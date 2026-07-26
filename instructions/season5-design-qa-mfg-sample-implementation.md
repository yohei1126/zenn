# シーズン5：設計・品証・製造マルチモーダル知見統合 — サンプル実装指示書

対象記事:

| 部 | 記事 | 役割 |
| :--- | :--- | :--- |
| 第1部 | `articles/2026-07-20-design-qa-mfg-knowledge-silos.md` | Problem（分断の構造） |
| 第2部 | `articles/2026-07-20-design-qa-mfg-multimodal-model.md` | Design（三層モデル） |
| 第3部 | `articles/2026-07-20-design-qa-mfg-shift-left.md` | Build（CADプッシュUXの参照アーキテクチャ） |

作成目的: 第3部で描いた体験を、**読者がローカルで再現できる最小コンパニオン実装**の仕様と作業順を固定する。  
**注:** 本ドキュメントは実装指示。記事本文・コードの変更は別タスク。

関連: シーズン2 コンパニオン `github.com/yohei1126/supply-chain-impact-analysis-agent`（Graph Contract / Bridge Keys / Neo4j）。シーズン5はドメインが設計・品証・製造に移るため、**新規リポジトリ推奨**（既存を無理に肥大化しない）。パターンの再利用は必須。

---

## 0. 解決したい問題（第1部の芯 → 実装が示すこと）

第1部の主張を、実装指示の前提として固定する。サンプルコードは機能カタログではなく、次の分断を**同じ部品コンテキスト上で扱い直す**ための最小実証である。

### 0.1 三者択一ではない：役割分担

よくある誤解は次のどれか一つ、と見ることである。連載・本サンプルの答えは **①だけでは足りない。②と③を役割分担し、意思決定に載せる** である。

| 見方 | 内容 | 本連載での位置 |
| :--- | :--- | :--- |
| **① 繋がっているだけ** | 同じ部品ID・同じBOM行をリンクする。帳票間のハイパーリンクやマスタ突合に近い | **必要条件だが不十分**。IDが一致しても観点（意味・トポロジー）は一致しない（第1部） |
| **② 意味が変わった工程を数理で結びつける** | EBOMとMBOMのように切り方が違う構造を、同一ツリー化せず **対応写像** $m$ や因果トリプルで結ぶ。差分は Tree Edit Distance / Graph Matching 等で測りうる（第2部・構造層） | **構造層の本体**。「同じ部品なのに世界が違う」への直接解 |
| **③ 似た過去から今の設計へ知見を移す** | 似た部品構成・形状・製造・シミュレーション・ゲート結果を、共通物差し（表現層）で候補化し、今の $x$（R等）に効く制約・リスク・コスト感度へ落とす（第2部・表現／意思決定層） | **表現層＋意思決定層の本体**。「過去事例が活きない」への直接解 |

関係式で言うと:

```text
① IDリンク            … 「どれが同じ部品か」の鍵（Season2 Bridge Keys と同型）
② 対応写像・因果グラフ … 「観点が違う構造をどう対応づけ、なぜを辿るか」
③ 類似＋感度          … 「グラフに薄い／別案件の過去を、今の設計変数にどう効かせるか」
```

- **②だけ**だと、いま載っている製品のトレースはできるが、まだグラフに無い過去案件やモダリティ差を跨いだ「似た失敗」は引きにくい。  
- **③だけ**だと、似た事例は出るが「どの設計ノードを直すか」「どの工程・仕様に効くか」が説明できない（未接地）。  
- だからカードは必ず **③の候補 → ②の接地 → （任意で）感度** の順で出す。類似度は決定ではない。

### 0.2 現場の痛み → どの層が担うか

| 現場の痛み（第1部） | 何が起きているか | 主に担う層 | サンプルが示す解決の核 |
| :--- | :--- | :--- | :--- |
| **同じ部品のBOMなのに世界が違う** | 設計は EBOM、製造は MBOM/BOP、品証は FMEA/ゲート。部品番号が一致しても観点・トポロジーが違う | **② 構造層** | 同一 `product_id` 上に三観点を置き、`corresponds_to`（対応写像 $m$）で結ぶ。無理な同一ツリー化はしない |
| **フィードバックが工程を跨ぎづらい** | 試作NGや歩留まりが帳票に閉じ、設計特徴へ戻らない。品証がゲート化しがち | **② 構造層**（ハブ＋パス） | 品証を設計特徴と工程の両方に辺を持つハブにし、上流／下流を双方向トレース。製造知見は $m$ 経由で設計特徴へ戻す |
| **過去事例の知見が今の設計に活きない** | 似た割れ・却下・加工条件が別システムに眠り、設計中は人力検索 | **③ 表現→意思決定** | いまの設計コンテキストから「似たゲート／FMEA／工程リスク」を候補化し、②で接地したうえで感度カードとしてプッシュする |

デモの一文:

> 「同じブラケットでも工程ごとに意味が違う（②で対応づける）。そのうえで、似た過去の却下・加工リスクを今のRに効く形で引き（③）、根拠パス付きで設計に戻す。IDで繋がっているだけ（①）では終わらない。」

実装の成功条件（§1）はこの問題文の言い換えであり、①のリンク追加だけで②③が無い拡張は MVP に入れない。

### 0.3 工程ごとに別グラフ、と考えてよいか

**はい（概念・所有権・トポロジーとしては）。** Season2 の「部門別グラフを物理統合せず Bridge で結ぶ」と同型である。

| 捉え方 | 内容 |
| :--- | :--- |
| **工程別グラフ** | 設計（EBOM/CAE/形状）、品証（FMEA/ゲート）、製造（MBOM/BOP/実績）は、それぞれ別の観点のグラフ（または別ドメイン）として持ってよい |
| **やってはいけないこと** | 三者を無理に一本の「正しいBOMツリー」に潰すこと。それは第1部が否定した同一化 |
| **やること** | 工程間は Bridge（`corresponds_to` 等）と品証ハブで **論理結合**する。フィードバックはキーと対応写像経由で戻す |
| **MVPの実装便宜** | ローカルデモでは Neo4j **1インスタンスにラベル／サブグラフで同居**させてよい（運用上の「別グラフ」を単一DBで模擬）。本番寄りにするなら Season2 同様 multi-DB / 別ストア＋フェデレーションでもよい |

つまり「工程ごとに別グラフ」＝**意味の境界を分ける**話であり、「グラフを増やせば解決」ではない。別グラフにしたうえで、②の対応写像と③の類似移転がなければ、また分断に戻る。

### 0.4 オントロジと契約はどの単位で書くか

Season2/4 と同型。**製品1個ごとでも、企業まるごと1本の巨大オントロジでもない。**

| 成果物 | 書く単位 | 中身 | 誰が守るか |
| :--- | :--- | :--- | :--- |
| **ドメインオントロジ（局所）** | **工程グラフごと**（設計 / 品証 / 製造） | その工程が所有するノード型・辺・必須属性。例: 設計=`ShapeFeature`,`CaeCase`；品証=`FmeaItem`,`GateResult`；製造=`MbomProcess`,`Equipment` | そのドメインの ingest / L0–L3 検証 |
| **Graph Contract（横断）** | **フェデレーション全体で1つ**（三工程をまたぐ合意） | Bridge Keys、許容する横断関係（`corresponds_to` 等）、結合経路、未接続時の品質ゲート | 結合時・クエリ時（L4）。横断辺の語彙はここに集約 |
| **インスタンスデータ** | 製品・版・案件ごと | 実ノード（`FEAT-FILLET-R` 等）。オントロジではない | シード / PLM 連携 |

整理:

```text
設計オントロジ ─┐
品証オントロジ ─┼─→ Graph Contract（1枚）─→ 論理結合・トレース・Grounding
製造オントロジ ─┘
        ↑
   型・語彙・必須辺（契約）
        ↑
   製品A/Bの実データはインスタンス（契約の単位ではない）
```

**やってはいけない単位の取り方**

| やりがち | なぜダメか |
| :--- | :--- |
| 製品ごとに Contract を複製 | 型がドリフトし、類似事例（③）の横断比較が壊れる |
| 最初から企業全体 OWL | 第2部が拒否した「網羅オントロジ先行」。エージェントが辿れる **最小の契約** で足る |
| Contract に工程内の全辺を詰め込む | 所有権が消え、分割統治が名目だけになる。工程内はドメインオントロジ側 |

**MVPでのファイル配置（便宜）**

- `ontology/schema.py` … 三ドメインの型をモジュール分け（`design.py` / `qa.py` / `mfg.py`）しても、単一パッケージでも可
- `ontology/contract/graph_contract.yaml` … **横断だけ**を1ファイルに（bridges, cross_domain_rels, quality_gates）
- ドメイン内の必須辺は各ドメイン節、または schema の validator に置く

「オントロジ＝工程グラフの型契約」「Graph Contract＝工程間の結合契約」——この二段が単位の答えである（Season4 の L0–L3 vs L4）。

---

## 1. 結論（要約）

| 論点 | 結論 |
| :--- | :--- |
| 実装のゴール | CAD差分イベントを入力に、「類似品証却下＋コスト感度＋グラフ根拠」をサイドパネル相当で返す |
| 理論との対応 | 構造層＝設計根拠KG、表現層＝候補生成（MVPはルール＋特徴類似）、意思決定層＝局所感度カード |
| やらないこと（MVP） | 実CADアドイン、フル対照学習、FNO/MeshGraphNets学習、厳密な多目的最適化ソルバ、本番PLM/MES接続 |
| やること（MVP） | 合成データ＋Graph Contract＋パストレース＋簡易類似＋差分感度＋採用/却下ログ |
| 段階 | 第3部 §5 の段階0→2をまず完走。段階3–4は拡張フラグ |
| 課題例の扱い | 原価×品質ジレンマはデモシナリオのフック。枠組みはQCD（まずQ・C） |

成功の定義（デモ1本で言えること）:

> 「Rを変えたら、過去ゲートで落ちた類似事例と、コストの効き方と、FMEA/工程へのリンクが同時に出る。類似度だけでは決めず、グラフで接地できる。」

---

## 2. 記事→実装のマッピング

| 記事の主張 | サンプル実装での落とし先 |
| :--- | :--- |
| 同じ部品でも工程ごとに観点・意味が分断（§0） | 単一シード上に設計/品証/製造ノードを共存させ、IDは共有しつつビューを分けたまま Bridge で結ぶ |
| 工程横断フィードバックが弱い（§0） | `trace_upstream` / `trace_downstream` と品証ハブ辺。製造イベントは $m$ 経由で設計特徴へ戻す前提をシードで示す |
| 過去事例が現設計に乗らない（§0） | `/advise` が「今の特徴」→過去ゲート類似→接地パス、を一枚のカードにする |
| EBOM–MBOM 観点差 | Bridge `corresponds_to`（手動シードの対応写像 $m$） |
| ゲート化したQA → ハブ | FMEA/DR/ゲート結果ノードが設計特徴と工程の両方に辺を持つ |
| 設計根拠知識グラフ | Neo4j（または同等）上のトリプル＋パスクエリ |
| 多峰性共用埋め込み | MVP: 数値特徴＋文埋め込み（または疑似ベクトル）の近傍検索。学習は段階4 |
| QCD 感度 | $C(x), h(x)$ の簡易サロゲート＋ $\Delta R$ の差分感度 |
| 検索窓の廃止 | API: `POST /advise`（現在の特徴コンテキストを受け取りプッシュ応答） |
| 自己進化 | `accept` / `reject` / `defer` イベントをログ＋任意でグラフ辺候補キューへ |
| Season2/4 接続 | `graph_contract.yaml`、必須辺検証、未接地候補のフラグ |

第2部の用語パネル・エンコーダ表に出した文献は**研究方向の地図**。MVPのコードはそれらを再実装しない。

---

## 3. リポジトリ方針

### 3.1 置き場所（推奨）

| 選択肢 | 内容 | 推奨 |
| :--- | :--- | :--- |
| **A. 新規リポジトリ** | 例: `design-qa-mfg-shift-left-demo` | **推奨**。Season5専用デモ、記事リンクが明確 |
| B. Season2 リポジトリに `domains/design_qa_mfg/` 追加 | Contract流用は楽だが主題が混ざる | 非推奨（MVP後に検討可） |
| C. zenn リポジトリ内 `samples/` | プレビューと同居 | 非推奨（実行・依存が記事リポを汚す） |

公開: GitHub public。README に Season5 三部へのリンクと「記事は参照アーキテクチャ、本リポは段階0–2の最小実装」と明記。

### 3.2 技術スタック（MVP固定案）

| 層 | 選択 | 理由 |
| :--- | :--- | :--- |
| 言語 | Python 3.11+ | Season2 と揃える |
| グラフ | Neo4j（Docker Compose） | Contract / Cypher / パストレースが記事と一致 |
| 契約 | `ontology/contract/graph_contract.yaml` + Pydantic | Season2/4 と同型 |
| 候補生成 | 特徴ハッシュ＋コサイン（文埋め込みは任意で sentence-transformers または疑似） | フル学習を避ける（第2部 §3.3） |
| API | FastAPI | CADアドインの代わりになる低レイテンシ入口 |
| UI | Streamlit または単純 HTML/HTMX | 「疑似CAD横パネル」のデモ。実CAD不要 |
| パッケージ | `uv` または `poetry` | どちらでも可。README で一本化 |

**GQL / GRAPH TYPE について（検証結果を踏まえた方針）:**

GQL の `CREATE GRAPH` / graph type は、工程内スキーマを DB に固定する理想形に近い。ただしデモ実機検証（`design-qa-mfg-shift-left-demo/docs/gql-schema-verification.md`）では、使用中の Neo4j Community（Kernel 2025.11.2 系）で次が **未対応**:

- `CREATE GRAPH ...`
- `CREATE GRAPH TYPE ...`
- `ALTER CURRENT GRAPH TYPE SET ...` / `SHOW CURRENT GRAPH TYPE`

一方 **`CREATE CONSTRAINT ... FOR (...) REQUIRE ...` は利用可能**。

| 層 | 理想（GQL GRAPH TYPE） | **本デモの採用（検証どおり）** |
| :--- | :--- | :--- |
| 工程内の型・必須・一意 | GRAPH TYPE で一括 | **Cypher `CREATE CONSTRAINT` + Pydantic 書き込み検証** |
| 工程横断 Bridge（L4） | 単一 GRAPH TYPE では不足 | **`graph_contract.yaml` が SSOT** |
| Grounding・未接地 | — | API / アプリ検証 |

方針（続けること）: **GRAPH TYPE 待ちにしない。** 正本は YAML/Pydantic、DB 強制は Cypher CONSTRAINT。GRAPH TYPE が使える版が出たらコンパイル先として検討する（任意・後追い）。

---

## 4. デモシナリオ（必須ストーリー）

業界寄せ（第3部メモ）: **切削主体の機械部品**（ブラケット想定）。

### 4.1 登場人物データ（シード最小集合）

| ID例 | 種類 | 内容 |
| :--- | :--- | :--- |
| `REQ-STIFF-01` | 仕様 | 剛性要件 |
| `CAE-CASE-12` | CAE | 応力合否（単体メッシュでは合格） |
| `FEAT-FILLET-R` | 形状特徴 | フィレットR（設計変数 $x$ の主軸） |
| `FMEA-CRACK-07` | 故障モード | 割れ（過去ゲート却下） |
| `GATE-REJ-03` | ゲート結果 | 耐久試験NG、理由リンク付き |
| `EBOM-BRKT-A` | EBOM部品 | ブラケット |
| `MBOM-OP-MILL` | MBOM/工程 | 切削工程＋検査 |
| `BOP-TOOL-42` | 設備 | 特定切削機（コストドライバ） |

必須トリプル（第2部表と同型）:

```text
(REQ-STIFF-01)-[:constrains]->(CAE-CASE-12)
(CAE-CASE-12)-[:justifies]->(FEAT-FILLET-R)
(FEAT-FILLET-R)-[:induces_risk]->(FMEA-CRACK-07)
(FMEA-CRACK-07)-[:mitigated_by]->(MBOM-OP-MILL)
(EBOM-BRKT-A)-[:corresponds_to]->(MBOM-OP-MILL)
(GATE-REJ-03)-[:about]->(FMEA-CRACK-07)
(GATE-REJ-03)-[:involves_feature]->(FEAT-FILLET-R)  # R≈0.3 で却下、など属性で保持
```

### 4.2 操作フロー（受け入れシナリオ）

1. UI/API で現在の設計コンテキストを送る: `{ "feature_id": "FEAT-FILLET-R", "r_mm": 0.3, "tolerance": "..." }`
2. システムが返すカード:
   - 類似ゲート却下（例: 類似度表示＋「未検証」または「接地済み」）
   - 根拠パス（仕様→CAE→特徴→FMEA→工程）
   - コスト感度（例: Rを +0.5 したときの $\Delta C$ と品証パス見込みの差分）
3. ユーザーが `accept` / `reject` / `defer` を押す → イベントログに永続化
4. （拡張）`reject` 理由が次の負例／制約候補キューに入る

提示文のトーンは第3部 §1 のイメージ文に合わせる（数値はシードで再現可能にする）。

---

## 5. ディレクトリ構成（目標）

```text
design-qa-mfg-shift-left-demo/
├── README.md
├── docker-compose.yml          # Neo4j
├── pyproject.toml
├── ontology/
│   ├── contract/
│   │   └── graph_contract.yaml # ノード型・必須辺・Bridge・品質ゲート
│   └── schema.py               # Pydantic
├── data/
│   ├── seed/                   # JSON/YAML の合成マスタ
│   │   ├── nodes.json
│   │   ├── edges.json
│   │   ├── feature_vectors.json
│   │   └── cost_surrogate.json # C(x), h(x) の表または係数
│   └── events/                 # accept/reject ログ（gitignore可）
├── app/
│   ├── storage/                # Neo4j driver
│   ├── graph/                  # パストレース、接地チェック
│   ├── retrieval/              # 候補生成（特徴類似）
│   ├── decision/               # 感度・簡易制約チェック
│   ├── api.py                  # FastAPI: /advise, /feedback
│   └── ui_streamlit.py         # 疑似CADパネル
├── scripts/
│   ├── seed_neo4j.py
│   ├── validate_contract.py    # 必須辺・未接続リスク
│   └── demo_advise.py
└── tests/
    ├── test_path_trace.py
    ├── test_retrieval.py
    └── test_sensitivity.py
```

---

## 6. Graph Contract（最小語彙）

`graph_contract.yaml` に少なくとも次を固定する。

### 6.1 ノード型

`Requirement`, `CaeCase`, `ShapeFeature`, `FmeaItem`, `GateResult`, `EbomNode`, `MbomProcess`, `Equipment`

### 6.2 関係（辺）

| 関係 | 意味 |
| :--- | :--- |
| `constrains` | 仕様→CAE |
| `justifies` | CAE→形状特徴 |
| `induces_risk` | 形状→FMEA |
| `mitigated_by` | FMEA→工程/設備 |
| `corresponds_to` | EBOM↔MBOM Bridge |
| `about` / `involves_feature` | ゲート結果の接続 |

### 6.3 品質ゲート（検証）

起動時または `validate_contract.py` で:

1. 必須辺の欠落（例: `ShapeFeature` に `induces_risk` が無い）を検出
2. `corresponds_to` 未接続を「未接続リスク」として列挙
3. 埋め込み候補がグラフ展開できない場合は UI 上 `ungrounded=true`

Season4 の「契約として検証」「Grounding」と同型。類似度だけで合否を出さない。

---

## 7. モジュール仕様

### 7.1 構造層 — `app/graph/`

| 関数（例） | 入出力 | 受け入れ条件 |
| :--- | :--- | :--- |
| `trace_upstream(feature_id)` | → 仕様/CAE パス | シードで非空 |
| `trace_downstream(feature_id)` | → FMEA/工程パス | 品証ハブを経由 |
| `expand_grounding(candidate_ids)` | → 根拠辺リスト or ungrounded | 候補IDがグラフに無ければ ungrounded |

実装メモ: Cypher は名前付きレシピ（Season2 の tool 境界思想）。LLM に Cypher を書かせない。

### 7.2 表現層 — `app/retrieval/`（MVP）

入力: 現在の `r_mm`, `tolerance`, 任意のテキストメモ。  
出力: Top-k の `GateResult` / `FmeaItem`（スコア付き）。

MVPアルゴリズム（いずれか1つでよい）:

1. **ルール**: `r_mm` が過去却下帯（例 0.25–0.35）なら該当ゲートを優先
2. **特徴ベクトル**: `[r_mm, tol_code, ...]` のコサイン
3. **文埋め込み（任意）**: FMEA文言との近傍（モデルはローカル小規模 or 疑似ハッシュ）

**禁止（MVP）:** CLIP/FNO の学習パイプライン、大規模ペア収集。

### 7.3 意思決定層 — `app/decision/`

サロゲート例（シードで固定し再現可能に）:

$$
C(r) = c_0 + c_1 / r + c_2 \cdot \mathbf{1}_{\text{tight\_tol}}
$$

$$
h(r) = \text{risk}(r) - \tau \quad (\text{risk は表引き or シグモイド})
$$

| 関数（例） | 内容 |
| :--- | :--- |
| `cost_sensitivity(r, delta=0.5)` | $\Delta C \approx C(r+\delta)-C(r)$ |
| `quality_sensitivity(r, delta=0.5)` | パス見込みや $h$ の差分 |
| `feasible(r)` | $h(r)\le 0$ の簡易判定（納期制約はオプション） |

最適解 $x^*$ の大域探索はしない。カードに「いまの変更の効き方」だけ出す。

### 7.4 API

```http
POST /v1/advise
{
  "product_id": "BRKT-A",
  "feature_id": "FEAT-FILLET-R",
  "r_mm": 0.3,
  "tolerance": "H7",
  "notes": ""
}

→ {
  "similar_gates": [...],
  "grounding_paths": [...],
  "sensitivity": {"delta_r": 0.5, "delta_cost_pct": -15, "delta_pass_prob": 0.12},
  "warnings": ["ungrounded_candidate:..."]
}

POST /v1/feedback
{ "advice_id": "...", "action": "accept|reject|defer", "reason": "..." }
```

レイテンシ目標（ローカル）: キャッシュヒット時 **< 300ms**。重い再計算はしない（第3部 §2.3）。

### 7.5 UI（疑似CAD）

- 左: Rスライダー＋公差セレクト（CADの代わり）
- 右: アドバイスカード（類似・根拠・感度・採用/却下）
- 検索窓は置かない（第3部 UX原則）

---

## 8. 実装フェーズと完了条件

記事第3部 §5 に対応。

| Phase | 内容 | Done の定義 |
| :---: | :--- | :--- |
| **0** | Contract + シード + Neo4j seed + `corresponds_to` | `validate_contract.py` が緑。Bridge 欠落を検出できる |
| **1** | 品証ハブ辺 + `trace_*` | feature_id から仕様と工程の両方に辿れるテストが通る |
| **2** | `/advise` + UI + ルール/特徴類似 + feedbackログ | README のデモ手順でカードが出る。検索UIなし |
| **3** | コスト/品質サロゲート感度をカードに常設 | $\Delta R$ で数値が変わるテスト |
| **4**（任意） | 文埋め込み差し替え、ペア学習のスタブ | フラグで切替。デフォルトOFF |

**記事公開との関係:** 第3部本文は参照アーキテクチャのまま維持してよい。実装が Phase 2 まで達したら、第3部に「コンパニオン実装」節または README リンクを追記する（執筆は別タスク）。

---

## 9. テスト方針

| テスト | 検証すること |
| :--- | :--- |
| `test_path_trace` | シード上で upstream/downstream が期待ノードを含む |
| `test_bridge` | EBOM→MBOM の `corresponds_to` 欠落を検出 |
| `test_retrieval` | R=0.3 で却下ゲートが Top-k に入る |
| `test_grounding` | グラフに無い候補IDは `ungrounded` |
| `test_sensitivity` | R増加でコストが単調に動く（サロゲート定義どおり） |
| `test_feedback` | accept/reject が追記される |

CI: pytest + Neo4j は docker またはテスト用のインメモリグラフ（簡易実装なら NetworkX フォールバック可。ただし本番パスは Neo4j）。

---

## 10. README に必ず書くこと

1. Season5 三部へのリンクと、本リポがカバーする Phase（0–2）
2. **問題文（§0）を README 冒頭に再掲**（同じ部品・観点分断・跨ぎフィードバック・過去知見の再利用）
3. `docker compose up` → `seed` → `streamlit` / `uvicorn` の最短手順
4. 「類似度は決定ではない」「権限・秘匿はデモ対象外」
5. Season2 Graph Contract との用語対応表（Bridge / Contract / Grounding）
6. 今後やらないことリスト（実CAD、フルFNO学習など）

---

## 11. 記事側へのフィードバック（実装後）

実装が進んだら、zenn 側で検討する更新（別PR）:

| 対象 | 内容 |
| :--- | :--- |
| 第3部 §7 | コンパニオン実装の有無を「新規リポで Phase0–2」に確定 |
| 第3部 | デモ画面スクショ or GIF、API例を1つ |
| AGENTS.md | Season5 実装指示へのリンク |
| 第2部 §3.3 | 「サンプルはハイブリッド」への実リポ参照 |

---

## 12. 作業チェックリスト（実装者向け）

- [ ] リポジトリ作成・ライセンス・README骨子
- [ ] `graph_contract.yaml` + `schema.py`
- [ ] シード JSON（§4.1 のノード/辺）
- [ ] Neo4j docker + seed スクリプト
- [ ] `trace_upstream` / `trace_downstream` + テスト
- [ ] `validate_contract`（必須辺・Bridge）
- [ ] retrieval MVP（ルール or 特徴ベクトル）
- [ ] sensitivity サロゲート
- [ ] FastAPI `/advise` `/feedback`
- [ ] Streamlit 疑似CADパネル
- [ ] デモ手順を README に固定
- [ ] （任意）第3部記事へリンク追記のPR

---

## 13. 明示的非目標（スコープ外）

- 商用CAD（NX/CATIA/SolidWorks）アドインSDK
- 本番PLM/SPDM/MESアダプタ
- 対照学習のデータパイプライン本番化
- 多目的最適化のパレート前線UI
- ODS / B2B フェデレーション（Season3B）との接続
- サプライチェーン影響分析エージェントとのデータ統合（ID体系の議論は将来）

---

## 14. 用語の対応（実装コードでブレないように）

| 記事用語 | 実装識別子の推奨 |
| :--- | :--- |
| 設計根拠知識グラフ | `rationale_graph` / Neo4j DB名 `rationale` |
| 多峰性共用埋め込み | `joint_embedding`（Phase4）。MVPは `feature_retrieval` |
| 感度 | `sensitivity` |
| Bridge Keys / 対応写像 $m$ | `corresponds_to` + `bridges` in contract |
| Grounding | `expand_grounding` / `ungrounded` |
| バーチャル品質ゲート | `virtual_gate`（候補レビューキュー。MVPは feedback ログで代替可） |

---

改訂履歴:

| 日付 | 内容 |
| :--- | :--- |
| 2026-07-23 | 初版。Season5 三部に対応するサンプル実装指示を追加 |
| 2026-07-23 | §0 を追加。観点分断・工程横断フィードバック・過去事例再利用を問題定義として明示 |
| 2026-07-23 | §0.1 を追加。「繋がるだけ」ではなく対応写像（②）と類似知見の移転（③）の役割分担を明示 |
| 2026-07-23 | §0.3 を追加。工程別グラフ（Season2同型）＋論理結合としてよい旨を明示 |
| 2026-07-23 | §0.4 を追加。オントロジ＝工程単位、Graph Contract＝フェデレーション1枚と単位を固定 |
