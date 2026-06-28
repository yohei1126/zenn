# Python Asia 2027（シンガポール）— セッション提案書（3案）

**イベント:** [Python Asia](https://pythonasia.org/)（シンガポール想定）  
**想定枠:** 45分トーク（+ 質疑） / 英語または英日併記スライド  
**提出者:** 大西 洋平（yohei）  
**作成日:** 2026年

**位置づけ:** 本リポジトリ `zenn` の連載・企画と **別リポジトリの実装** を CFP に載せるための著者用メモ。3案は **独立したセッション** として提出可能（同時に複数提出するかは CFP 規定に従う）。

---

## 0. 3案の一覧

| 案 | テーマ | 一言 | 主な資産 |
|:---:|:---|:---|:---|
| **1** | 知識グラフ・オントロジ・論理フェデレーション | LLM と決定論を **Tool Boundary** で両立 | Zenn S1–S2 + [`supply-chain-impact-analysis-agent`](https://github.com/yohei1126/supply-chain-impact-analysis-agent) |
| **2** | Physical AI | 松尾研講座で学んだ **データ→学習→運用** を製造現場の言葉で | 松尾研 [Physical AI 講座 2026](https://weblab.t.u-tokyo.ac.jp/physical-ai/) + 製造業ドメイン知 |
| **3** | マルチモーダル・エッジ AI | Lance × DuckDB × Python で **エッジ原型** を組む | [`season-wm-lance-series-plan.md`](./season-wm-lance-series-plan.md) / 連載2本 / `raw/lancedb/` |

**相互関係:** 案1＝**意味の層・記号AI**、案2＝**物理世界・ロボット**、案3＝**マルチモーダル data plane**。同一スピーカーの **3本柱** として並べられるが、1セッションに詰め込まない。

---

# 案1 — 知識グラフ・オントロジ・論理フェデレーション：決定論と非決定論のバランス

## 1.1 タイトル案

| 優先 | 英語（CFP 用） | 日本語 |
|:---:|:---|:---|
| **推奨** | *Balancing Symbolic and Neural AI: Knowledge Graphs, Ontologies, and Logical Federation in Python* | 記号AIとニューラルAIのバランス — Python で組む KG・オントロジー・論理フェデレーション |
| 短め | *Don't Let the LLM Write Cypher: Deterministic Tools for Graph Agents* | LLM に Cypher を書かせない — グラフエージェントの決定論的ツール |

## 1.2 テーゼ（1文）

> エンタープライズ AI は **LLM の柔軟性** と **オントロジー・KG の決定論的検証** を分離して設計する。Python では Pydantic・YAML 契約・名前付きツールがその境界になる。

## 1.3 聴衆が持ち帰るもの

1. 「売上」が数百定義ある問題 = **意味の層** の話（プロンプト調整だけでは解けない）
2. **単一巨大グラフ** ではなく、ドメイン別グラフ + **結合の約束事**（共通ID・結び方）
3. **Tool Boundary** — LLM＝計画、Python＝検証済みグラフ探索
4. **簡易オントロジー**（Pydantic）→ Cypher 整合性 → 必要なら OWL、の段階的厳密さ

## 1.4 なぜつまらないか（Pydantic 紹介だけにしない）

| やらない | やる |
|:---|:---|
| Pydantic モデルの写経 | **越境書き込み reject** を pytest / ライブで見せる |
| プロンプト例の紹介 | **`mode=tools`** で API キーなしデモ → その後 LLM プランナー |
| OWL 講義 | サプライヤー停止 → 部品 → 製品 → 工程の **3ホップ波及** |
| Text-to-Cypher 推奨 | **存在しないエッジ** を LLM が invent してもツール層で落ちるデモ |

## 1.5 デモ構成（45分）

| 分 | 内容 |
| ---: | :--- |
| 0–5 | 問題設定：「売上」はどれか / 部門分断 |
| 5–12 | 3層：PF 自動オントロジー（③）・部門連合（②）・コアドメイン（①）— 概念のみ短く |
| 12–20 | リポジトリツアー：`ontology/` · `domains/` · `graph_contract.yaml` |
| 20–35 | **ライブ** Path A→B（[`demo-runbook`](https://github.com/yohei1126/supply-chain-impact-analysis-agent/blob/main/docs/demo-runbook.md)）<br>① `demo_federation.py` ② Web UI Federation ③ Agent（`mode=tools` 推奨） |
| 35–42 | pytest 1本：`test_schema` または `test_federation_analysis` |
| 42–45 | まとめ：決定論 / 非決定論の分担表 |

**会場リスク対策:** Neo4j のみ Docker 起動。LLM / Langfuse は **オプション**（スライド1枚）。

## 1.6 技術スタック（Python らしさ）

- **uv** + **pytest** + **ruff** / **mypy**
- **Pydantic v2** — ロード前ゲート（簡易オントロジー）
- **Neo4j** multi-DB + **DuckDB** component master
- **YAML Graph Contract** → Agent Skill / `graph-context.json` **自動生成**
- **`app/agent`**: `ToolRegistry`、heuristic / LLM planner 切替

## 1.7 根拠コンテンツ

| 種別 | パス |
|:---|:---|
| Zenn 連載 | `articles/2026-05-30-vkg-strategy{,-2,-3}.md` |
| Zenn 連載 | `articles/2026-06-06-supply-chain-impact-analysis-agent{,2,3}.md` |
| スライド（MLOps 版） | `slides/mlops-meaning-layer-2026/talk.md`（概念は流用、デモはリポジトリ中心に差し替え） |
| 実装（正本） | `/Users/yoheionishi/work/supply-chain-impact-analysis-agent` |
| 公開 | https://github.com/yohei1126/supply-chain-impact-analysis-agent |

## 1.8 CFP 要約（英語・約120語）

> Enterprise agents fail when users say "revenue" but the system cannot pick *which* definition applies. This talk shows a Python-native architecture: domain-scoped Neo4j graphs, Pydantic-gated ingest, YAML federation contracts, and **deterministic tools** so the LLM plans but never writes ad-hoc Cypher. Live demo: supplier disruption propagation across engineering, manufacturing, and sourcing graphs—without merging them into one physical database. Bring pytest as your meaning layer, not longer prompts.

## 1.9 前提・レベル

- **対象:** 中級（Python + なんらかの DB 経験。KG 未経験可）
- **前提知識:** FastAPI 不要。Docker 基本操作があるとデモ追従しやすい

---

# 案2 — Physical AI：松尾研講座と製造現場の接点

## 2.1 背景（著者）

- **2026年6月〜8月:** [東京大学松尾・岩澤研究室 Physical AI 講座 2026 基礎編](https://weblab.t.u-tokyo.ac.jp/lecture/course-list/physical-ai/) 受講（〜2026年末まで関連講座・応用編も視野）
- カリキュラム例：Physical AI 概要 → 模倣学習 → 強化学習 → スケーリング → **実世界データ収集** → 実運用（[公式カリキュラム](https://weblab.t.u-tokyo.ac.jp/lecture/course-list/physical-ai/)）
- 本業文脈：**製造業** — 案1の BOM / サプライチェーン知識と接続可能

## 2.2 タイトル案

| 優先 | 英語 | 日本語 |
|:---:|:---|:---|
| **推奨** | *From Factory Data to Physical AI: What Matsuo Lab Teaches and What Python Teams Can Ship* | 工場データから Physical AI へ — 松尾研で学び、Python チームが届けるもの |
| 実装寄り | *LeRobot, Trajectories, and the Data Loop — A Manufacturing Engineer's Field Notes* | 軌跡・模倣学習・データループ — 製造エンジニアの Physical AI メモ |

## 2.3 テーゼ（1文）

> Physical AI は「大きなモデル」より **データ収集→学習→評価→運用のループ** が本体であり、製造現場では **既存の意味の層（BOM・工程・センサー）** と trajectory データの設計が成否を分ける。

## 2.4 聴衆が持ち帰るもの

1. Physical AI / 知能ロボティクス / 世界モデルの **用語の整理**（松尾研講座ベース）
2. **sim だけ vs 実世界データ** — 講座で強調される収集・スケーリングの現実
3. 製造業向け：**何を trajectory として記録するか**（画像・関節角・力・タイムスタンプ・メタデータ）
4. Python エコシステム：**LeRobot** 等の位置づけ（深掘りは講座に任せ、**現場への翻訳** に集中）

## 2.5 セッションの切り口（案1との差別化）

| 案1 | 案2 |
|:---|:---|
| 知識 **表現**（グラフ・オントロジー） | 知識 **行動**（ポリシー・trajectory） |
| DWH / Neo4j / エージェント QA | ロボット / sim / 実機 / データループ |
| 決定論的ツール | 模倣学習 + 安全制約 + デプロイ |

**橋渡しスライド（1枚）:** 案1の `Component → Product → Process` グラフは、Physical AI では **「その Process を誰が・どう動かすか」の trajectory** として記録される。

## 2.6 デモ構成（45分・コード比重は中）

| 分 | 内容 |
| ---: | :--- |
| 0–8 | Physical AI とは（松尾研講座の地図）— [Physical AI 講座](https://weblab.t.u-tokyo.ac.jp/physical-ai/) |
| 8–18 | データループ：収集 → 学習 → 評価 → 運用（第6–7回相当の要約） |
| 18–28 | 製造例：ライン動画 / ティーチング / BOM・工程メタデータとの **同居** |
| 28–38 | **Python デモ（軽量）** — sim または録画 trajectory の読み込み・可視化（LeRobot / 最小 numpy） |
| 38–45 | 案3 への布石：trajectory store に **Lance** が効く理由（1スライド） |

**注:** 松尾研講座の **課題コードそのままの発表は避ける**（著作・受講規約を確認）。**学んだ概念の再構成 + 著者の製造ドメイン** で話す。

## 2.7 技術・参考（執筆時に深掘り）

| 項目 | 参照 |
|:---|:---|
| 松尾研講座 | https://weblab.t.u-tokyo.ac.jp/physical-ai/ |
| LeRobot（Hugging Face） | 講座で扱う sim / データ収集スタック（版は受講時点に合わせる） |
| 世界モデル（講座リンク先） | 案3 `season-wm-lance-series-plan.md` と接続可 |
| 製造ドメイン | 案1 リポジトリの EBOM / Routing 用語 |

## 2.8 CFP 要約（英語・約120語）

> Physical AI is having its moment—robots, foundation models, and real-world data loops. I took the University of Tokyo Matsuo Lab's Physical AI course (2026) while working in manufacturing analytics. This talk translates the curriculum for Python developers: what to record as trajectories, how sim relates to shop-floor video, and where the data loop breaks in enterprise settings. Not a LeRobot tutorial—a field map from factory semantics to trainable policies, with a lightweight Python demo.

## 2.9 前提・レベル

- **対象:** 中級（Python + ML 基礎。ロボット未経験可）
- **2027年時点:** 2026 受講完了・応用編または最終課題の **学びを反映** した版に更新

## 2.10 執筆 TODO（CFP 前）

- [ ] 受講メモを `instructions/physical-ai-matsuo-course-notes.md` に整理（任意・非公開可）
- [ ] デモ用最小 trajectory（公開可能な synthetic）を選定
- [ ] 講座コンテンツの **再配布可否** を確認

---

# 案3 — マルチモーダル・エッジ AI：DuckDB × Lance × LLM Python プロトタイプ

## 3.1 タイトル案

| 優先 | 英語 | 日本語 |
|:---:|:---|:---|
| **推奨** | *Multimodal Edge AI in Python: Lance, DuckDB, and LLM Prototypes Without Three Glue Systems* | マルチモーダル・エッジ AI — Lance と DuckDB で LLM 原型を Python だけで |
| 短め | *One Lance File, Two Query Faces: LanceDB Meets DuckDB for Edge Multimodal Apps* | 1つの Lance ファイルを LanceDB と DuckDB で使い分ける |

## 3.2 テーゼ（1文）

> エッジのマルチモーダル AI は **ベクトルDB・オブジェクトストア・メタデータDB の3分割** で drift しやすい。**Lance** に bytes・metadata・embedding を同居させ、**DuckDB**（SQL）と **LanceDB**（検索）で同じファイルを読む Python 原型が現実的。

## 3.3 聴衆が持ち帰るもの

1. **真マルチモーダル data plane** の定義（random access・版・同居）
2. なぜ MP4/HDF5 だけでは足りないか（世界モデル論文の empirics を1枚）
3. **同じ Lance ファイル** を DuckDB SQL と LanceDB で触る最小コード
4. LLM 原型：**SQL / 検索結果 / 画像 bytes** を Python で1パイプラインに載せるパターン

## 3.4 デモ構成（45分・**コード中心**）

| 分 | 内容 |
| ---: | :--- |
| 0–8 | 3系統 glue の問題 → Lance の5要点 |
| 8–15 | Push-T 数値（HDF5 vs Lance）— [`plan-multimodal-lance-duckdb-article.md`](./plan-multimodal-lance-duckdb-article.md) |
| 15–30 | **ライブ:** Lance 作成 → DuckDB `read_lance` → フィルタ / `image_bytes` |
| 30–40 | LanceDB 側（ベクトル検索）— 同ファイル |
| 40–45 | LLM 原型：取得チャンクをプロンプトに（API またはモック） |

**デモリポ:** 新規 `multimodal-edge-demo/`（zenn 外）または notebook — CFP 確定後に最小公開。

## 3.5 技術スタック

| 層 | 技術 |
|:---|:---|
| フォーマット | **Lance** |
| SQL / 分析 | **DuckDB** + lance extension |
| 検索 / embedded | **LanceDB**（Python） |
| LLM | OpenAI-compatible client または LiteLLM（任意） |
| パッケージ | **uv**, **jupyter** または **marimo**（任意） |

## 3.6 根拠コンテンツ

| 種別 | パス |
|:---|:---|
| 企画 | [`season-wm-lance-series-plan.md`](./season-wm-lance-series-plan.md) |
| 連載 | `articles/2026-07-06-multimodal-data-foundation-lance-duckdb.md` |
| 連載 | `articles/2026-07-13-multimodal-lance-duckdb-query-surfaces.md` |
| 素材 | `raw/lancedb/` |
| 草案 | [`LANCE.md`](./LANCE.md)（製造 ML ユースケース） |

## 3.7 CFP 要約（英語・約120語）

> Edge multimodal apps often split vectors, blobs, and metadata across three systems—and drift. Lance colocates bytes, metadata, and embeddings with random access; DuckDB adds SQL; LanceDB adds search—on the **same files**. This session builds a Python prototype: filter trajectories or inspection frames in DuckDB, retrieve neighbors in LanceDB, and feed grounded chunks to an LLM. Grounded in world-model research I/O lessons (stable-worldmodel) but focused on shippable edge patterns, not training at scale.

## 3.8 前提・レベル

- **対象:** 中〜上級 Python（pandas 経験あれば可）
- **GPU 不要** — エッジ / laptop デモ想定

## 3.9 案2 との接続

- 案2：**trajectory を何として記録するか**
- 案3：**trajectory をどう置いて SQL / 検索 / LLM に渡すか**

---

## 4. 提出戦略

| 優先 | 案 | 理由 |
|:---:|:---|:---|
| **第1候補** | **1** | 実装・テスト・デモが最も完成。Zenn 連載と一体 |
| **第2候補** | **3** | Python らしい「組み立て」デモ。Lance コミュニティにも刺さる |
| **第3候補** | **2** | 2026 受講直後の freshness。**2027 CFP 締切前に応用編・課題を反映** してから提出 |

**ワークショップ化:** 案1 または 案3 は **90分ハンズオン** に拡張可能（Neo4j または Lance のみ事前 `docker compose` / `uv sync`）。

---

## 5. 共有準備チェックリスト

| 項目 | 案1 | 案2 | 案3 |
|:---|:---:|:---:|:---:|
| 英語スライド | ○ | ○ | ○ |
| オフライン動作デモ | ○ | △ | ○ |
| GitHub 公開 URL | あり | 要作成 | 要作成 |
| ネットワーク不要バックアップ | `mode=tools` | 録画 | 事前生成 Lance |
| 連載 URL（補足資料） | Zenn S1–S2 | — | Zenn WM 入口2本 |

---

## 6. 更新履歴

| 日付 | 内容 |
|:---|:---|
| 2026-05 | 初版 — Python Asia 2027 向け3案 |

---

*関連: [`plan-mlops-meetup-meaning-layer-graph-talk.md`](./plan-mlops-meetup-meaning-layer-graph-talk.md) · [`zenn-book-meaning-layer-series-plan.md`](./zenn-book-meaning-layer-series-plan.md)*
