---
title: "Snowflake Cortex Sense は何者か——Genie Ontology と同じコンテキスト革命"
emoji: "❄️"
type: "tech"
topics: ["snowflake", "cortex", "ontology", "aiagent", "knowledgegraph"]
published: true
---

:::message
**連載の位置づけ（[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) → [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) → [シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)）**

本連載の主題は、エンタープライズ AI に必要な **「意味の層」**（ビジネス定義・関係・信頼すべき資産）の設計です。2026年、分析エージェントが製品の中心になるなか、人力オントロジーの限界を **クエリログ等の行動統計で補う** 方向へ、[知識グラフ](https://neo4j.com/blog/knowledge-graph/)・オントロジーがデータプラットフォームで再注目されています（[シーズン1 第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2)、[シーズン3 前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)）。

| シーズン | 問い |
| :--- | :--- |
| [シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)（仮想グラフ） | ① データをどう辿り、型を固定するか |
| [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)（論理フェデレーション） | ② 部門別データをどう結ぶか |
| [シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)（[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)・**[本編](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)**） | ③ どの定義を信頼するか（Genie Ontology / Cortex Sense） |

**本編**は [前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の続きです。Snowflake **Cortex Sense** が Genie Ontology と同型のコンテキストレイヤーであることを整理します。§5 で①②③の実務上の重なりも示します。
:::

## 概要

2026 年 6 月、データインフラの二大巨頭が **ほぼ同時に**、[シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)が論じる **同型のコンテキストレイヤー** を発表しました。製品名は異なりますが、いずれも **オントロジー snippet の自動抽出と、利用統計に基づく定義の裁定** を担います。

| | Snowflake | Databricks |
| :--- | :--- | :--- |
| **発表日** | [Snowflake Summit 26](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/)（6 月 2 日） | [Data + AI Summit](https://www.databricks.com/dataaisummit)（6 月 16 日） |
| **エージェント UI** | [CoWork](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/)（旧 Snowflake Intelligence） | [Genie One](https://www.databricks.com/product/business-intelligence/ai-bi/genie) |
| **コンテキストレイヤー** | **Cortex Sense** | [**Genie Ontology**](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)（**OntoRank**） |

[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)が述べた **第三の道** ——人間に全定義を書かせる方式はメンテナンスが破綻し、LLM に [Text-to-SQL](https://en.wikipedia.org/wiki/Text-to-SQL) を100%丸投げすると誤答（[ハルシネーション](https://en.wikipedia.org/wiki/Hallucination_(artificial_intelligence))）を招く——という二大限界に対し、**プラットフォーム上の利用行動統計から意味レイヤーを自律構築する** アプローチは、Databricks だけの話ではありませんでした。Snowflake は **2 週間早く** 同じカテゴリの製品を出していました。[本記事](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)は、**Cortex Sense** が[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の Genie Ontology と **同じ思想** であることを、公開資料ベースで整理します。

---

## 1. [前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の予言は、すでに実現していた

[前編 §8 ③](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank#8-残る問い自社で何をするか)では、Genie Ontology が Databricks 限定である一方、Snowflake や Google Cloud が **同型機能を追従する可能性** があると書きました。追従は「これから」ではなく、**すでに始まっていた** のです。

Snowflake VP of AI Baris Gultekin は Summit で **「Context determines agent quality（コンテキストがエージェントの品質を決める）」** と述べています（[SiliconANGLE の分析](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/) が引用）。ACV（年間契約額）の定義に無料枠を含めるかどうか——こうした **ビジネス定義の差** を知らない汎用エージェントは、どれだけ推論が巧みでも間違います。

[Harmeet Arora 氏の LinkedIn 投稿](https://www.linkedin.com/posts/harmeetsarora_snowflakesummit-marketinganalytics-agenticai-share-7467805537636700162-wDcZ/) も同型の実務摩擦を指摘しています。マーケティング分析では「MQL の定義」「ファネル各段階のコンバージョン」「アトリビューションロジック」が土台であり、それがドキュメントや個人の暗黙知に閉じていればエージェントは使えない——**定義を明示的・機械可読にし、クエリできる環境に載せる** ことが、AI 分析の本丸だと。

Cortex Sense は、この問いに対する Snowflake 版の回答です。[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)が Genie Ontology に見出したパラダイム——**トップダウンで人間が書くオントロジーの限界を、ボトムアップの利用統計で突破する**——は、Snowflake 側でも独立に実装されていました。

---

## 2. Cortex Sense の正体——実行時コンテキスト強化レイヤー

### 2.1 公式・第三者資料が言っていること

[Atlan の解説](https://atlan.com/know/snowflake/snowflake-cortex-sense/)（Snowflake Summit 現地取材ベース）は、Cortex Sense を次のように定義しています。

> Snowflake Cortex Sense is a runtime context enrichment layer... It lifts CoCo and CoWork accuracy from 47% to 83% by automatically building a shared context substrate from query history, object metadata, BI dashboards, and Horizon Context semantic views.

要するに **実行時（runtime）の文脈強化レイヤー** です。手動でセマンティックモデルを都度設定するのではなく、すでに Snowflake 内に存在するシグナルから **共有コンテキスト基盤（shared context substrate）** を自動構築し、[CoWork](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/)（ビジネスユーザー向けの自然言語データ分析エージェント）と [CoCo](https://atlan.com/know/snowflake/snowflake-coco/)（データエンジニア向けのコーディングエージェント、旧 Cortex Code）がクエリ時に引く——という設計です。

Atlan が引用する「精度（accuracy）」は、**自然言語のデータ質問に対し、ビジネス定義を踏まえて正しい SQL や回答を返せた割合**（複雑なエンタープライズクエリを対象とした Snowflake 内部テスト）を指します。

[Snowflake 公式プレスリリース](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/) は、Cortex Sense を **「データ、ビジネス定義、運用知識を自動的に集約し、AI エージェントが信頼できるコンテキストを即座に使えるようにする」** 機能と説明しています。Christian Kleinerman（EVP of Product）は、シグナルを **収集・強化し、CoCo / CoWork / Cortex Agents に渡す** 能力だとキーノートで述べています（Atlan 記事が引用）。

### 2.2 入力シグナル——Genie Ontology と同型

Cortex Sense が参照するシグナルは、公開資料上、次の 4 系統に整理できます（[Atlan](https://atlan.com/know/snowflake/snowflake-cortex-sense/)・[SiliconANGLE](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/) が一致）。

| シグナル | 役割 | Genie Ontology との対応 |
| :--- | :--- | :--- |
| **クエリ履歴** | 分析者が実際にどのフィールドでフィルタするかから、暗黙の定義を推定 | Unity Catalog 上のクエリログ |
| **オブジェクトメタデータ** | テーブル・カラム名、説明、関係 | カタログメタデータ |
| **BI ダッシュボード** | Power BI / Tableau のメトリクス・Measure——**すでにビジネス検証された定義** | ダッシュボード利用実績 |
| **Horizon Context セマンティックビュー** | 会計年度、売上定義などガバナンス済みの意味定義 | 認証アセット（certified asset）との結びつき |

「手動設定は不要（No manual configuration required）」と Atlan が明記する点も、[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の論点と一致します。**人間が会議で「正しい売上」を決める** のではなく、**観測された利用パターン** からエージェントが参照すべき文脈を組み立てる——[PageRank](https://en.wikipedia.org/wiki/PageRank) 型の発想です。

### 2.3 Horizon Context との関係——「図書館」と「司書」

混乱しやすいのが、[Horizon Context](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/) との役割分担です。Atlan の比喩が明快です。

- **Horizon Context** — ガバナンスとメタデータの **図書館**（セマンティックビュー、ビジネス用語集、メタデータコネクタ）
- **Cortex Sense** — クエリの瞬間に適切な文脈を引き出す **司書**（runtime enrichment）

[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の Genie Ontology でも、Unity Catalog（保管・ガバナンス）と OntoRank（裁定・注入）の分離がありました。Snowflake も **カタログ層と実行時コンテキスト層** を分けています。

---

## 3. Genie Ontology との対比——同じ問い、異なる名前

公開資料から読み取れる範囲で、両者を並べます。

| 観点 | Databricks Genie Ontology | Snowflake Cortex Sense |
| :--- | :--- | :--- |
| **解く問い** | 「売上」はどの定義か——複数 snippet の **権威裁定** | スキーマは分かるが **ビジネス意味** が分からない問題 |
| **入力** | UC メタデータ、クエリ、ダッシュボード、連携アプリ（Slack 等） | クエリ履歴、オブジェクトメタデータ、BI、Horizon セマンティックビュー |
| **裁定の明示性** | **OntoRank** と名付け、キーノートで説明 | アルゴリズム名は未公開。「runtime enrichment」として説明 |
| **エージェント** | Genie One | CoWork（分析）、CoCo（データ開発） |
| **ガバナンス基盤** | [Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/index.html) | [Horizon Catalog / Context](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/) |
| **手動オントロジー** | 不要（統計的自律構築） | 不要（同上、Atlan 引用） |
| **権限** | ACL・UC 権限を検索時に適用 | RBAC・マスキングをエージェント経路に適用 |
| **精度の主張** | キーノートベンチマーク（詳細は[Kazushi 氏の現地レポート](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3)に委譲） | 47% → 83%（CoCo/CoWork、Snowflake 内部テスト、[Atlan](https://atlan.com/know/snowflake/snowflake-cortex-sense/) 引用） |

:::message
**注記：ベンチマーク数値について**

47% / 83% 等は Snowflake 内部テストに基づく数値であり、[SiliconANGLE](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/) は別の評価セットで 24% → 86% といった段階も報告しています。絶対値より **「ガバナンス済みビジネスコンテキストに近づくほど精度が上がる」** という方向性が、両社発表で共通している点が重要です。
:::

[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)が Google / PageRank と対比した **ボトムアップ構築** は、Snowflake 版では次のように言い換えられます。

| | Google（公開 Web） | Databricks | Snowflake |
| :--- | :--- | :--- | :--- |
| **入力** | リンク、クリックログ | UC 上の利用統計 | Snowflake 内クエリ・BI・Horizon |
| **アルゴリズム** | PageRank | OntoRank | 詳細未公開 |
| **出力** | 検索順位 | エージェント向け ontology snippet | 実行時 enriched context |
| **エージェント** | — | Genie | CoWork / CoCo |

**2026 年 6 月時点で、データプラットフォームの二大巨頭が「意味の層を統計的に自動構築する」方向に独立収束した** ——これは偶然の製品名被りではなく、エンタープライズ AI の **構造的条件** を示唆します。

---

## 4. 相違点——収束していても同じではない

思想が同型でも、実装と射程には差があります。

### 4.1 OntoRank の「明示性」

Databricks は **OntoRank** という名前で、社内に乱立する「売上」などの定義候補から、クエリ利用頻度・認証済みアセット・鮮度などのシグナルで **権威スコアを付け、エージェントに渡す snippet を選ぶ格付けロジック** を前面に出しました（[現地レポート](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3)参照）。Snowflake は Cortex Sense を **コンテキスト強化** と呼び、内部のランキング手順や PageRank 変種の有無は公開していません。[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)で述べた 2005 年 Swoogle OntoRank との思想的類似は、Snowflake 版では **未確認** です。

### 4.2 連携アプリの射程

Genie Ontology は [Slack](https://slack.com/)・[Confluence](https://www.atlassian.com/software/confluence) 等から **Learned Knowledge** を取り込む 2 系統設計を、[公式発表](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team)と[現地レポート](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3)が強調しています。Cortex Sense の公開シグナルは **Snowflake 内と BI コネクタ** が中心で、[SiliconANGLE](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/) は「SAP / Salesforce / Workday 横断のプロセス知識」は **弱い** と評価しています。CoWork の [MCP コネクタ](https://modelcontextprotocol.io/)（Google Drive、Salesforce、Slack 等）は **アクション接続** であり、Cortex Sense の **意味構築** とはレイヤーが異なります。

### 4.3 ベンダーロックの対称性

[前編 §8 ③](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank#8-残る問い自社で何をするか)は Genie Ontology の Databricks 限定性を指摘しました。Cortex Sense も **Snowflake 限定** です（[Atlan](https://atlan.com/know/snowflake/snowflake-cortex-sense/) が明言）。マルチクラウド環境では、どちらのプラットフォームにも載らない文脈——dbt の変換ロジック、Salesforce の商談定義、部門横断の用語集——が残ります。これは **クロスシステム・コンテキストレイヤー**（OpenMetadata / DataHub / 外部カタログ）が依然として必要な理由です。

### 4.4 「砂の上の強化」のリスク

Atlan と [SiliconANGLE](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/) が共通して指摘するのは、**入力シグナルが貧弱・矛盾していると、自動構築は矛盾を加速する** 点です。財務と営業で「売上」定義が食い違ったままクエリが流れていれば、Cortex Sense はその食い違いを **学習して増幅** し得ます。[前編の「観測可能なシグナルは十分か」](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank#8-残る問い自社で何をするか)は、Snowflake 利用者にもそのまま当てはまります。

---

## 5. 本シリーズとの接続——[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)・[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)・[シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) の三層スタック

[シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) は、プラットフォームによる **オントロジー（ビジネス定義）の自動構築** によって、DWH 内の意味レイヤーを **すべて手動で書き起こす必要がなくなりつつある** —— という転換点です。[Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) / Genie Ontology が担う **③** は、クエリログ・BI 利用などから定義候補を抽出し、どれを信頼するかを統計的に裁定する層であり、ここはプラットフォームに委ねられる領域が広がっています。

一方で **すべてを自動に任せてよいわけではありません**。**①** は、自社の競争優位や業務判断に直結する **コアドメインのエンティティと関係**——誤った解釈がそのまま損失につながるマスタや業務ルール——であり、[シーズン1 第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) が示したとおり、Pydantic 等で **顧客が決定論的にモデリング・固定** する必要があります。**②** は、部門やシステムの境界をまたぐ **共通IDと結合順序** の問題であり、[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) の **Bridge Keys** と **Graph Contract** として、組織が独自に設計・合意しなければなりません——DWH 内のプラットフォーム・コンテキスト層（③）だけでは解けません。

実務では、**どの層をプラットフォームの自動構築に任せ、どの層を自社でモデリングするか** を先に切り分ける必要があります。その設計図を描くのに、[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)（辿り方・厳格層）と [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)（部門フェデレーション）の解説がそのまま役立ちます。以下、①②③の三層スタックとして整理します。

:::message
**過去シリーズ未読の方向けの用語補足**

- **[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)** — データを DWH から動かさずグラフ的に辿る **[仮想グラフ](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)**。コアドメインは [Pydantic](https://docs.pydantic.dev/) で型・制約を固定する（[第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)）。
- **[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)** — **部門やシステムごとに分かれたデータ** を1つに統合せず、共通ID（**Bridge Keys**）と結合ルール（**Graph Contract**）で **クエリ時だけ** 横断する **[論理フェデレーション](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2)**。
- **[シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)** — エージェントがビジネス指標（売上・MQL など）を答えるとき、「同名でも定義が複数ある」問題の裁定。[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の Genie Ontology / OntoRank と [本編](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)の Cortex Sense が、利用統計から定義を自動構築するレイヤー（③）。
:::

### 5.1 [シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)（仮想グラフ戦略）——単一プラットフォーム上のグラフと厳格層

[仮想グラフ戦略 3 部作](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) のレイヤー表に、[本編](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)と[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)を重ねると次のようになります。

| レイヤー | 問い | Databricks | Snowflake |
| :--- | :--- | :--- | :--- |
| 物理 / 仮想グラフ | データをどう辿るか | [第 1 部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) | Iceberg / ゼロコピー連携 |
| オントロジー / 知識グラフ | 何が何と関係するか | [第 2 部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) | Horizon メタデータ |
| **意味の構築・裁定** | どの定義を信頼するか | [**Genie Ontology / OntoRank**（前編）](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) | [**Cortex Sense**（本編）](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) |
| 物理グラフの変更管理 | スキーマをどう厳格に保つか | [第 3 部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) | CoCo / dbt パイプライン |

[第 3 部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) の **二層戦略** ——競争優位に直結するコア（BOM 等）は Pydantic で決定論的に固定し、全社横断メトリクス（「売上」等）だけ統計に任せる——は、プラットフォームを Snowflake に替えても変わりません。Cortex Sense に部品構成グラフまで統計に寄せるのは、Genie Ontology の場合と同じく危険です。

### 5.2 [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)（論理フェデレーション）——組織境界を越える別の「意味」問題

[シーズン2 第1部](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) が整理した前提は、[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)とは異なります。[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)は **1つの DWH 上** でグラフを扱うのに対し、[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)は設計（EBOM）・製造（Routing）・調達（Sourcing）のように **部門ごとに別システム・別所有権** のデータを前提にします。全社を1つの物理グラフに統合するアプローチは、[第1部が述べた通り](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent#4-なぜ一元管理セントラルグラフdbは破綻するのか) 組織的・技術的に破綻しやすい。

[第2部](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2) の解は **物理分離・論理結合** です。部品を指す `Component.id` などの **Bridge Keys**（ドメイン横断の共通ID）と **Graph Contract**（どのIDをどの順で結ぶかの機械可読な契約）を全社合意し、クエリ時にだけドメインを横断します。LLM には **決定論的ツール**（検証済みクエリの API）の実行順序だけを任せ、スキーマ丸ごとの SQL 自由生成は避けます——[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)が批判した Text-to-SQL 丸投げと同型の責務分離です。

ここで重要なのは、**[Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) / [Genie Ontology](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) が解く問いと、[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)が解く問いは直交している** 点です。

| | [Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) / [Genie Ontology](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) | [シーズン2（論理フェデレーション）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) |
| :--- | :--- | :--- |
| **境界** | **プラットフォーム内**（UC / Horizon 上の資産） | **組織・システム間**（PLM / MES / SRM 等） |
| **問い** | 「売上」「MQL」は **どの定義** を信頼するか | `Component.id` で **どの順序** にドメインを結合するか |
| **手段** | クエリログ・BI 利用などの **統計的裁定** | Bridge Keys + Graph Contract + **決定論的ツール** |
| **典型シナリオ** | CoWork / Genie への自然言語分析 | [サプライヤー途絶の影響波及分析](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent#3-ビジネスの要求ドメインをまたぐ有事の影響波及分析) |

[第1部 §2.1](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent#21-組織間データ連携を阻む具体的な壁) が挙げた **意味論の不一致**（設計の Component / 調達の Item / 製造の Material）は、プラットフォームのコンテキストレイヤーだけでは解けません。逆に、Graph Contract が整っていても、Snowflake 内で「影響を受ける総売上」を聞いたとき **どのメトリクス定義を使うか** が曖昧なら、フェデレーション探索の結果を経営判断に載せる段階でずれます。**両方のレイヤーが必要** です。

### 5.3 三層が重なるとき——有事分析の実行スタック

[第3部（実装編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3) のサプライチェーン影響分析エージェント（例：サプライヤー停止→部品→製品→工程への波及追跡）を、[本記事](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)の文脈に載せ替えると、実行時にはおおよそ次の三層が重なります（§5 冒頭の用語補足と対応）。

```
[ ③ プラットフォーム・コンテキスト層 ]
  Cortex Sense / Genie Ontology — DWH 内メトリクス定義の統計的裁定
           │
           ▼
[ ② 組織フェデレーション層 ]  ← シーズン2
  Graph Contract + Bridge Keys — 調達→設計→製造の ID 連鎖
  決定論的ツール（bom_supplier_impact 等）
           │
           ▼
[ ① コアドメイン厳格層 ]  ← シーズン1 第3部
  Pydantic / ontology/schema.py — BOM・関係性の型と越境禁止
```

具体例で言えば、「東アジアの港湾停止でサプライヤー X が止まった」という [第1部のシナリオ](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent#31-途絶発生時のシナリオ) では、**②** の `analyze_supplier_disruption` が `Component.id` をバトンに EBOM → Routing を横断します（[シーズン2 第3部 §4.1](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3#41-3段階の連鎖的クエリ実行-appfederationanalysispy)）。その結果を「影響売上はいくらか」と経営層に要約するとき、**③** の [Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) / [OntoRank](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) が「売上」の定義を Horizon / UC 上から選びます。BOM の親子関係そのものは **①** の厳格グラフ（[シーズン1 第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)の `USED_IN` 接続制約、[シーズン2 第3部](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3)の `domains/registry.py` 越境禁止）が守ります。

[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)の `ontology/` ディレクトリは、[第3部](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3) で実装した **Graph Contract**（[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)の Pydantic 定義に、組織横断の結合ルールを上乗せしたもの）です。[Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) はこれを **置き換えません**。DWH 上の分析エージェント向けコンテキストとして **隣接レイヤー** に位置します。

マルチクラウド環境では、**③ がプラットフォームごとに二重化** する（UC 上の OntoRank と Horizon 上の Cortex Sense）一方、**② はベンダー非依存の契約** として設計できます——[第2部の Bridge Keys](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2#2-フェデレーション契約bridge-keysの設計) は Snowflake にも Databricks にも依存しません。§6 ③ の「どのカタログが裁定を持つか」は **③ の話**、「どの ID でドメインを結合するか」は **② の話** として切り分けると、設計判断がぶれにくくなります。

---

## 6. 実装者が持ち帰る問い

[前編 §8](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank#8-残る問い自社で何をするか)の 3 問いを Snowflake 文脈で更新し、[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)との接続を 2 点追加します。

**① クエリ履歴と Horizon は「行動統計」として十分か**

Cortex Sense は Snowflake 内のクエリ・BI 利用が前提です。分析文化が薄い、Horizon が形だけ、セマンティックビューが未整備——こうした環境では、[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)と同様に **権威推定の材料が足りません**。

**② CoWork の便利さと Cortex Sense の土台を混同しない**

MCP で Salesforce に繋がることと、「MQL の定義がエージェントに渡る」ことは別問題です。[Harmeet Arora 氏](https://www.linkedin.com/posts/harmeetsarora_snowflakesummit-marketinganalytics-agenticai-share-7467805537636700162-wDcZ/) が述べたように、**定義が Snowflake 内に明示・機械可読で存在するか** を先に確認する必要があります。

**③ マルチクラウドでは「どちらの Sense / Ontology が裁定を持つか」**

Databricks と Snowflake の両方を使う企業では、Unity Catalog と Horizon の **それぞれ** にコンテキストレイヤー（**③**）が育ちます。裁定の競合——財務の「売上」が UC と Horizon で異なるランクを持つ——は、[シーズン2 第2部](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2) の論理フェデレーション設計と併せて検討する必要があります。一方、調達グラフと設計グラフを `Component.id` で結ぶ **②** の Graph Contract はプラットフォーム横断で維持できます。ネイティブ実装を両方使うか、上位に cloud agnostic なカタログを置くかは、[前編 §8 ③](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank#8-残る問い自社で何をするか)と同型の判断です（§5.3 参照）。

**④ [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)のエージェントにコンテキスト層を足すか**

[影響分析エージェント](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3)（[シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)第3部：部門別グラフを決定論的ツールで横断）は、経営向け要約で社内 KPI を引用する段階では、実行中の DWH に **[Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) / [Genie Ontology](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) が有効か** を別途確認します。ツール境界（②）と統計的コンテキスト（③）を混同しないことが、[シーズン2 第2部 §4](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2#4-aiエージェントとツール境界の設計) の設計原則をプラットフォーム製品時代に引き延ばす形になります。

---

## おわりに

[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)の結論は、2026 年 6 月の業界動向によって **強化** されました。

LLM エージェントに社内データを扱わせるためのミッシングピースは、セマンティック Web の再来（人間が先に全部書く）でも、ベクトル検索任せでもありません。**ユーザーの利用統計から逆算して、プラットフォームが自律的にコンテキストレイヤーを育てる** ——Databricks は **OntoRank** という名前で、Snowflake は **Cortex Sense** という名前で、**同じ命題に答えました**。

実装者にとって重要なのは、どちらのロゴかではなく、**自社のカタログに、それだけの行動統計とガバナンス済み定義が溜まっているか** です。

次に読むべきは、製品ドキュメントではなく **自社の「売上」定義が何箇所に、どの鮮度で、誰のクエリで使われているか** という監査かもしれません。組織横断のグラフ探索を既に [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) で設計しているなら、**③ のコンテキスト層がその上に載るか** を合わせて点検するのがよいでしょう。[Cortex Sense](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) も [Genie Ontology](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) も、その監査結果が悪ければ空回りします——[PageRank](https://en.wikipedia.org/wiki/PageRank) がリンクのない Web では機能しないのと同じです。

---

## 参考文献

### 発表・公式

- [Snowflake — CoWork 発表プレスリリース（2026-06-02）](https://www.snowflake.com/en/news/press-releases/snowflake-cowork-powers-the-agentic-enterprise-as-the-personal-agent-for-knowledge-workers-to-work-smarter/)
- [Atlan — Snowflake Cortex Sense and the Enterprise Context Layer](https://atlan.com/know/snowflake/snowflake-cortex-sense/)
- [Atlan — Snowflake CoCo（旧 Cortex Code）解説](https://atlan.com/know/snowflake/snowflake-coco/)

### 分析・現地所感

- [Kazushi 氏 — Data + AI Summit 2026 初日 Keynote：Genie Ontology を現地スライドで読み解く](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3)
- [SiliconANGLE — Snowflake moves up the AI stack, but the System of Intelligence is still being built（2026-06-02）](https://siliconangle.com/2026/06/02/snowflake-moves-ai-stack-system-intelligence-still-built/)
- [Harmeet Arora — Cortex Sense に関する LinkedIn 投稿（Summit Day 2）](https://www.linkedin.com/posts/harmeetsarora_snowflakesummit-marketinganalytics-agenticai-share-7467805537636700162-wDcZ/)

### [シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)（前編・本編）

- [前編：セマンティック Web の挫折から 20 年 - Databricks「OntoRank」が解く、AIエージェント最大のボトルネック](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)
- [本編：Snowflake Cortex Sense は何者か——Genie Ontology と同じコンテキスト革命](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)

### [シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)（仮想グラフ戦略）

- [仮想グラフ戦略 第1部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)
- [仮想グラフ戦略 第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2)
- [仮想グラフ戦略 第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)

### [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)（論理フェデレーション）

- [第1部：分断されたグラフと影響分析の課題（背景編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)
- [第2部：組織境界を維持する論理フェデレーション（設計編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2)
- [第3部：サプライチェーン影響分析エージェントの実装（実装編）](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent3)
