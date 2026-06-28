# Zenn 本構成案：エンタープライズ AI の「意味の層」

## 1. 本書のテーゼ（2026 年時点の整理）

シーズン1〜3の連載を通じて見えてきた **一本の線** を、本書の主題とする。

> エンタープライズ AI のボトルネックは、いつも **「意味の層」** にある。  
> 推論器（LLM）やクエリ技法（Text-to-SQL / GraphRAG）は進化するが、**ビジネス定義・関係・信頼すべき資産をどう構築・維持するか** という問いは、1960 年代後半から **似た形で繰り返し** 現れている（本格化は 1970 年代の知識表現研究）。

2026 年の業界動向は、この問いに対する **二つの現代的な答え** が同時に成熟し始めたことで特徴づけられる。

| 動向 | 代表例 | 解くレイヤー | 連載上の位置づけ |
| :--- | :--- | :--- | :--- |
| **仮想グラフ** — DWH 上に関係を重ね、物理移動なしでグラフ的に辿る | Snowflake / Databricks / Google の Virtual Graph、Neo4j 連携 | ① データの辿り方・型の固定 | **シーズン1** |
| **論理フェデレーション** — 部門・システムを物理統合せず、共通 ID でクエリ時だけ横断 | Bridge Keys、Graph Contract、決定論的ツール | ② 組織境界の結合 | **シーズン2** |
| **オントロジー自動構築** — 利用統計からビジネス定義を抽出・裁定 | Databricks Genie Ontology / OntoRank、Snowflake Cortex Sense | ③ プラットフォーム内の定義裁定 | **シーズン3**（執筆済み） |

**本書が伝える結論（現時点）**

- **全部を人力でオントロジー・知識グラフを書く必要はなくなりつつある**（③ はプラットフォームに委ねられる領域が広がった）。
- しかし **全部を自動に任せてよいわけではない**。競争優位に直結するコアドメイン（①）と、部門横断の結合契約（②）は、**ドメインエキスパートとアーキテクトが設計・合意** する必要がある。
- 古典（セマンティック Web、OWL、述語論理）で挫折した問題が **別の入力（クエリログ・カタログ）と別の裁定（PageRank 型）** で再登場している——歴史を知ると、2026 年の製品発表が「突然」に見えなくなる。

---

## 2. 本書タイトル・対象読者

### タイトル案

**第1候補（推奨）**  
`エンタープライズ AI の意味の層 — 2026年のプラットフォーム動向から、三層設計と知識表現の歴史へ`

**第2候補（短め）**  
`意味の層を設計する — 仮想グラフ・論理フェデレーション・自動構築のいま、とオントロジーの系譜`

**旧案（歴史先出し・非推奨）**  
`エンタープライズ AI の意味の層 — オントロジーと知識グラフの歴史から、…`

### 対象読者

| 読者 | 得られるもの |
| :--- | :--- |
| データ基盤 / ML エンジニア | Snowflake・Databricks のコンテキストレイヤーを、シリーズ全体の中で位置づけられる |
| ドメインエキスパート・アーキテクト | 「どこまで自動化し、どこに介在すべきか」の設計枠組み |
| KG / セマンティック Web 経験者 | 古典と現代製品の **同型性**（知識獲得ボトルネックの再発）の地図 |
| Season 1/2 連載既読者 | 本書で三層スタックが **一冊に閉じた形** で読める（連載とは別原稿） |

### 本書と Zenn 連載記事の関係（執筆方針）

**本書は連載記事の収録・転載ではない。** シーズン0〜3で得た論点・構成・コードは **たたき台** とし、**すべて本用に丸ごと書き直す**。

| 方針 | 内容 |
| :--- | :--- |
| **本書内** | 既に Zenn 公開済みの連載記事への **リンクは貼らない**（章間参照・部内参照のみ） |
| **本書外** | `articles/` の連載はそのまま無料記事として残す（本の **予告編・入門編** として機能しうるが、本は依存しない） |
| **重複** | 同じテーマを扱うが、 prose・構成・例示は本専用に再設計する（連載向け `:::message` やシリーズ誘導は本には不要） |
| **コード** | コンパニオンリポジトリは共有可。本では **本用の抜粋・説明** を載せ、記事と同一段落のコピペはしない |

**執筆時の参照（著者用・読者には見えない）**

| 本の章 | たたき台（`articles/`） | 企画メモ（`instructions/`） |
| :--- | :--- | :--- |
| 第4–6章 | `vkg-strategy-what` / `2` / `3` | — |
| 第7–9章 | `supply-chain-impact-analysis-agent` ×3 | `supply-chain-neo4j-migration-plan.md` |
| 第1–2章 | `genie-ontology-ontorank` / `cortex-sense-genie-ontology` | — |
| 第10–12章 | （未執筆） | `season0-part{1,2,3}-outline.md` |

---

- ODS / B2B データスペース接続（→ `season3-b2b-ods-connection-plan.md`）
- 本番信頼・Evidence・監査の運用編（→ `season3-production-trust-series-plan.md`）
- マルチモーダル / Lance 系（→ `season-wm-lance-series-plan.md`）

---

## 3. 全体構成（Zenn 本 = 1冊・5部構成）

Zenn 本は **章ごとに新規原稿** を `books/` に置く。連載 `articles/` からの転載・相互リンクは行わない。

### 3.1 叙事の型（読者向け・標準ルート）

**歴史から入らない。** 教科書型の「古代から現代へ」ではなく、実務者が現場で飲み込む順に並べる。

```text
  今何が起きているか
       ↓
  なぜそうなっているか（三層・意味の層）
       ↓
  現実にどう作るか（①② の How）
       ↓
  歴史的背景（似た問題の繰り返し）
       ↓
  設計で閉じる（チェックリスト・WS）
```

| 幕 | 読者の問い | 本での位置づけ | 章番号＝`chNN` |
| :--- | :--- | :--- | :--- |
| **1. 今** | 2026年、業界は何を発表しているか | 入口。製品・動向の地図 | 前書き → **第1–2章** |
| **2. なぜ** | なぜ仮想グラフ・フェデレーション・自動構築なのか | 三層スタックで問題を整理 | **第3章** |
| **3. どうやる** | 自社で何を設計・実装するか | ①② の手触り | **第4–9章** |
| **4. 歴史** | これは突然ではないのか | KR 系譜・同型パターン（**中盤以降**） | **第10–12章** |
| **5. 閉じる** | 持ち帰って使えるか | 比較表・索引・WS | **第13–15章**＋付録 |

**章番号の原則:** **第N章 ＝ `chNN-*.md` ＝ 目次の N 番目**（掲載順と一致）。部番号（第I〜V部）は制作メモ用。

### 3.0 章番号・ファイル対応表

| 章 | ファイル | 部（制作） | 幕 | タイトル（案） |
| :---: | :--- | :--- | :--- | :--- |
| — | `preface.md` | — | — | 前書き |
| 1 | `ch01-ontorank.md` | 第IV部 | 今 | Genie Ontology と OntoRank |
| 2 | `ch02-cortex-sense.md` | 第IV部 | 今 | Cortex Sense と二社の収束 |
| 3 | `ch03-three-layer-stack.md` | 第V部 | なぜ | 三層スタックの全体像 |
| 4 | `ch04-virtual-graph.md` | 第II部 | どうやる | 仮想グラフ戦略 |
| 5 | `ch05-why-graph.md` | 第II部 | どうやる | 知識グラフと推論 |
| 6 | `ch06-core-domain-layer.md` | 第II部 | どうやる | コアドメイン層の構築 |
| 7 | `ch07-federation-problem.md` | 第III部 | どうやる | 分断されたグラフと影響分析 |
| 8 | `ch08-federation-design.md` | 第III部 | どうやる | 論理フェデレーションの設計 |
| 9 | `ch09-federation-build.md` | 第III部 | どうやる | 影響分析エージェントの実装 |
| 10 | `ch10-ontology-origins.md` | 第I部 | 歴史 | オントロジーと知識表現の原点 |
| 11 | `ch11-kg-genealogies.md` | 第I部 | 歴史 | 知識グラフの二つの系譜 |
| 12 | `ch12-reasoning-limits.md` | 第I部 | 歴史 | 推論の世界と現場での限界 |
| 13 | `ch13-build-approaches.md` | 第V部 | 閉じる | レイヤー別の構築アプローチ |
| 14 | `ch14-code-index.md` | 第V部 | 閉じる | サンプルコード・リポジトリ索引 |
| 15 | `ch15-design-workshop.md` | 第V部 | 閉じる | 設計ワークショップ |

**制作上の部番号（第I〜V部）** は企画・執筆メモ用。読者には **第1章から順に読む** だけでよい（§8 `chapters:` も同順）。

### 3.2 部構成（制作ビュー）

```text
┌─────────────────────────────────────────────────────────────┐
│  前書き — いまの現場と本の約束                               │
├─────────────────────────────────────────────────────────────┤
│  第IV部  現在編C — プラットフォームによる意味の自動構築（③）│  ← 読者はここから
│  第V部   第3章 — 三層スタック（なぜ）                        │
│  第II部  現在編A — 仮想グラフとコアドメイン層（①）                   │
│  第III部 現在編B — 論理フェデレーション（②）                  │
│  第I部   過去編 — 知識表現と推論の世界                        │  ← 歴史はここ（中盤以降）
│  第V部   第13–15章＋付録 — 設計で閉じる                       │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 標準読み順（本の目次＝掲載順）

```text
前書き
→ 第1章 → 第2章          【今：Summit・OntoRank・Cortex Sense】
→ 第3章                   【なぜ：三層スタック】
→ 第4章 → 第5章 → 第6章    【どうやる：①】
→ 第7章 → 第8章 → 第9章    【どうやる：②】
→ 第10章 → 第11章 → 第12章    【歴史：だから似た話が繰り返される】
→ 第13章 → 第14章 → 第15章 【閉じる：設計・索引・WS】
→ 付録A → 付録B
```

**章番号 ＝ 掲載順 ＝ `ch01`〜`ch15`。** 本文では「第N章」で相互参照する（部名「歴史編」も併用可）。

### 3.4 読者別ルート

| ルート | 順序 | 想定読者 |
| :--- | :--- | :--- |
| **標準（推奨）** | §3.3 のとおり | データ基盤・ML・アーキテクト全般 |
| **動向だけ先に** | 前書き → 1–2 → 3 → 13 →（必要なら4–9）→ 10–12 → 15 | 製品選定・構想段階のリーダー |
| **実装優先** | 前書き → 3 → 4–9 → 14 → 15 → 1–2 → 10–12 | 手を動かすエンジニア |
| **古典 KG 経験者** | 前書き → 3 → **10–12** → 1–2 → 4–9 → 13–15 | 歴史を早めに読んでもよいが **第1章を歴史にしない** |

---

## 4. 部別詳細

### 前書き（新規・1章相当）

| 節 | 内容 |
| :--- | :--- |
| いま現場で起きていること | Summit 前後の仮想グラフ・コンテキストレイヤー・OntoRank / Cortex Sense（**歴史の前に現状**） |
| なぜ「意味の層」という語か | LLM エージェント時代のボトルネックを一言で |
| 本書の歩き方 | **今 → なぜ → 実装 → 歴史 → 設計** の5幕（§3.3）。歴史は中盤以降 |
| 三層スタック早見表 | ①②③ の対応（詳細は第3章） |
| 本書とコンパニオンリポジトリ | `supply-chain-impact-analysis-agent` との関係 |
| 読み方ガイド | 標準 / 動向優先 / 実装優先 / KG 経験者（§3.4） |

---

### 第I部：過去編 — 知識表現と推論の世界（Season 0・**新規執筆**）

**読者向け位置づけ:** **第4幕（歴史）**。標準ルートでは第1–3章・第4–9章の **後**（第10–12章）。「本の第1章を歴史にする」教科書構成にはしない。

**目的:** 「似た問題を、時代ごとに似た形で解いてきた」という **歴史の芯** を渡す。企画 [`season0-ontology-kg-series-plan.md`](./season0-ontology-kg-series-plan.md) および [`season0-part{1,2,3}-outline.md`](./season0-part1-outline.md) を **アウトライン** として本用に書き下ろす。

**スコープ（歴史編の導入で宣言する）**

> 本書がたどる「古典」は、チェスや画像認識の AI 史ではなく、**意味をデータとして表現し、推論し、なぜその構築がボトルネックになったか** を問い続けてきた **知識表現（KR）・オントロジー・知識グラフ** の系譜である。起点は 1960 年代後半の意味ネットワーク、本格化は 1970 年代のフレームとエキスパートシステム、挫折の言語化は 1980 年代の知識獲得問題、再挑戦は 2000 年代のセマンティック Web、統計による回収は PageRank から OntoRank へ続く。

| 章 | タイトル（案） | 時代・テーマ | 執筆状態 |
| :--- | :--- | :--- | :--- |
| **第10章** | オントロジーと知識表現の原点 | **1960年代末〜1980年代**（中心は 1970 年代）：意味ネットワーク、フレーム、ルール・述語論理、知識獲得のボトルネック | 未執筆（outline あり） |
| **第11章** | 知識グラフの二つの系譜 | 1990s–2000s：Gruber・RDF/OWL/セマンティック Web vs プロパティグラフ | 未執筆（outline あり） |
| **第12章** | 推論の世界と現場での限界 | 1980s–2000s（横断）：記述論理、OWL 推論、計算複雑性、エンタープライズでの挫折 | 未執筆（outline あり） |

**第I部で扱う古典研究（系譜）**

| 区分 | 分野・代表 | 本書との関係 | 主な配置 |
| :--- | :--- | :--- | :--- |
| **中核** | 意味ネットワーク（Quillian；Collins & Quillian 1969） | ノード＋ラベル付きエッジの原点。① の概念祖先 | 第10章 |
| **中核** | フレーム（Minsky 1974） | スロット・継承・デフォルト。スキーマ設計の元型 | 第10章 |
| **中核** | ルールベース推論・エキスパートシステム（MYCIN 等） | 決定論的ツール（②）の思想的祖先 | 第10章 |
| **中核** | 述語論理・定理証明（Resolution、Prolog） | OWL／記述論理への橋 | 第10章・第12章 |
| **中核** | 知識獲得のボトルネック（知識工学） | 本書テーゼの芯。SW 挫折・③ への接続 | 第10章 |
| **中核** | 記述論理 → OWL | 推論は可能でも構築・スケールで破綻 | 第12章（第11章から接続） |
| **中核** | セマンティック Web（RDF、RDFS、OWL、SPARQL） | 「人力で意味を先に書く」路線の頂点 | 第11章 |
| **中核** | プロパティグラフ系譜（Neo4j 等） | RDF とは別の実務路線 | 第11章 |
| **関連（古典 AI 枠外）** | オントロジー工学（Gruber 1993） | 「オントロジー」の工学用語定義 | 第11章冒頭 |
| **関連（古典 AI 枠外）** | PageRank（1998）、OntoRank / Swoogle（2005） | 意味の統計的復元。③ の直接祖先 | 第11章末・第1章へ伏線 |
| **脚注程度** | Cyc、SHRDLU、スクリプト理論 | 対比・例示用。詳述しない | 第10章 |
| **対象外** | 画像認識・ロボティクス・ゲーム探索・強化学習 | 意味の層問題の別軸 | 第I部では扱わない |
| **対象外** | 接続主義・パーセプトロン | AI 冬に 1 文程度。回収点は LLM＋グラフ融合 | 前書きまたは第4部で言及 |

**第I部で必ず押さえる歴史の「同型パターン」**

| 時代 | 問い | 当時の答え | 限界 | 2026 年の対応 |
| :--- | :--- | :--- | :--- | :--- |
| 1960s 後半 | 概念をどう結ぶか | 意味ネットワーク（is-a、part-of） | 小規模実験に留まる | ① 仮想グラフ上の関係 |
| 1970s–80s | 知識をどう表現・推論するか | フレーム、ルール、述語論理 | スケールしない知識獲得 | ③ 統計的抽出 |
| 1980s–90s | 知識を誰が書くか | 知識工学、Cyc（人力の極端例） | 獲得コストが支配的 | ①② はエキスパート介在 |
| 1990s–2000s | 意味を Web 規模で共有するか | RDF、OWL、セマンティック Web | 人力メンテナンス破綻 | OntoRank / Cortex Sense |
| 2000s–10s | 大規模データをどう辿るか | PageRank、リンク構造 | 社内データはリンクが薄い | UC / Horizon 上の利用統計 |
| 2010s–20s | グラフで推論するか | 知識グラフ、GraphRAG | 構築コスト | ① 仮想グラフ + ② フェデレーション |
| 2020s– | LLM に任せるか | Text-to-SQL、Agent | ハルシネーション | 決定論的ツール + ③ 定義裁定 |

**第I部 章別の入出力（執筆時の境界）**

| 章 | 入れる | 入れない |
| :--- | :--- | :--- |
| **第10章** | 意味ネット、フレーム、ルール、述語論理、MYCIN、知識獲得ボトルネック | 画像 AI、ゲーム AI、ロボティクス |
| **第11章** | Gruber、RDF/OWL/SW、SW の挫折、プロパティグラフ系譜、PageRank の位置づけ | Web 技術全般の詳説 |
| **第12章** | 記述論理、OWL 推論、計算複雑性、エンタープライズ限界 | 推論アルゴリズムの網羅的解説 |

**歴史編の文体:** 各章冒頭で **第1–3章で見た現象へのバックキャスト**（「OntoRank はなぜ突然ではないか」）から入る。年表の羅列から入らない。

**サンプルコード（第I部）:** Turtle / SPARQL / Cypher の **概念断片のみ**（`COMP-103 --USED_IN--> PROD-901` 共通題材）。実行環境は載せない。詳細は `season0-ontology-kg-series-plan.md` §5。

---

### 第II部：現在編A — 仮想グラフとコアドメイン層（①・**書き直し**）

**読者向け位置づけ:** **第3幕（どうやる・①）**。第3章の直後。

連載シーズン1と同テーマ。たたき台は `articles/2026-05-30-vkg-strategy-*.md`（著者参照用のみ）。

| 章 | タイトル（案） | 本書での役割 |
| :--- | :--- | :--- |
| **第4章** | 仮想グラフ戦略 | ① の入口：なぜ DWH 上に仮想グラフか |
| **第5章** | 知識グラフと推論 | グラフ・オントロジーが推論に効く理由（**本章内で用語を再定義**。歴史編は後追いの深掘り） |
| **第6章** | コアドメイン層の構築 | **ドメインエキスパート介在領域（①）** の How：Pydantic・変更管理 |

**書き直し時の方針**

- 歴史編を読んでいなくても成立するよう、第5章で必要な用語は **自己完結**
- 歴史編（第10–12章）への参照は **「のちの歴史編で」** の先取り・後追い参照に統一

- 連載向けの「シーズン2へ続く」誘導は削除し、第III部への **部内参照** に置換
- 第6章末で「③ に任せる領域 vs ① で固定する領域」を述べ、第3章へ **回指**
- 製品名・ベンダー比較は必要最小限に整理（本全体のトーンに合わせる）

---

### 第III部：現在編B — 論理フェデレーション（②・**書き直し**）

**読者向け位置づけ:** **第3幕（どうやる・②）**。第II部の直後。

連載シーズン2と同テーマ。たたき台は `articles/2026-06-06-supply-chain-impact-analysis-agent*.md`。

| 章 | タイトル（案） | 本書での役割 |
| :--- | :--- | :--- |
| **第7章** | 分断されたグラフと影響分析 | ② の Problem：組織分断 |
| **第8章** | 論理フェデレーションの設計 | **ドメイン合意領域（②）**：Bridge Keys、Graph Contract |
| **第9章** | 影響分析エージェントの実装 | Build：決定論的ツール、コンパニオンリポジトリ |

**書き直し時の方針**

- 製造業シナリオは **本書用に再構成**（業界共通の抽象を先に、事例は後）
- Text-to-SQL 丸投げ vs 決定論的ツールの対比を第8–9章内で **自己完結**（外部記事へのリンクなし）
- コード引用は本用に選び直し・コメントを本向けに統一

---

### 第IV部：現在編C — プラットフォームによる意味の自動構築（③・**書き直し**）

**読者向け位置づけ:** **第1幕（今）の本編**。標準ルートでは **前書きの直後** に読む。本のフック。

連載シーズン3と同テーマ。たたき台は `articles/2026-06-17-databricks-genie-ontology-ontorank.md` / `2026-06-24-snowflake-cortex-sense-genie-ontology.md`。

| 章 | タイトル（案） | 本書での役割 |
| :--- | :--- | :--- |
| **第1章** | Genie Ontology と OntoRank | **いま③で何が起きたか**。アルゴリズムと第三の道 |
| **第2章** | Cortex Sense と二社の収束 | **いま③の業界地図**。Snowflake / Databricks |

**書き直し時の方針**

- 2章を **1つの部として通読** できるよう統合的な導入・まとめを追加（連載の「前編・本編」分割を解体）
- セマンティック Web や PageRank の詳細は **歴史編へ委譲**（「のちの歴史編で系譜を辿る」と1–2文）
- 第3章への橋：「では①②は誰が設計するのか」を部まとめで示唆
- Summit 資料・第三者記事へのリンクは **参考文献** に集約し、本文は自己完結

---

### 第V部：総合編 — 三層スタックの設計（**新規・本書の核**）

**読者向け位置づけ:** **第3章＝第2幕（なぜ）**、**第13–15章＝第5幕（閉じる）**。第3章は第2章の直後、第13章以降は歴史編の後。

連載各記事の §5 相当の論点を **独立章群として新規執筆** する。実務者が本を閉じたときに持ち帰る「設計ノート」。

| 章 | タイトル（案） | 掲載順での役割 |
| :--- | :--- | :--- |
| **第3章** | 三層スタックの全体像 | **なぜ** ①②③ に分かれるか。責務分界（試読の核） |
| **第13章** | レイヤー別の構築アプローチ | ①②③ 比較（実装を読んだ後の整理） |
| **第14章** | サンプルコード・リポジトリ索引 | コンパニオン実装の読み方 |
| **第15章** | 設計ワークショップ | 自社向けチェックリスト（**最後に読む**） |
| **付録A** | 用語集 | 本書内で定義した用語のみ |
| **付録B** | 参考文献・Further Reading | 学術文献・公式プレス・第三者分析（**正本は §12**） |

#### 第14章：サンプルコードの所在（コンパニオンリポジトリ）

| レイヤー | 内容 | 所在 |
| :--- | :--- | :--- |
| ① コアドメイン層 | Pydantic スキーマ、接続制約 | Season 2 リポジトリ `ontology/schema.py` 等 |
| ② フェデレーション | `graph_contract.yaml`、Bridge Keys | 同リポジトリ `ontology/contract/` |
| ② エージェント | 決定論的ツール、波及分析 | `tools/`、`app/federation_analysis.py` |
| ③ プラットフォーム | UC / Horizon 上の利用統計設計 | **概念章のみ**（製品依存のためコードは原則なし） |
| 第I部 概念例 | Turtle / SPARQL / Cypher 断片 | 本書第I部各章内インライン |

---

## 5. 章数・ボリューム見積

| 区分 | 章数 | 状態 | おおよその分量 |
| :--- | :---: | :--- | :--- |
| 前書き | 1 | 新規 | 3,000–5,000 字 |
| 第I部（過去編） | 3 | 未執筆 | 各 8,000–12,000 字 |
| 第II–IV部 | 8 | **連載から全面書き直し** | 各 8,000–12,000 字（連載より部内接続・冗長削減を想定） |
| 第V部（総合編） | 4 + 付録 | 新規 | 12,000–20,000 字 |
| **合計** | **約16章 + 付録** | | **本1冊（Zenn 有料本想定）** |

---

## 6. 執筆順と掲載順（要約）

**執筆順**（著者用・設計図を先に固める）と **掲載順**（読者用・§3.3）を分ける。

### 6.1 掲載順（本の目次・`config.yaml`）

§3.3 の **今 → なぜ → 実装 → 歴史 → 閉じる** ＝ **第1章から順に読む**（`chapters:` と一致）。

### 6.2 執筆優先順位（著者用）

| 順位 | 作業 | 理由 |
| :---: | :--- | :--- |
| 1 | **前書き + 第3章**（三層の骨格） | 全章の設計図。執筆は先、掲載は第1–2章の直後 |
| 2 | **第IV部**（1–2章・書き直し） | **掲載上の入口**。いまの動向を先に仕上げる |
| 3 | **第II部 → 第III部**（4–9章・書き直し） | ①② の How。リポジトリと同期 |
| 4 | **第I部**（10–12章・書き下ろし） | 歴史編。**掲載は中盤以降**だが、第1章のバックキャスト用に執筆 |
| 5 | **第V部 残り + 付録**（13–15章） | 歴史を読んだ後に閉じる設計編 |
| 6 | **Zenn 本オブジェクト** | `chapters:` を掲載順で登録（§8） |

**詳細な週次計画・公開区分は §11 を参照。**

**書き直しの進め方（推奨）**

1. たたき台記事を横に開き、**見出し構成だけ** 抽出する（本文はコピーしない）
2. 本用アウトラインを `instructions/book-chapter-NN-outline.md` に1章ずつ置く（任意）
3. 初稿は `books/meaning-layer/chNN-*.md` に執筆（`articles/` とは分離）
4. 通読校正で **Zenn 連載 URL・「前編」「シーズン」誘導** が残っていないか確認

---

## 7. 既存 instructions との関係

| ファイル | 本書での位置づけ |
| :--- | :--- |
| `season0-ontology-kg-series-plan.md` | 第I部の **企画正本**（収録ではなく書き下ろしの指針） |
| `season0-part{1,2,3}-outline.md` | 第I部各章のアウトライン |
| `articles/*.md`（連載） | **たたき台のみ**。本には転載・リンクしない |
| `supply-chain-neo4j-migration-plan.md` | 第9・14章の実装整合 |
| `supply-chain-series-articles-review.md` | 書き直し時の論点チェック（任意） |
| `season3-trusted-federation-series-plan.md` | **本書の範囲外**（第2巻「信頼と運用」候補） |
| `season3-b2b-ods-connection-plan.md` | **本書の範囲外**（第2巻「越境接続」候補） |

**ナンバリング注意:** 連載上の「シーズン3（OntoRank / Cortex Sense）」と、企画メモ上の「Season 3A/3B（本番・ODS）」は **別物**。本書は前者を第IV部に、後者は将来の第2巻として分離する。

---

## 8. Zenn 本としてのメタデータ案

```yaml
# book 用（zenn CLI 作成時）— 章は books/ 配下の新規原稿
title: "エンタープライズ AI の意味の層"
summary: |
  2026年の仮想グラフ・論理フェデレーション・オントロジー自動構築（OntoRank / Cortex Sense）
  という「いま」から入り、三層スタックで「なぜ」を整理し、実装の手触りを経て、
  知識表現の歴史（1960年代後半〜）で腹落ちさせ、設計ワークショップで閉じる。
  どこを自動化し、どこにドメインエキスパートが介在すべきか——
  三層スタックで設計する実務ガイド。
  （Zenn 連載記事の収録版ではない。すべて書き下ろし。）
price: 1980  # 推奨レンジ 1,480–1,980。上限は §10 参照
# 章番号＝掲載順（ch01〜ch15 と一致）
chapters:
  - books/meaning-layer/preface.md
  - books/meaning-layer/ch01-ontorank.md
  - books/meaning-layer/ch02-cortex-sense.md
  - books/meaning-layer/ch03-three-layer-stack.md
  - books/meaning-layer/ch04-virtual-graph.md
  - books/meaning-layer/ch05-why-graph.md
  - books/meaning-layer/ch06-core-domain-layer.md
  - books/meaning-layer/ch07-federation-problem.md
  - books/meaning-layer/ch08-federation-design.md
  - books/meaning-layer/ch09-federation-build.md
  - books/meaning-layer/ch10-ontology-origins.md
  - books/meaning-layer/ch11-kg-genealogies.md
  - books/meaning-layer/ch12-reasoning-limits.md
  - books/meaning-layer/ch13-build-approaches.md
  - books/meaning-layer/ch14-code-index.md
  - books/meaning-layer/ch15-design-workshop.md
```

---

## 9. 次のアクション（著者向けチェックリスト）

- [ ] 本構成案の **掲載順（§3.3）** と `config.yaml` の `chapters:` を一致させる
- [ ] §11 の Phase 0（`zenn new:book`・章ファイル雛形）から開始
- [ ] 無料試読章（**前書き + 第3章前半**）と価格を決定（§10・§11）
- [ ] 付録B（`appendix-references.md`）は §12 から章別に抜粋して収録
- [ ] 発売告知記事（任意）で「連載との違い」「第I部・第V部が本だけ」を明示

---

## 10. 販売戦略（公開 / 非公開・価格）

### 10.1 基本方針：二層商品

| 層 | 商品 | 役割 |
| :--- | :--- | :--- |
| **無料** | 既存連載（S1〜3）＋本の一部試読 | 認知・信頼・検索流入 |
| **有料** | Zenn 本（全面書き下ろし） | 歴史・統合叙述・設計ワークショップへの課金 |

連載と本で **同じ話を二重課金しない**。本の価値は情報の新規性より **構成・深度・実務ツール** に置く。

### 10.2 公開（無料）にするもの

| 対象 | 方針 | 理由 |
| :--- | :--- | :--- |
| **Zenn 連載 S1〜3**（全8記事） | ずっと無料・削除しない | ①②③ の入口、SEO・SNS 流入、本の予告編 |
| **コンパニオンリポジトリ** | GitHub 公開（OSS） | 実装の信頼性。コード有料化は拡散と信頼を損なう |
| **本の試読** | 前書き ＋ **第3章**（三層スタック概要） | 連載にない本独自の核を見せ、購入理由を伝える |

**試読にしない方がよい章**

| 章 | 理由 |
| :--- | :--- |
| 第1–2章 | S3 連載と内容が近く、試読で満足されやすい |
| 第4章 | S1 連載と被る。歴史フックには第10章が有効だが一般層には重い |

**第3章の分割案（任意）**  
前半（三層の定義・早見表）を `free: true`、後半（判定基準・事例・WS 用質問）を有料——1章内で無料/有料を分けられる。

**本内から連載 URL は貼らない**（§2 確定方針）。連載側に「本の存在」を1行触れてもよいが必須ではない。

### 10.3 非公開（有料・本のみ）にするもの

| 優先度 | 部・章 | 有料にする理由 |
| :--- | :--- | :--- |
| **最高** | **第I部**（第10–12章） | 連載にない。歴史と同型パターンは本だけ |
| **最高** | **第V部**（第13–15章＋付録）※第3章試読除く | 設計 WS・チェックリスト・用語集・事例マッピング |
| **高** | **第II〜IV部**（第1–2章・第4–9章）書き直し全文 | 連載より通読・部内接続・冗長削減した完成版 |

第II〜IV はテーマは連載と重なるが、**一本の物語としての読み体験** は本のみ。試読を第3章に絞れば、②③ の詳細は有料側に残せる。

### 10.4 公開 / 非公開マップ

```text
【無料・ずっと公開】
  ├─ Zenn 連載 S1（3記事）
  ├─ Zenn 連載 S2（3記事）
  ├─ Zenn 連載 S3（2記事）
  ├─ GitHub コンパニオンリポジトリ
  └─ 本：前書き + 第3章（試読）

【有料・本のみ】
  ├─ 第I部  第10–12章  （歴史・知識表現・推論）
  ├─ 第II部 第4–6章  （仮想グラフ）※書き下ろし版
  ├─ 第III部 第7–9章 （論理フェデレーション）※書き下ろし版
  ├─ 第IV部 第1–2章（オントロジー自動構築）※書き下ろし版
  └─ 第V部  第13–15章 + 付録（第3章試読を除く詳細・WS 一式）
```

### 10.5 価格設定

#### Zenn の制約

- 設定可能範囲：**200〜5,000 円**（100 円単位）
- プラットフォーム手数料：決済手数料 3.6% 控除後の **10%**
- 市場感（2026 年時点）：Zenn 本の中央値は **約 500 円**、平均 **約 986 円**。2,000 円超は少数派

#### 本書の価格に効く要因

| プラス（高くても売れる） | マイナス（高値が効きにくい） |
| :--- | :--- |
| 第I部・第V部は連載にない | S1〜3 で②③の要点は既に無料公開済み |
| 16章・推定 8〜12 万文字規模 | Zenn 上は商業専門書（3,000〜5,000 円）と比較されにくい |
| エンタープライズ / アーキテクト向けニッチ | 個人アカウント・初の有料本は信頼の蓄積が必要 |
| 設計 WS・チェックリストは「社内展開用」価値 | コンパニオン実装は OSS で本外に出る |

#### 推奨レンジ

| 価格 | 位置づけ | 想定 |
| :--- | :--- | :--- |
| **980〜1,480 円** | 堅実・初版 | 連載読者の「お礼買い」も拾いやすい。部数最大化 |
| **1,980 円** | **推奨（収益と部数のバランス）** | 商業技術書の半額感。「歴史＋設計編つきの完成版」として説明しやすい |
| **2,480〜2,980 円** | 上限付近（条件付き） | 第I部の厚み・第15章 WS の実用度・総文字数 10 万超を満たす場合のみ検討 |
| **3,000 円超** | 非推奨 | 無料連載8本との差が価格で説明しきれず、購入率が急落しやすい |
| **5,000 円** | Zenn 上限・実質非推奨 | 個人著者の初版ではほぼ売れない。第2巻＋実績＋法人向けパッケージ化後なら再検討 |

#### 「最も高い値段で、まだ売れる」上限の結論

> **2,980 円** が、本書の現状（連載8本無料・初の有料本・ニッチテーマ）で現実的に狙える **上限**。

根拠：

1. Zenn 本として 3,000 円前後は **既存読者の「比較対象」が商業書にシフト** し、無料連載との重複が厳しく見える。
2. 一方 **1,980 円** は「ランチ1食・社内経費で通る」帯で、第I部（歴史）と第V部（設計）だけでも **連載では得られない** と説明できる。
3. **2,980 円** まで上げるなら、発売時に **総文字数 10 万超・第15章 WS のコピペ可能なチェックリスト・業界横断の事例** を明示し、サマリーで「アーキテクト向け設計手引き」と打つ。
4. **5,000 円** は Zenn 上の天井だが、同内容の無料記事が多い初版では **売上最大化にもならない**（部数減の方が大きい）。

**初版の推奨：** `price: 1980`。発売後 1〜2 ヶ月の販売数・感想を見て、改訂版（第I部増補・事例追加）で **2,480 円** に上げる方が、初版から 2,980 円より総収益は取りやすい。

#### 収益の目安（1,980 円・著者取り分おおよそ 1,718 円/冊）

| 月間販売 | 月間著者取り（概算） |
| :--- | :--- |
| 3 冊 | 約 5,200 円 |
| 6 冊 | 約 10,300 円 |
| 12 冊 | 約 20,600 円 |

連載8本＋試読2章の導線が機能すれば、初月 **3〜6 冊**、安定後 **月 2〜5 冊** は現実的なレンジ。

### 10.6 やらない方がよいこと

1. 連載の有料化・削除 — 流入と信頼の源泉を失う  
2. S3 だけ本に閉じる — すでに無料公開済みで逆効果  
3. コードの有料本限定 — 実装記事との一貫性が崩れる  
4. 試読を第1–2章にする — 連載と被り、試読で目的達成されやすい  
5. 初版から 3,000 円超 — 無料コンテンツとの差分が価格を正当化しきれない

### 10.7 ポジショニング一文（本のサマリー用）

> 2026年の動向から入り、三層で「なぜ」を整理し、実装を経て歴史で腹落ちさせる。**歴史（第I部）と設計 WS（第V部後半）** は連載にない本独自の価値。実装はリポジトリで無料。

---

## 11. 執筆計画（順番・公開区分・マイルストーン）

**前提**

- 執筆順 ≠ 読者の読み順。執筆は **設計図 → 差別化コンテンツ → 書き直し → 総仕上げ**。
- 連載 `articles/` は **たたき台のみ**。執筆中も無料公開のまま触らない。
- 本は **一括発売**（`published: false` で章を溜め、全章初稿＋通読後に `published: true`）。
- 目標総量：**8〜12 万字**。週あたり執筆 **6,000〜8,000 字** を想定すると **全工程 14〜18 週**。

### 11.1 公開区分マスター表

| # | ファイル | タイトル | 部 | 執筆種別 | 公開区分 |
| :---: | :--- | :--- | :--- | :--- | :--- |
| — | `preface.md` | 前書き | — | 新規 | **無料（試読）** |
| 1 | `ch01-ontorank.md` | Genie Ontology と OntoRank | IV | 書き直し | 有料 |
| 2 | `ch02-cortex-sense.md` | Cortex Sense と二社の収束 | IV | 書き直し | 有料 |
| 3 | `ch03-three-layer-stack.md` | 三層スタックの全体像 | V | 新規 | **前半無料 / 後半有料** |
| 4 | `ch04-virtual-graph.md` | 仮想グラフ戦略 | II | 書き直し | 有料 |
| 5 | `ch05-why-graph.md` | 知識グラフと推論 | II | 書き直し | 有料 |
| 6 | `ch06-core-domain-layer.md` | コアドメイン層の構築 | II | 書き直し | 有料 |
| 7 | `ch07-federation-problem.md` | 分断されたグラフと影響分析 | III | 書き直し | 有料 |
| 8 | `ch08-federation-design.md` | 論理フェデレーションの設計 | III | 書き直し | 有料 |
| 9 | `ch09-federation-build.md` | 影響分析エージェントの実装 | III | 書き直し | 有料 |
| 10 | `ch10-ontology-origins.md` | オントロジーと知識表現の原点 | I | 新規 | 有料 |
| 11 | `ch11-kg-genealogies.md` | 知識グラフの二つの系譜 | I | 新規 | 有料 |
| 12 | `ch12-reasoning-limits.md` | 推論の世界と現場での限界 | I | 新規 | 有料 |
| 13 | `ch13-build-approaches.md` | レイヤー別の構築アプローチ | V | 新規 | 有料 |
| 14 | `ch14-code-index.md` | サンプルコード・リポジトリ索引 | V | 新規 | 有料 |
| 15 | `ch15-design-workshop.md` | 設計ワークショップ | V | 新規 | 有料 |
| A | `appendix-glossary.md` | 用語集 | — | 新規 | 有料 |
| B | `appendix-references.md` | 参考文献 | — | 新規 | 有料 |

**本の外（すでに無料・執筆対象外）**

| 対象 | 公開 | 本との関係 |
| :--- | :--- | :--- |
| 連載 S1（3記事） | 無料・維持 | たたき台。触らない |
| 連載 S2（3記事） | 無料・維持 | たたき台。触らない |
| 連載 S3（2記事） | 無料・維持 | たたき台。触らない |
| コンパニオンリポジトリ | 無料・OSS | 第9・14章と整合のみ |
| 発売告知記事（任意1本） | 無料 | 本発売時のみ新規執筆 |

### 11.2 フェーズ別スケジュール

```text
Week 0        準備
Week 1–2      Phase 1  骨格（前書き・第3章）
Week 3–4      Phase 2  第IV部（1–2章）— 掲載上の入口
Week 5–7      Phase 3  第II・III部（4–9章）
Week 8–11     Phase 4  第I部（10–12章）— 掲載は中盤以降
Week 12–13    Phase 5  第V部残り＋付録（13–15章）
Week 14–15    Phase 6  掲載順通読・試読分割・発売
```

### 11.3 Phase 0：準備（Week 0）

| 順 | タスク | 成果物 | 公開 |
| :---: | :--- | :--- | :--- |
| 0-1 | `zenn new:book` で雛形作成 | `books/meaning-layer/config.yaml` | 下書き |
| 0-2 | 章ファイルを空で一括作成 | `books/meaning-layer/ch*.md` | 下書き |
| 0-3 | 三層スタック早見表（1枚）を先に固定 | `instructions/three-layer-stack-reference.md`（著者用） | 非公開メモ |
| 0-4 | 第I部用アウトライン整備 | `season0-part{1,2,3}-outline.md` を本用に更新 | 非公開メモ |
| 0-5 | `config.yaml` に `price: 1980`、章順を §8 どおり登録 | — | 下書き |

**ゲート:** 早見表と部間参照ルール（「第○章で述べた」形式）が書ける状態。

---

### 11.4 Phase 1：骨格（Week 1–2）

**目的:** 全章の設計図。ここで書いた第3章が他章の「北極星」になる。

| 週 | 順 | 章 | 作業 | 目標字数 | 公開 |
| :--- | :---: | :--- | :--- | :--- | :--- |
| 1 | 1 | **前書き** | 初稿 | 3,000–5,000 | **無料試読** |
| 1 | 2 | **第3章** | アウトライン＋前半初稿（§1–3：定義・早見表・責務分界） | 4,000 | **無料試読** |
| 2 | 3 | **第3章** | 後半初稿（§4–6：判定基準・事例・他章への接続） | 4,000–6,000 | 有料 |
| 2 | 4 | — | 第1–2章・第4–9章の **見出しだけ** 抽出（たたき台から。本文コピー禁止） | — | — |

**第3章 無料/有料の境界（執筆時の目安）**

| 節 | 内容 | 公開 |
| :--- | :--- | :--- |
| §1 三層の定義 | ①②③ の一言定義 | 無料 |
| §2 早見表 | 人力/自動/プラットフォーム対応 | 無料 |
| §3 なぜ三層か | 問題提起（LLM 単独の限界） | 無料 |
| §4 判定基準 | どこを誰が設計するかの決定木 | **有料** |
| §5 事例マッピング | 業界横断の当てはめ | **有料** |
| §6 本書の読み方との接続 | 各部への導線 | **有料** |

執筆は **1ファイルに通しで書き**、通読時に `free: true` を front matter で付与（Zenn は章単位）。

**ゲート:** 前書き＋第3章前半を読んで「本を買う理由」が言える。第1–2章・第4–9章の書き直し方針が表に落ちている。

---

### 11.5 Phase 2：第IV部・現在編C（Week 3–4）

**目的:** **読者が最初に読む本編**。2026年動向。歴史は先送りし、現象から入る。

| 週 | 順 | 章 | たたき台 | 目標字数 | 公開 |
| :--- | :---: | :--- | :--- | :--- | :--- |
| 3 | 5 | **第1章** | `genie-ontology-ontorank.md` | 8,000–10,000 | 有料 |
| 4 | 6 | **第2章** | `cortex-sense-genie-ontology.md` | 8,000–10,000 | 有料 |

**書き直しチェック**

- [ ] 歴史の詳細は **歴史編へ委譲**（「のちの歴史編で」）
- [ ] 部まとめで第3章（なぜ三層か）へ橋をかける
- [ ] Summit リンクは参考文献へ

**ゲート:** 第1–2章だけ読んで「2026年に何が起きたか」が伝わる。

---

### 11.6 Phase 3：第II・III部（Week 5–7）

**目的:** ①② の How。第3章を読んだ後の掲載位置。

| 週 | 順 | 章 | たたき台 | 目標字数 | 公開 |
| :--- | :---: | :--- | :--- | :--- | :--- |
| 5 | 7 | **第4章** | `vkg-strategy-what.md` | 8,000–10,000 | 有料 |
| 5–6 | 8–9 | **第5–6章** | `vkg-strategy2` / `3` | 各 8,000–10,000 | 有料 |
| 7 | 10–12 | **第7–9章** | `supply-chain-impact-analysis-agent` ×3 | 各 8,000–12,000 | 有料 |

**ゲート:** 歴史編なしで第4–9章が通読できる。

---

### 11.7 Phase 4：第I部・過去編（Week 8–11）

**目的:** **掲載は第10–12章**だが、第1章（OntoRank）へのバックキャスト用に執筆。

| 週 | 順 | 章 | 参照 | 目標字数 | 公開 |
| :--- | :---: | :--- | :--- | :--- | :--- |
| 8–9 | 13 | **第10章** | `season0-part1-outline.md` | 8,000–10,000 | 有料 |
| 10 | 14 | **第11章** | `season0-part2-outline.md` | 8,000–10,000 | 有料 |
| 11 | 15 | **第12章** | `season0-part3-outline.md` | 8,000–12,000 | 有料 |

**執筆ルール**

- 第10章冒頭で **KR 系譜にスコープを限定**（§4「スコープ」宣言文）
- 各章は **第1–3章で見た現象へのバックキャスト** から入る（年表先出し禁止）
- 意味ネットの起源は Collins & Quillian（1969）から
- 共通題材 `COMP-103 --USED_IN--> PROD-901`

**ゲート:** 歴史編を読むと「OntoRank は突然ではない」と言える。

---

### 11.8 Phase 5：第V部・総合編 残り（Week 12–13）

**目的:** 購入動機の柱。第3章後半と整合させる。

| 週 | 順 | 章 | 内容 | 目標字数 | 公開 |
| :--- | :---: | :--- | :--- | :--- | :--- |
| 12 | 16 | **第13章** | ①②③ 別の構築アプローチ比較表 | 6,000–8,000 | 有料 |
| 12–13 | 17 | **第14章** | リポジトリ索引・読み方 | 4,000–6,000 | 有料 |
| 13 | 18 | **第15章** | WS チェックリスト（コピペ可） | 8,000–12,000 | 有料 |
| 13 | 19 | **付録A・B** | 用語集・参考文献 | 各 2,000–4,000 | 有料 |

**第15章は最後に書く**（歴史編まで含め全論点が揃ってから）。

---

### 11.9 Phase 6：通読・発売（Week 14–15）

| 順 | タスク | 公開への影響 |
| :---: | :--- | :--- |
| 6-1 | **§3.3 掲載順** で通読（歴史が冒頭に来ていないか確認） | — |
| 6-2 | 連載 URL・「シーズン」「前編」残存チェック | — |
| 6-3 | 第3章に `free: true`（前半のみの場合は章分割を検討） | 試読公開 |
| 6-4 | 前書きに `free: true` | 試読公開 |
| 6-5 | `config.yaml` の `chapters:` が掲載順であることを確認 | — |
| 6-6 | `published: true` | **本 1,980 円で発売** |
| 6-7 | （任意）告知記事：「今から入る本」「歴史は中盤」 | 無料記事 |

**発売ゲート（すべて満たしてから公開）**

- [ ] 総文字数 8 万字以上（2,980 円を狙うなら 10 万字）
- [ ] 試読2章（前書き＋第3章前半）がサマリーと一致
- [ ] 第15章 WS が単独で使える
- [ ] 付録A の用語が本文定義と一致

---

### 11.10 執筆順・掲載順の一覧

```text
【執筆順（著者）】
  前書き → 第3章 → 第1–2章 → 第4–9章 → 第10–12章 → 第13–15章 → 付録
  → 掲載順通読 → 発売

【掲載順（読者・§3.3）】
  前書き → 1 → 2 → 3 → 4–6 → 7–9 → 10–12 → 13–15 → 付録

無料試読:
  前書き ＋ 第3章前半（「なぜ三層か」は入口付近で見せる）
```

### 11.11 リスクと代替順序

| 状況 | 代替 |
| :--- | :--- |
| 歴史編が長引く | 第10–12章を改訂版に回し、初版は第1–9章＋第13–15章 — **非推奨**（差別化が薄れる） |
| 発売を前倒ししたい | 同上 |
| 執筆が止まった | 最低セット：前書き＋第1–3章＋第15章。歴史（10–12）なし単体発売は避ける |
| 2,980 円に上げたい | 第15章を厚くし、掲載順通読後に字数 10 万確認 → `price: 2980` |

---

## 12. 参考文献リスト（付録B 正本）

本書 `appendix-references.md` に収録する文献の **著者用マスター**。URL は執筆・改版時に有効性を確認する。  
**本書内から Zenn 連載 URL は貼らない**（§2）が、たたき台・背景としてここでは著者参照用に列挙可。

凡例: 📄 論文 / 🌐 オンライン記事・公式 / 📘 書籍（英） / 📕 書籍（日）

---

### 12.1 知識表現・オントロジー・セマンティック Web（第10–12章）

#### 古典・基礎論文

| 種別 | 文献 | 備考 |
| :---: | :--- | :--- |
| 📄 | Collins, A. M., & Quillian, M. R. (1969). *Retrieval time from semantic memory.* Journal of Verbal Learning and Verbal Behavior, 8(2), 240–247. | 意味ネットワークの実験的基盤 |
| 📄 | Quillian, M. R. (1968). *Semantic memory.* In M. Minsky (Ed.), Semantic Information Processing. MIT Press. | 意味ネットワークの原点 |
| 📄 | Minsky, M. (1974). *A Framework for Representing Knowledge.* MIT AI Lab Memo 306. [PDF](https://courses.media.mit.edu/2004spring/mas966/Minsky%201974%20Framework%20for%20knowledge.pdf) | フレーム理論 |
| 📄 | Shortliffe, E. H. (1976). *Computer-Based Medical Consultations: MYCIN.* Elsevier. | エキスパートシステム・後ろ向き推論 |
| 📄 | Feigenbaum, E. A., & McCorduck, P. (1983). *The Fifth Generation.* Addison-Wesley.（知識獲得ボトルネックの普及的叙述） | 知識工学の文脈 |
| 📄 | Gruber, T. R. (1993). *Toward principles for the design of ontologies used for knowledge sharing.* International Journal of Human-Computer Studies, 43(5–6), 907–928. | オントロジー工学の定番 |
| 📄 | Berners-Lee, T., Hendler, J., & Lassila, O. (2001). *The Semantic Web.* Scientific American, 284(5), 34–43. | セマンティック Web 宣言 |
| 📄 | Baader, F., et al. (Eds.). (2007). *The Description Logic Handbook* (2nd ed.). Cambridge University Press. | 記述論理・OWL 推論の理論 |
| 📄 | Hogan, A., et al. (2021). *Knowledge Graphs.* Morgan & Claypool / OUP. [無料版](https://kgbook.eu/) | 知識グラフの現代テキスト |

#### 標準・仕様（オンライン）

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 🌐 | W3C Semantic Web 標準一覧 | https://www.w3.org/standards/semanticweb/ |
| 🌐 | RDF 1.1 概念・抽象構文 | https://www.w3.org/TR/rdf11-concepts/ |
| 🌐 | OWL 2 Web Ontology Language 概要 | https://www.w3.org/TR/owl2-overview/ |
| 🌐 | SPARQL 1.1 概要 | https://www.w3.org/TR/sparql11-overview/ |
| 🌐 | OWL 2 Primer（W3C） | https://www.w3.org/TR/owl2-primer/ |

#### 統計的意味復元・ランキング

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 📄 | Page, L., Brin, S., et al. (1999). *The PageRank Citation Ranking: Bringing Order to the Web.* Stanford InfoLab. | https://ilpubs.stanford.edu:8090/422/1/1999-66.pdf |
| 📄 | Ding, L., et al. (2005). *Finding and Ranking Knowledge on the Semantic Web.* ISWC 2005.（**OntoRank / Swoogle**） | https://ebiquity.umbc.edu/_file_directory_/papers/197.pdf |
| 🌐 | Swoogle プロジェクト（UMBC） | https://ebiquity.umbc.edu/project/html/id/53/Swoogle |

#### 書籍 — 英語

| 種別 | 文献 |
| :---: | :--- |
| 📘 | Allemang, D., & Hendler, J. *Semantic Web for the Working Ontologist* (3rd ed.). Morgan Kaufmann. |
| 📘 | Hogan, A., et al. *Knowledge Graphs.* OUP / Morgan & Claypool.（[kgbook.eu](https://kgbook.eu/) 無料） |
| 📘 | Baader, F., et al. (Eds.) *The Description Logic Handbook* (2nd ed.). CUP. |
| 📘 | Hitzler, P., Krötzsch, M., Parsia, B., Patel-Schneider, P. F., & Rudolph, S. *Foundations of Semantic Web Technologies* (2nd ed.). CRC Press. |
| 📘 | Heath, T., & Bizer, C. *Linked Data: Evolving the Web into a Global Data Space.* Morgan & Claypool. |
| 📘 | Gómez-Pérez, A., Fernández-López, M., & Corcho, O. *Ontological Engineering.* Springer. |

#### 書籍 — 日本語

| 種別 | 文献 |
| :---: | :--- |
| 📕 | Dean Allemang, James Hendler 著／セマンティックWeb委員会 訳『**実践セマンティックWeb ― RDF/RDFS/OWLによるオントロジー設計ガイド**』オーム社, 2010.（*Semantic Web for the Working Ontologist* 第1版訳） |
| 📕 | 加藤文彦ほか『**オープンデータ時代の標準Web API SPARQL**』インプレス, 2015. [公式](https://sparqlbook.jp/) |
| 📕 | Tom Heath, Christian Bizer 著／**Linked Dataの挑戦**（オライリー・ジャパン訳） |
| 📕 | 勝川宜正『**オントロジー工学**』近代科学社.（古典KG・オントロジー設計） |
| 📕 | 古川雅之『**知識表現と推論**』丸善, 1991.（日本語の古典AI・KR入門） |

---

### 12.2 知識グラフ・グラフDB・GraphRAG（第4–6章）

#### 論文・技術レポート

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 📄 | Edge, D., et al. (2024). *From Local to Global: A Graph RAG Approach to Query-Focused Summarization.* Microsoft Research. | https://arxiv.org/abs/2404.16130 |
| 📄 | Pan, S., et al. (2024). *Unifying Large Language Models and Knowledge Graphs: A Roadmap.* IEEE TKDE survey. | https://arxiv.org/abs/2306.08302 |
| 📄 | Ji, S., et al. (2022). *A Survey on Knowledge Graphs: Representation, Acquisition, and Applications.* IEEE TNNLS. | https://arxiv.org/abs/2002.00388 |

#### オンライン記事・公式

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 🌐 | Neo4j — What is GraphRAG? | https://neo4j.com/blog/genai/what-is-graphrag/ |
| 🌐 | Microsoft — GraphRAG project | https://github.com/microsoft/graphrag |
| 🌐 | Palantir — Ontology overview | https://www.palantir.com/platforms/ontology/ |
| 🌐 | ISO GQL（グラフクエリ言語） | https://www.iso.org/standard/76120.html |

#### 書籍 — 英語

| 種別 | 文献 |
| :---: | :--- |
| 📘 | Robinson, I., Webber, J., & Eifrem, E. *Graph Databases* (2nd ed.). O'Reilly. |
| 📘 | Barrasa, J., & Webber, J. *Building Knowledge Graphs: A Practitioner's Guide.* O'Reilly. |
| 📘 | Needham, M., & Hodler, A. *Graph Algorithms.* O'Reilly / Neo4j. |

#### 書籍 — 日本語

| 種別 | 文献 |
| :---: | :--- |
| 📕 | Jesús Barrasa, Jim Webber 著／『**はじめての知識グラフ構築ガイド**』マイナビ出版, 2024.（*Building Knowledge Graphs* 訳） |
| 📕 | Ian Robinson, Jim Webber, Emil Eifrem 著／『**グラフデータベース**』（オライリー・ジャパン訳） |
| 📕 | 西尾圭亮・石井広・須藤良一 編『**知識グラフと推論**』共立出版.（日本語のKG・推論まとめ） |

---

### 12.3 論理フェデレーション・データ統合・エージェント（第7–9章）

#### 論文・オンライン

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 📄 | Halevy, A., et al. (2016). *Enterprise Information Integration: Successes, Challenges and Controversies.* SIGMOD Record. | エンタープライズ統合の古典 |
| 📄 | Lenzerini, M. (2002). *Data Integration: A Theoretical Perspective.* PODS. | 論理フェデレーションの理論 |
| 📄 | Zhang, J., et al. (2025). *GPA: A Framework for AI Agent Evaluation.*（Snowflake ブログで言及） | https://arxiv.org/abs/2510.08847 |
| 🌐 | Dehghani, Z. *How to Move Beyond a Monolithic Data Lake to a Distributed Data Mesh.* martinfowler.com, 2019. | https://martinfowler.com/articles/data-monolith-to-mesh.html |
| 🌐 | Andrew Jones — *Data Contracts: The What, Why, and How.* | データ契約の実務入門（Confluent / 各社ブログ） |
| 🌐 | コンパニオン実装 `supply-chain-impact-analysis-agent` | https://github.com/yohei1126/supply-chain-impact-analysis-agent |

#### 書籍 — 英語

| 種別 | 文献 |
| :---: | :--- |
| 📘 | Kleppmann, M. *Designing Data-Intensive Applications* (2nd ed.). O'Reilly.（データモデル・統合・信頼の基盤） |
| 📘 | Inmon, W. H. *Building the Data Warehouse* (4th ed.). Wiley.（DWH 古典） |
| 📘 | Kimball, R., & Ross, M. *The Data Warehouse Toolkit* (3rd ed.). Wiley.（ディメンショナルモデリング） |

#### 書籍 — 日本語

| 種別 | 文献 |
| :---: | :--- |
| 📕 | Martin Kleppmann 著／『**データ中心アプリケーション設計**』（オライリー・ジャパン訳） |
| 📕 | 石塚満『**データモデリング標準ガイド**』（データモデリング・ER の定番） |
| 📕 | 日本データベース学会 編『**データベースハンドブック**』オーム社.（統合・モデリングの横断参照） |

---

### 12.4 プラットフォーム・仮想グラフ・2026年動向（第1–3章）

#### 公式ドキュメント・発表

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 🌐 | Databricks — Genie One プレスリリース（2026-06-16） | https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team |
| 🌐 | Databricks — Unity Catalog | https://docs.databricks.com/en/data-governance/unity-catalog/index.html |
| 🌐 | Databricks — Lakehouse / virtualization 概要 | https://www.databricks.com/product/delta-lake |
| 🌐 | Snowflake — Cortex Sense / CoWork プレス（2026-06） | https://www.snowflake.com/en/news/press-releases/ |
| 🌐 | Snowflake — Polaris Catalog（オープンカタログ） | https://www.snowflake.com/en/product/features/polaris-catalog/ |
| 🌐 | Snowflake — Snowflake Intelligence / Cortex Agents ドキュメント | https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents |
| 🌐 | Google Cloud — Spanner Graph / Graph Spanner 発表資料 | https://cloud.google.com/spanner/docs/graph |
| 🌐 | Neo4j — Aura / 仮想グラフ連携（Snowflake Native App 等） | https://neo4j.com/ |

#### 第三者分析・現地レポート（オンライン）

| 種別 | 文献 | URL |
| :---: | :--- | :--- |
| 🌐 | Kazushi 氏 — Data + AI Summit 2026 Keynote（Genie Ontology 現地スライド解説） | https://zenn.dev/kazushi6/articles/3d58cfe511bcc3 |
| 🌐 | Atlan — Snowflake Cortex Sense and the Enterprise Context Layer | https://atlan.com/know/snowflake/snowflake-cortex-sense/ |
| 🌐 | SiliconANGLE — Snowflake moves up the AI stack（2026-06-02） | https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/ |
| 🌐 | Snowflake Engineering Blog — GPA Framework for AI Agent Evaluation | https://www.snowflake.com/en/engineering-blog/ai-agent-evaluation-gpa-framework/ |

#### 書籍 — 英語（プラットフォーム横断）

| 種別 | 文献 |
| :---: | :--- |
| 📘 | Jordan, G., et al. *Fundamentals of Data Engineering.* O'Reilly.（モダンデータ基盤の全体像） |
| 📘 | Sathi, A. *Cognitive Computing with Big Data and the Internet of Things.*（古いが意味層の文脈） |
| 📘 | Marr, B. *Data Strategy.*（ビジネス定義・メトリクス設計の入門） |

#### 書籍 — 日本語

| 種別 | 文献 |
| :---: | :--- |
| 📕 | 山口真一・高橋裕之『**Snowflake 実践ガイド**』など Snowflake 技術書（プラットフォーム操作の補助） |
| 📕 | 日本オラクル／各社『**Databricks / Lakehouse**』関連技術書・ホワイトペーパー（製品名は改版時に差し替え） |
| 📕 | 増井敏克『**データ活用のための分析基盤設計**』など、DWH・セマンティックレイヤー設計の実務書 |

---

### 12.5 LLM・エージェント・Text-to-SQL リスク（横断）

| 種別 | 文献 | URL / 備考 |
| :---: | :--- | :--- |
| 📄 | Lewis, P., et al. (2020). *Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks.* NeurIPS. | RAG 原論文 |
| 📄 | Yao, S., et al. (2023). *ReAct: Synergizing Reasoning and Acting in Language Models.* ICLR. | エージェントループ |
| 🌐 | Anthropic — Model Context Protocol (MCP) 仕様 | https://modelcontextprotocol.io/ |
| 🌐 | dbt — Semantic Layer ドキュメント | https://docs.getdbt.com/docs/use-dbt-semantic-layer/dsl |
| 📘 | Mollick, E. *Co-Intelligence*（英） / 各種 LLM エージェント実務書 | エージェント導入のビジネス文脈 |
| 📕 | 松尾豊・岩澤有祐ほか『**大規模言語モデル**』関連書籍（日本語のLLM入門・多数） | 第3章の LLM 文脈用 |

---

### 12.6 本書執筆のたたき台（著者参照用・本にはリンクしない）

連載8本は無料公開のまま。本書は **書き下ろし** のため、以下は執筆時の論点メモのみ。

| シーズン | ファイル（`articles/`） |
| :--- | :--- |
| S1 仮想グラフ | `2026-05-30-vkg-strategy-what.md` / `vkg-strategy2.md` / `vkg-strategy3.md` |
| S2 フェデレーション | `2026-06-06-supply-chain-impact-analysis-agent{,2,3}.md` |
| S3 自動構築 | `2026-06-17-databricks-genie-ontology-ontorank.md` / `2026-06-24-snowflake-cortex-sense-genie-ontology.md` |
| Season 0 企画 | `instructions/season0-ontology-kg-series-plan.md` / `season0-part{1,2,3}-outline.md` |

---

### 12.7 付録B への収録方針

| 方針 | 内容 |
| :--- | :--- |
| **本編** | 各章末に **3〜8件** の「本章の参考文献」を掲載（§12 から抜粋） |
| **付録B** | §12 全文を **章別インデックス付き** で収録（重複リンクは統合） |
| **優先度** | 無料で読めるもの（W3C、kgbook.eu、arXiv、公式ドキュメント）を厚めに |
| **除外** | 連載 URL・有料ペイウォールのみの記事（要約は本文で言及、リンクは付録に限る） |
| **更新** | プラットフォーム発表（Summit 等）は **年次で差し替え**。歴史文献は固定 |

---

*更新: §3 叙事順「今→なぜ→実装→歴史→閉じる」。**章番号を掲載順に再採番**（第1章＝OntoRank、`ch01`〜`ch15` と一致）。**§12 参考文献マスター**を追加*
