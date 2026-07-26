# OWA vs CWA：IPA Open Dataspaces と本連載の世界観整理

作成目的: **公開情報だけ**を根拠に、(1) ODS がなぜ「多くの企業が集まる場」なのに開世界仮説（OWA）を採るのか、(2) 本連載が閉世界仮説（CWA）に寄せる理由、(3) 両者は排他ではなく **層の重心の違い** であることを整理する。  
記事化・Epilogue 執筆の下敷き。実装変更は別タスク。

関連:

| 文書 | 役割 |
| :--- | :--- |
| [Why Open Dataspaces（IPA, 2026-04-01）](https://www.ipa.go.jp/digital/architecture/reports/open-dataspaces-design-philosophy.html) | 設計思想の一次ソース（要約ページ） |
| [同・英語PDF](https://www.ipa.go.jp/en/digital/architecture-guidelines/individual-link/p1o1lf000001xv4n-att/WhyOpenDataspaces_en.pdf) | OWA/CWA・RDF/OWL の詳細記述 |
| [Open Data Spaces 公式](https://www.ipa.go.jp/en/digital/opendataspaces/) | ODS-RAM / ODP / Middleware |
| `instructions/season3-b2b-ods-connection-plan.md` | 本シリーズ ↔ DPQM マッピング |
| `articles/2026-06-28-kg-ontology-redefinition.md` §3 補足 | 既に短く触れている ODS 二層 |

---

## 1. 結論（先に）

| 問い | 答え（公開情報ベース） |
| :--- | :--- |
| ODS は「OWA 一択」か？ | **いいえ。** Ontology Product は OWA、Data Product は **選択的 CWA** の二層（DPQM） |
| 大勢の企業が集まるのに OWA で問題ないのか？ | **意味の発見・相互運用の層では意図的。** 未宣言＝偽と断定すると、多様性と不完全な自己宣言を包摂できない、というのが IPA の論拠 |
| では取引・運用データも「書いてない＝不明」でよいか？ | **ODS 自身もそうは言っていない。** 強い一貫性・検証が要る領域は Data Product 側で CWA を入れる |
| 本連載との対立は？ | **対立というより重心の差。** ODS は組織横断の意味層を OWA 基調；本連載は社内エージェント／原価・品質判断のデータ層を CWA 基調 |
| 技術スタックの系譜 | ODS 意味層は **セマンティック Web 後継**（RDF / RDFS / OWL / SPARQL 等）。本連載は **LPG + Pydantic/YAML 契約**（L5 OWL 推論は採らない） |

一文:

> ODS の OWA は「企業間で意味が揃う前に偽と落とさない」ための開放弁。本連載の CWA は「書いてない関係をエージェントに補完させない」ための拒否弁。同じフェデレーションでも、**何を最優先するか**が違う。

---

## 2. 二つの世界観（定義の揃え）

| | 開世界仮説（OWA） | 閉世界仮説（CWA） |
| :--- | :--- | :--- |
| 古典的読み | 載っていない事実は **偽とは限らない**（真／偽／不明） | 載っている集合がその時点の世界の全部。無いものは無い |
| 典型スタック | RDF・OWL・Reasoner・SPARQL | RDB・多くの API・LPG + スキーマ検証 |
| 失敗モード | 不完全な宣言を「誤り」として排除しすぎ、接続が始まらない | 未知を推論で埋め、監査不能な「事実」が増える |
| 向く場面 | 組織横断・語彙進化・発見（Discoverability） | 書き込み拒否・合否・原価／安全の決定論 |

本連載での言い換え（すでに Season4 で使用）:

- OWA … 「書いてない＝偽ではない」
- CWA … 「契約にない＝無効／拒否」

---

## 3. ODS 側：公開情報が言うこと

### 3.1 スタックと系譜（セマンティック Web の後継）

英語版 Why Open Dataspaces PDF は、意味表現に次を明示する（要約）:

- **RDF / RDF\*** … 観測事実・語彙・出自を分散可能な知識単位として保持
- **RDFS** … 語彙と構造
- **OWL** … 妥当性・排他などの制約、意味的矛盾の扱い
- 実装・参照 … ODS Middleware（ODP の参照実装 OSS）、SPARQL 系 Discovery／キャッシュ（本リポの L4 クローンでも `L4-crawler-service` 等が SPARQL / RDF Patch を扱う）

IPA は同時に、欧州の **Eclipse Dataspace / IDS 系の仕様そのものとは設計原則が異なる** と述べる（同 PDF）。  
したがって整理としては:

| 言ってよい | 言い過ぎ |
| :--- | :--- |
| 意味層は **RDF/OWL/SPARQL というセマンティック Web 系譜** | 「ODS＝Eclipse Dataspace Components そのもの」 |
| Middleware / L4 OSS が RDF グラフ操作に乗る | すべてが Eclipse RDF4J 一本、と断定（実装詳細は版依存） |

### 3.2 DPQM：OWA と CWA の二層（ここが核心）

IPA 公開要約の文言（要旨）:

> Ontology Product では「（真と）判断できないことは、偽ではない」＝**OWA**。  
> Data Product では **CWA を選択的に導入**。  
> この二層が、提供者と利用者の期待のトレードオフを埋める。  
> あわせて **Schema Flexible**（先にインスタンス、後から意味）を採る。

英語 PDF の補強（要旨）:

- OWA は、ドメインオーナーが自己宣言する Data Product の **多様性を積極的に包摂**するのに最も相性が良い
- ただし未宣言情報の完全性は保証できない
- 従来の Push and Ingest（集約）は CWA 寄りだったが、組織横断では「全データを有限集合として事前定義」は原理的に不可能
- だから Ontology Product＝OWA、Data Product＝選択的 CWA

Speaker Deck 等の二次まとめでも、「OWA 基調＋選択的厳格性で CWA を内包」「均質な完全性強制ではない」と読まれている（一次ソースは上記 IPA 文書）。

### 3.3 「大勢の企業が集まるのに OWA で問題ないのか？」への ODS 側の答え

公開設計から読み取れる論理は次のとおり。**「場全体を OWA のまま運用する」のではなく、「どの層で開くか」を分けている。**

| 懸念 | ODS 設計上の応答 |
| :--- | :--- |
| 意味がバラバラなのに繋げないと始まらない | **Ontology Product を OWA** にし、未接続・不完全な語彙を「偽」と落とさない。Dynamic Ontology / LLM でギャップを知識へ成熟させる（OSI） |
| 偽の事実が流通したら危険 | 実データへのアクセスは **Data Query（第二段）**。強い保証が要る領域は Data Product で **CWA 選択** |
| 誰が何を使えるか無秩序 | 意味の開放とは別に **IUC（Identity and Usage Control）** で信頼を設計対象にする |
| カタログが静的マスタに固まる | DAD：Ontology Query（Best Effort）→ Data Query。カタログはクエリ依存の動的ビュー |

つまり「多社が集まる場」で必要なのは、**最初から全員の語彙を閉世界で揃えることではなく、揃う前でも発見・交渉・段階的合意ができること**。OWA はその開放弁。厳格さは Data Product / Usage Control 側に寄せる——これが公開文書上の答え。

### 3.4 ODS が「開いている」対象と「閉じてよい」対象

| 層 | 仮定の重心 | 例 |
| :--- | :--- | :--- |
| 意味・発見（Ontology Product / Ontology Query） | **OWA** | 語彙の自己宣言、Ontological Gap、Best Effort 検索 |
| 提供データ（Data Product / Data Query） | **選択的 CWA** | 強い一貫性、検証可能インターフェースが要る領域 |
| 利用制御（IUC） | （仮定というより契約・権限） | 誰が・どの条件で使えるか |

### 3.5 Ontology Product 側はどう動くか（公開設計＋作業仮説）

ここは「世界観」だけでなく、**意味層が機械としてどう回るか**の整理。  
表記: **〔公開〕**＝IPA 公開文書に明示／強く示唆。**〔仮説〕**＝公開設計＋ L4 参照実装の読みから立てた作業仮説（Epilogue では仮説と明示すること）。

#### 3.5.1 公開設計が約束している部品

| 部品 | 〔公開〕での役割 |
| :--- | :--- |
| **Ontology Product** | Data Product と表裏の AQ。意味・文脈の提供単位（OWA） |
| **Ontology Endpoint** | ドメイン外に公開する「意味の入口」。内部 ID は温存し、**IRI** でグローバルに指す（DAD） |
| **Data Endpoint** | 実データへの入口（別IF）。意味とデータの分離 |
| **Ontology Query → Data Query** | 二段クエリ。第一段は任意キーワード等に対する **Best Effort**、第二段で実ソースへ |
| **Dynamic Ontology（OSI）** | 意味と構造を分離。組織間で定義が違っても止まらない。**LLM が意味のつなぎを推定**し、**論理的オントロジ規則で検証・洗練**し、「推測 → 検証可能知識」へ成熟 |
| **RDF / RDFS / OWL** | 事実・語彙・制約を分散可能な知識単位として保持（セマンティック Web 系譜） |
| **Schema Flexible** | 先にインスタンス、後から意味付与。全集を事前定義しない |

公式ポータルの Dynamic Ontology 要約（要旨）:  
*definitions differ → LLMs infer semantic connections → validated/refined through logical ontological rules → sharing continues even with incomplete datasets → guesses become verifiable knowledge.*

#### 3.5.1a Dynamic Ontology とは何か〔公開〕

IPA Open Dataspaces が OSI（Ontology and Semantic Interoperability）で掲げる仕組みの名前。  
**「最初から全員の語彙を固定した静的オントロジ」ではなく、運用しながら意味のギャップを埋めていく動的な相互運用**を指す。

公式の流れ（要旨）:

1. **意味と構造を分離**する（データモデルを壊さずに意味だけ進化させられる）  
2. 組織ごとに定義が違っても共有を止めない（OWA・不完全データ可）  
3. **LLM** が語彙・概念の対応を **推定（guess）** する  
4. **論理的なオントロジ規則**（OWL 等の系譜）でその推定を **検証・洗練** する  
5. 通ったものだけが **検証可能な知識（knowledge）** として残る  

| ではないもの | であるもの |
| :--- | :--- |
| 人間が最初に巨大 OWL を書き切る古典 SW そのもの | ギャップがあっても探索を止めないための **成熟ループ** |
| LLM の言い換えをそのまま事実にする仕組み | **推測 → 規則検証 → 知識** の二段（公開説明上） |
| Data Product の認証付き Pull そのもの | Ontology 側（意味のつなぎ）の話。Data Query の前段 |

本連載との対比: 社内 CWA（契約外拒否・L5 不採用）は「書いてない関係を補完しない」。Dynamic Ontology は社外で「書いてない対応を **候補として推定し、検証してから知識化**」する——層が違う。シリーズでは説明と仮説まで（本番パイプライン自作はやらない）。

#### 3.5.2 動かし方の作業仮説（パイプライン予想）

多社が集まる場で「意味が揃う前でも探索できる」ための、想定フロー:

```text
[提供者ドメイン]
  語彙・Aspect・制約・出自 ──登録──▶ Ontology Endpoint（RDF グラフとして公開）
  実データ API / DB     ──別IF──▶ Data Endpoint（IUC の後ろ）

[利用者 / Agentic AI]
  ① Ontology Query（Best Effort）
       │  キーワード / 意図 / 自社語彙
       ▼
     SPARQL 等で分散カタログ・語彙グラフを探索
       │  ヒットは「候補・対応仮説」であり確定事実ではない（OWA）
       ▼
  ② （任意）Dynamic Ontology ループ
       │  LLM: 語彙ギャップの対応候補を推定
       │  OWL/規則: 矛盾・排他・型のチェックで候補を絞り込む
       │  人間 / 契約プロセス: 採用された対応を知識として残す
       ▼
  ③ Data Query
       │  IRI / Endpoint 解決後、許された範囲だけ Pull
       ▼
     Data Product（ここで選択的 CWA・強い検証が効きうる）
```

| 段階 | 何が起きているか（仮説込み） | OWA/CWA |
| :--- | :--- | :--- |
| 登録 | 各社が自分の意味を **自己宣言** して Ontology Endpoint に載せる。完全合意は前提にしない | OWA（不完全でも載せる） |
| Ontology Query | 「同じものを指していそうな語彙・製品」を **Best Effort で候補化**。無い＝偽ではない | OWA |
| Dynamic Ontology | LLM のギャップ埋め ＋ 論理規則の検証。推測をそのまま Data Query の根拠にしない | 中間（推測→検証） |
| Data Query | 実データ取得。権限・利用条件（IUC）と、提供側が選んだ CWA 検証 | CWA 選択可 |
| 成熟 | 採用された対応関係がオントロジ側に残り、次回の Query が少し閉じていく | 運用で徐々に厳密化 |

#### 3.5.3 L4 参照実装から見える「実装寄りの姿」〔仮説〕

本シリーズが触っている ODS L4 OSS（`/Users/yoheionishi/work/open-dataspaces/`）からの読み（詳細は接続検証タスク）:

| コンポーネント | 意味層での予想役割 |
| :--- | :--- |
| `SDK-for-semantics` | Aspect / API / Instance を **JSON-LD** 等に落とし、Discovery に登録（意味の自己宣言の実装入口） |
| `L4-discovery-finder` / `L4-discovery-service` | 「どこに Ontology/Data Endpoint があるか」の解決（DAD の実装面） |
| `L4-crawler-service` | 分散した意味グラフを **SPARQL キャッシュ**し、**RDF Patch** で eventual consistency に追従 |
| `L4-sparql-client-sample` | Ontology Query に相当するクライアント UI の参考 |

つまり Ontology Product は「巨大な中央 OWL を全員が編集する」というより、

> **各社が RDF 系で意味を公開し、Discovery＋SPARQL で候補を引き、LLM＋規則でギャップを埋め、合意できたところだけ知識として残す**

分散カタログ／フェデレーションに近い、というのが作業仮説。

#### 3.5.4 本連載の Graph Contract との対応（予想マッピング）

| ODS Ontology 側 | 本連載の近いもの | 差 |
| :--- | :--- | :--- |
| Ontology Endpoint の語彙グラフ | `schema.py` + Contract の型・Identity | 社内は CWA で拒否；社外公開面は OWA 対話になりうる |
| Ontology Query（Best Effort） | プランナー／候補生成 | ODS は「不明を偽にしない」；本連載 UI は未接地フラグ |
| Dynamic Ontology（LLM＋規則） | （将来）社外語彙アライメント；社内では L5 不採用 | 社内は規則＋人手承認を厚くする想定 |
| Data Query | 決定論的 Cypher ツール | 同型の二段だが、データ側の閉度が本連載の方が強い |
| IRI / Bridge | Bridge Keys | アドレス可能性は同族 |

#### 3.5.5 予想する「うまくいく条件」と「壊れ方」

| うまくいくとき | 壊れ方（監視ポイント） |
| :--- | :--- |
| Best Effort 候補が「仮説」としてラベルされ、Data Query 前に人間／契約ゲートがある | Ontology Query の類似をそのまま業務事実にする |
| Dynamic Ontology の LLM 出力が OWL/規則で弾かれ、ログが残る | 推測がサイレントに RDF へ書き戻される |
| Data Product 側で必要領域だけ CWA | 全層 OWA のまま在庫・合否・課金を扱う |
| RDF Patch / キャッシュの鮮度が SLA として見える | 古い語彙対応のまま Data Query |

Epilogue 用の一文（案）:

> Ontology Product は、多社の語彙を RDF 上に自己宣言させ、SPARQL 的な Best Effort 探索と Dynamic Ontology（LLM＋論理規則）で「まだ揃っていない意味」を候補化し、本当に触るデータだけ Data Product（選択的 CWA）と IUC の後ろに置く——だから開世界でも場が壊れない、というのが公開設計から読める仕組み予想である。

### 3.6 本シリーズで「どこまでやるか」（Ontology / Data Product の線引き）

世界観メモ（本ファイル）と実装・記事（`season3-b2b-ods-connection-plan.md`）を混同しない。  
**執筆・接続の深さは段階で止める。**

#### 3.6.1 段階別の到達点

| 段階 | Ontology Product 側 | Data Product 側 |
| :--- | :--- | :--- |
| **本ファイル（世界観整理）** | 仕組み予想（§3.5）まで。L4 の部品名対応まで | 「選択的 CWA」「IUC の後ろ」と書くまで。API 実装はしない |
| **Epilogue（1記事）** | Graph Contract ≒ 社内 Ontology Product の **対応表**。二段クエリと同型であること。OWA が多社の場で必要な理由 | 「Bridge Key だけ渡しても IUC 的に不十分」と **ギャップを1つ**。実 Pull は予告のみ |
| **Season 4 Build（任意・最小）** | Partner 1社分を `SDK-for-semantics` で Aspect/API/Instance → 登録 → Discovery 解決まで | Endpoint から **stub / mock Pull 1本**（L2 本格はしない）。返却をエージェントが読むところまで |
| **やらない（両側共通）** | ODP 網羅、企業横断 OWL 全集、Dynamic Ontology の本番 LLM パイプライン自作 | 本番 MES/PLM 接続、課金・法務付き Usage Control 実装、L3/L2 Onboarding 本格 |

#### 3.6.2 Ontology 側：やる／止める

| やる | 止める（ここから先は書かない／実装しない） |
| :--- | :--- |
| DPQM の Ontology＝OWA であることの説明 | 「ODS の Ontology を自社の唯一の正本にする」設計 |
| Ontology Query＝Best Effort／候補、という境界 | Ontology Query 結果を業務の確定事実として扱う話 |
| Dynamic Ontology を **公開設計の一文＋仮説** で紹介 | Reasoner／LLM アライメント基盤の自前構築 |
| Graph Contract Identity ↔ Ontology Product のマッピング | 社外公開用 Ontology Endpoint の本番運用設計 |
| L4 なら SDK 登録〜Finder 解決の **摩擦記録** | SAMM/TTL 全仕様の解説、分散カタログ運用の教科書 |

**Ontology で十分なゴール（シリーズ視点）:**  
「意味は OWA で候補化し、社内契約（CWA）とは層が違う」と読者に腹落ちさせ、接続するなら **登録→発見** まで触れればよい。

#### 3.6.3 Data Product 側：やる／止める

| やる | 止める |
| :--- | :--- |
| Data Product＝選択的 CWA、実データは第二段、という位置づけ | 全 Data Product を自前で CWA 実装し直す |
| IUC／Usage Control が「開いた意味」の受け皿であること（ギャップ指摘） | 法務文書・価格交渉プロトコルの実装 |
| Season2 のドメイン DB＋決定論的ツール＝社内 Data Product 相当、と対応づける | 社外 Partner の本番データ契約・SLA 運用 |
| Build なら **1 Endpoint・mock 応答・1 Pull** | 複数 Partner・本番認証基盤・課金メーター |

**Data Product で十分なゴール（シリーズ視点）:**  
「触るデータは閉じて検証する／誰がどう使うかは IUC」と示し、Ontology の Best Effort と混線させない。実装は **モック Pull で二段目があること** が分かれば足りる。

#### 3.6.4 一文での線

```text
Ontology  … 見つける・意味をつなぐ候補（OWA）…… 記事は対応表＋仕組み予想、Build は登録〜発見
Data      … 許された範囲だけ取る（選択的 CWA＋IUC）… 記事はギャップ、Build は mock Pull 1本
止まる所 … 本番データ空間の運用・法務・ODP 網羅・社内 CWA 正本の放棄
```

#### 3.6.5 データアクセスの形態（Ontology 検索との対比）

読者の直感的な対比:

| | Ontology 側（意味） | Data Product 側（事実） |
| :--- | :--- | :--- |
| 入口 | Ontology Endpoint | **別IFの Data Endpoint** |
| 典型操作 | SPARQL 等で語彙・カタログを **Best Effort 探索** | 認証・認可のうえ **Pull（取得）** |
| 公開度 | 発見のために外へ出せる（ただし PEP もありうる） | **原則クローズ。契約・権限のある相手だけ** |
| プロトコル感 | RDF グラフ問い合わせ | **単一形態に固定されない**（下記） |

〔公開〕Why Open Dataspaces / ODS-RAM・ODP から読めること:

1. **Serving and Pull** — データを中央に集約せず、消費側が提供者の Endpoint に取りに行く。  
2. **Ontology と Data はエンドポイント分離** — 意味が分かったあとに、実データ用 URL／サービスへ進む（二段目＝Data Query）。  
3. **AQ 内部** — Ontology Product と Data Product のあいだに **API ゲートウェイ、マルチモーダルなデータ源抽象、トランザクション管理**（構造化／半構造／非構造、同期／非同期）が座るとされる。  
4. **IUC** — 認証（API Key・証明書・アカウント等）と認可。PEP は Data / Ontology 双方の **API ゲートウェイやクエリサーバ** に置き、PDP が ReBAC 等で可否判定。アクセス制御の延長に **Usage Control**（使途・義務）。  
5. **ODP** — 論理 Protocol ＋ **Binding**（実装例として **HTTPS/JSON** などが文書化）。詳細な単一 REST スキーマを思想文書が固定するわけではない。

〔仮説・実務イメージ〕シリーズ Build で触る最小形:

```text
Ontology Query  ──(IRI / Endpoint 解決)──▶
Data Query      ── HTTPS + 認証ヘッダ ──▶ Data Endpoint
                  （JSON / JSON-LD 等の応答を Pull）
```

| ありうる形態（排他ではない） | メモ |
| :--- | :--- |
| **HTTPS API（JSON / JSON-LD）** | ODP Binding・SDK 系で最も見えやすい。シリーズ mock Pull の既定想定 |
| **ファイル／オブジェクト取得** | バッチ・大容量。利用条件は IUC |
| **同期 RPC / 非同期メッセージ** | AQ 内の「同期・非同期」記述に対応 |
| **クエリIF（SQL・SPARQL・その他）** | Data 側にも「クエリサーバ」と書かれるが、**Ontology 用の公開 SPARQL と同義ではない**。認証の裏・契約範囲内 |

**混同しないこと:** Ontology の SPARQL＝「ネットに転がる意味を探す」。Data のアクセス＝「権限付き Endpoint への Pull」。後者を「また SPARQL で全部取る」と決めつけない（提供者の Data Product 設計に依存）。

---

## 4. 本連載側：なぜ CWA に寄せるか

| 動機 | 内容 |
| :--- | :--- |
| 題材 | 原価・製造・品証・エージェント回答。**書いてない関係の暗黙補完は現場混乱** |
| 実装 | LPG（Neo4j）+ Pydantic/YAML Graph Contract。契約外は ingest 拒否（L0–L4）。**L5 OWL 推論は採らない** |
| フェデレーション | Season2 は部門グラフを物理分離し Bridge で結ぶが、**結合ルール自体は契約（CWA 的）** |
| ODS との接続観 | 社外に出るとき Ontology Endpoint は OWA 寄りの対話面になりうるが、**社内運用グラフの既定は CWA のまま**（Season4 §3 補足と同型） |

本連載が一択で ODS を否定しているわけではない。**社内の決定論的ツール境界では CWA、組織横断の意味発見では ODS の OWA 層を参照しうる**——接続は Season3B / Epilogue の主題。

---

## 5. 対立表（執筆・議論用）

| 次元 | IPA ODS（公開設計） | 本連載（Season2/4/5） |
| :--- | :--- | :--- |
| 主戦場 | 組織・国境横断の分散データ | 社内（＋将来 B2B）の信頼できるグラフ＋エージェント |
| 意味層 | Ontology Product＝**OWA 基調** | オントロジ＝**契約**（無いものは拒否） |
| データ層 | Data Product＝**選択的 CWA** | ドメイン DB＝**一貫して CWA 寄り** |
| スキーマ方針 | Schema Flexible（後から意味） | 書き込み前に型・必須辺を固定（shift-left） |
| 推論 | OWL 等を意味整合に使い得る（設計文書） | 暗黙導出はせず、決定論的 traversal + LLM 要約 + Grounding |
| クエリ二段 | Ontology Query → Data Query | プランナー → 決定論的 Cypher（同型のミニ版） |
| 技術系譜 | RDF / RDFS / OWL / SPARQL（セマンティック Web 後継） | LPG / Cypher / Pydantic / YAML |
| 「多社が集まる」への答え | 意味層を開けて包摂し、厳格さは選択的 | まず社内を閉じて信頼し、外は Contract / IUC で足す |

---

## 6. よくある誤解（公開情報で潰す）

| 誤解 | 訂正 |
| :--- | :--- |
| ODS＝全部 OWA だから嘘でも通る | Data Product と IUC がある。OWA は主に **Ontology Product** |
| 本連載＝ODS と相容れない | 層が違う。接続時は Ontology＝対話面、社内グラフ＝CWA のまま、が既存メモの筋 |
| セマンティック Web は死んだので ODS は古い | IPA は Agentic AI・ダークデータ・組織横断を動機に、**系譜を意図的に再利用**している |
| Eclipse Dataspace＝ODS | IPA は **別設計原則** と明言。混同しない |
| OWA だから品質ゲート不要 | むしろ Usage Control・選択的 CWA が品質・権利の受け皿 |

---

## 7. 記事・Epilogue に載せるときの推奨トーン

1. **先に二層（DPQM）を出す** — 「ODS は OWA」だけで終わらせない  
2. **「多社が集まる」問題を ODS 自身の言葉で解く** — 多様性包摂・Schema Flexible・完全性は Data Product 側  
3. **本連載の CWA は敵視ではなく安全側の重心** — 原価・品証・エージェント  
4. **接続図は1枚で足りる** — Ontology Endpoint（OWA 寄り）↔ Graph Contract / 社内 DB（CWA）  
5. **Ontology 側の仕組みは §3.5** — 二段クエリ＋Dynamic Ontology。仮説は仮説と書く  
6. **やらないこと** — ODP 網羅、法務詳細、Eclipse/IDS 逐語解説（`season3-b2b-ods-connection-plan.md` §9 に準拠）

---

## 8. 一次ソース・参照リンク（公開）

| 種別 | URL |
| :--- | :--- |
| 設計思想（JP） | https://www.ipa.go.jp/digital/architecture/reports/open-dataspaces-design-philosophy.html |
| 設計思想（EN PDF） | https://www.ipa.go.jp/en/digital/architecture-guidelines/individual-link/p1o1lf000001xv4n-att/WhyOpenDataspaces_en.pdf |
| ODS ポータル（EN） | https://www.ipa.go.jp/en/digital/opendataspaces/ |
| 成果物公開プレス（2026-04-01） | https://www.ipa.go.jp/en/pressrelease/press20260401.html |
| 本シリーズ既存記述 | `articles/2026-06-28-kg-ontology-redefinition.md`（§3 ODS 補足） |
| 接続企画 | `instructions/season3-b2b-ods-connection-plan.md` §4 |

ローカル（gitignore、公開記事には直接貼らない）: `raw/ods/`、`/Users/yoheionishi/work/open-dataspaces/`（L4 OSS）。

---

## 9. 残作業（任意）

- [ ] Epilogue 下書きに §5 対立表を1節で移植（網羅禁止）
- [ ] Epilogue または別メモに §3.5 のパイプライン図を「仮説」ラベル付きで載せる
- [ ] L4 Middleware の README から「実際に使う RDF ストア／SPARQL エンジン名」を1行追記（実装事実の裏取り）
- [ ] Season0 第2部執筆時に本メモへ相互リンク
- [ ] `SDK-for-semantics` の Aspect→JSON-LD→register を1本トレースし、§3.5.3 の仮説を実証／修正

---

改訂履歴:

| 日付 | 内容 |
| :--- | :--- |
| 2026-07-23 | 初版。IPA 公開文書に基づき OWA/CWA 二層と本連載重心差を整理 |
| 2026-07-23 | §3.5 追加。Ontology Product の動き方（公開設計＋作業仮説パイプライン） |
| 2026-07-23 | §3.6 追加。Ontology / Data Product それぞれ「どこまでやるか」の線引き |