---
title: "セマンティック Web の挫折から 20 年 - Databricks「OntoRank」が解く、AIエージェント最大のボトルネック"
emoji: "🧞"
type: "tech"
topics: ["databricks", "ontology", "knowledgegraph", "genie", "aiagent"]
published: true
---

:::message
**連載の位置づけ（[シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) → [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent) → [シーズン3](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank) → [シーズン4](https://zenn.dev/yohei/articles/2026-06-28-kg-ontology-redefinition)）**

本連載の主題は、エンタープライズ AI に必要な **「意味の層」**（ビジネス定義・関係・信頼すべき資産）の設計です。

| シーズン | 問い |
| :--- | :--- |
| [シーズン1](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)（仮想グラフ） | ① データをどう辿り、型を固定するか |
| [シーズン2](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent)（論理フェデレーション） | ② 部門別データをどう結ぶか |
| **シーズン3**（[前編](https://zenn.dev/yohei/articles/2026-06-17-databricks-genie-ontology-ontorank)・[本編](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology)） | ③ どの定義を信頼するか（Genie Ontology / Cortex Sense） |
| [シーズン4](https://zenn.dev/yohei/articles/2026-06-28-kg-ontology-redefinition)（現代の知識グラフとオントロジー・3部作） | ④ グラフの品質検証からエージェント回答の根拠確認まで、どう実装するか |

**本記事**は **シーズン3 の前編** です。発表の機能説明そのものは [Databricks 公式プレスリリース](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team) と [Kazushi 氏の現地レポート](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3) に任せ、ここでは **なぜ OntoRank がパラダイムの転換点なのか** を歴史とアルゴリズムの観点から整理します。[本編（Snowflake Cortex Sense）](https://zenn.dev/yohei/articles/2026-06-24-snowflake-cortex-sense-genie-ontology) では同型のコンテキストレイヤーを Snowflake 側から論じます。
:::

## 概要

2026年6月の [Data + AI Summit](https://www.databricks.com/dataaisummit) で、Databricks は **[Genie One](https://www.databricks.com/product/business-intelligence/ai-bi/genie)** と、その中核となる **Genie Ontology** を発表しました。キーノートで名前が付けられた **OntoRank** は、分散した社内資産から [オントロジー](https://en.wikipedia.org/wiki/Ontology_(information_science)) の断片（snippet）を抽出し、**どの定義を信頼するか** をアルゴリズムで裁定する仕組みです。

[第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) では、オントロジーさえ整えばグラフ探索や推論は相対的に容易な一方、「[知識獲得のボトルネック](https://en.wikipedia.org/wiki/Knowledge_acquisition)」で [セマンティックWeb](https://www.w3.org/standards/semanticweb/) が挫折した歴史を述べました。[第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) では、人力での厳格なオントロジー設計が実務上の唯一の現実解であると結論づけました。

Genie Ontology は、その前提に **第三の道** を提示します。人間に全定義を書かせるのでも、[LLM](https://en.wikipedia.org/wiki/Large_language_model) に100%任せるのでもなく、**[Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/index.html) 上に蓄積された利用行動の統計** をガソリンにして、意味のレイヤーを自律的に洗練させる——2000年代のセマンティックWebが解けなかった問題への、Google が検索で示した型の再現です。

---

## 1. ボトルネックは常に「意味の構築」にある

エンタープライズ AI の **コンテキスト問題** は、Genie に限った話ではありません。[AIエージェント](https://en.wikipedia.org/wiki/Intelligent_agent) は「売上」という語を処理できますが、**自社でその語が何を指し、どのテーブルにあり、どう結合するか** は持っていません。財務の「売上」は税抜か税込か、物流の「売上」は出荷ベースか受注ベースか——同じ単語でも部門によって参照先が異なります。

:::message
**多国籍製造業では売上の定義が数百種類ある？**

一言「売上」と聞くだけでも、多国籍展開する製造業では、その定義が **数百種類に及ぶ可能性がある** ——以前、グローバル製造業のデータマネジメント担当者から、そのような実務の摩擦を伺ったことがあります。国・事業単位・会計基準・出荷タイミング・製品階層の組み合わせで、同名のメトリクスが別々に生きている。エージェントが「売上を教えて」と聞かれた瞬間、**どの定義を選ぶか** がすでに問題になっています。
:::

文脈を絞れば応答は速いものの中身がずれ、正確さを求めれば手当たり次第に探索させて [トークン](https://en.wikipedia.org/wiki/Large_language_model#Tokenization) コストが膨らみます——[精度とコストのトレードオフ](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3) は、[RAG](https://research.facebook.com/publications/retrieval-augmented-generation-for-knowledge-intensive-nlp-tasks/)・[Text-to-SQL](https://en.wikipedia.org/wiki/Text-to-SQL)・Agentic Search のいずれでも繰り返されます。いずれも「検索・推論の技法」は進化していますが、**ビジネス用語の意味をどこから持ってくるか** という問いは残ります。

[第2部の対比表](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) が示すように、[知識グラフ](https://neo4j.com/blog/knowledge-graph/what-is-knowledge-graph/)（[GraphRAG](https://neo4j.com/blog/genai/what-is-graphrag/)）やオントロジーは **関係性レイヤー** として極めて有効です。問題は推論そのものではなく、**推論の前提となる意味構造をどう構築・維持するか** にあります。Genie Ontology は、この「意味の構築」を製品機能として正面から扱った点で、注目に値します。

---

## 2. オントロジー推論の「不都合な真実」

### 2.1 グラフがあれば推論は「後工程」

[オントロジー](https://en.wikipedia.org/wiki/Ontology_(information_science))（概念と関係の設計図）と、それに従って埋められた [知識グラフ](https://neo4j.com/blog/knowledge-graph/rdf-vs-property-graphs-knowledge-graphs/)（具体データ）が適切に構築されていれば、あとは既存の道具が効きます。

- **グラフ探索** — ノードを多ホップで [辿る探索](https://en.wikipedia.org/wiki/Graph_traversal)（例: サプライヤー → 部品 → 製品 → 顧客）
- **中心性・重要度** — [PageRank](https://en.wikipedia.org/wiki/PageRank) や [Betweenness Centrality](https://en.wikipedia.org/wiki/Betweenness_centrality) など
- **LLM への構造化コンテキスト注入** — ノード・エッジをプロンプトに載せる [GraphRAG](https://neo4j.com/blog/genai/what-is-graphrag/) パターン
- **宣言的クエリ** — [Cypher](https://neo4j.com/docs/cypher-manual/current/) や [GQL](https://www.iso.org/standard/76120.html)（ISO 標準のグラフクエリ言語）

[第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) で整理した通り、**「ノードとエッジで意味を表す」** という [知識表現](https://en.wikipedia.org/wiki/Knowledge_representation_and_reasoning) の思想は1970年代の [セマンティックネットワーク](https://en.wikipedia.org/wiki/Semantic_network) から続いており、LLM 時代になっても骨格は変わりません。変わったのは推論器（LLM）の柔軟性であり、**意味の地図を誰がどう描くか** という問題は残りました。つまりボトルネックは常に **構築フェーズ** にあり、探索・推論フェーズではないのです。

### 2.2 セマンティックWebが廃れた理由

2000年代の **[セマンティックWeb](https://www.w3.org/standards/semanticweb/)**（[RDF](https://www.w3.org/RDF/)・[OWL](https://www.w3.org/OWL/)）は、この地図を **人間が先に書く** ことを前提にしました。ページに `rdf:type` を付け、概念間の関係を合意し、[推論エンジン](https://en.wikipedia.org/wiki/Semantic_reasoner) がそれを辿る——[Tim Berners-Lee](https://www.w3.org/People/Berners-Lee/) が描いた美しい構想でしたが、実務では次の壁にぶつかりました。

1. **[知識獲得のボトルネック](https://en.wikipedia.org/wiki/Knowledge_acquisition)** — タグ付けと定義の合意に膨大な人手。Web 全体に [RDFa](https://www.w3.org/TR/rdfa-core/) を埋め込む作業は現実的ではありませんでした
2. **合意形成の政治的コスト** — 「売上」の正しい定義は部門ごとに異なり、トップダウンで1本化できません
3. **陳腐化** — ビジネスが変わってもオントロジーが追従しません。手動マスタはすぐに嘘になります

[第2部 §2](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) が「知識獲得のボトルネック」として述べた挫折と同じです。オントロジー推論の **アルゴリズム** は成立していても、**構築プロセスがスケールしない** ため、製薬・医療など一部を除き表舞台からフェードアウトしました。技術が間違っていたのではなく、**入力（定義の供給）の設計** が間違っていたと、後から読むことができます。

---

## 3. Googleの勝利——意味を「書かせない」アプローチ

セマンティックWebが人力構築で止まった一方、同じ時代に **[Google 検索](https://www.google.com/search/howsearchworks/)** は別の答えを示しました。

人間にオントロジーを書かせるのを諦め、次の **観測可能なシグナル** から意味を **統計的・機械的に** 復元しました。重要なのは、入力が **すでに Web 上に存在する行動の痕跡** である点です。新たに哲学書を書かせるのではなく、観測するだけです。

| シグナル | 役割 |
| :--- | :--- |
| **リンク構造** | [PageRank](https://ilpubs.stanford.edu:8090/422/1/1999-66.pdf) — 「重要なページ」は他から多く参照される |
| **クエリ・クリックログ** | どの検索結果がクリックされ、何が実際に役立ったかを示す [行動統計](https://en.wikipedia.org/wiki/Click-through_rate) |
| **[Knowledge Graph](https://blog.google/products/search/introducing-knowledge-graph-things-not/)** | エンティティと関係の **自動構築・推論**（2012年〜） |

Web 全体のリンクと利用者の行動という **集合知** を入力に、裏側で意味に基づいた検索を実現した——これはセマンティックWebの **トップダウン定義** とは対極の **ボトムアップ構築** です。ユーザーは「正しいオントロジー」を意識せず、普通に検索するだけで、システム側が権威を学習します。

:::message
[PageRank](https://en.wikipedia.org/wiki/PageRank) は「真理を発見する」アルゴリズムではなく、「観測された参照行動から権威を推定する」アルゴリズムです。哲学上の正しさではなく、**スケールする入力** を選んだことが本質です。
:::

---

## 4. 現代の罠——LLMにオントロジーを作らせる限界

[生成AI](https://en.wikipedia.org/wiki/Generative_artificial_intelligence) 時代、同じ構造が再現されています。LLM は非構造化テキストからオントロジー的 snippet を大量に **下書き** できますが、それだけでは足りません。

| アプローチ | 強み | 限界 |
| :--- | :--- | :--- |
| **LLM 100%** | 非構造化テキストから snippet を大量抽出できる | [ハルシネーション](https://en.wikipedia.org/wiki/Hallucination_(artificial_intelligence))による定義の捏造 |
| **人力 + レビュー** | 正確性は高い | セマンティックWebの二の舞。スケールしません |
| **[セマンティックレイヤー](https://www.getdbt.com/product/semantic-layer) だけ** | 集計定義は明確 | 多ホップの関係探索・定義の競合解決が弱いです |

[第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) は、ドメインエキスパートがオントロジーを厳格に定義し、[Pydantic](https://docs.pydantic.dev/) 等で制約を強制する **局所的・決定論的** 構築を、実務の現実解として提示しました。その結論は依然として正しく、**スコープを絞った物理グラフ**（[Neo4j](https://neo4j.com/) 等）には有効です。

しかしエンタープライズ全体の「売上」「顧客」「製品」といった **横断的な意味** を、全社オントロジーとして人力で維持するのは、2000年代と同じボトルネックに戻ります。LLM が下書きを加速しても、**「どれが正か」の裁定** が人間に残る限り、運用はスケールしません。ここが Genie Ontology が狙う隙間です。

---

## 5. OntoRank——Unity Catalog の統計からオントロジーを紡ぐ

ここで Data + AI Summit 2026 の **Genie Ontology** が意味を持ちます。公式には [「自動で構築・継続更新されるコンテキスト層」](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team) と説明されています。機能の手順は [Kazushi 氏の整理](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3) のとおり、要点だけ再掲します。

1. **Extract & store Ontology Snippets** — テーブル・クエリ・ダッシュボード・パイプライン・連携アプリから知識断片を抽出
2. **Determine authority with OntoRank** — 同一概念に複数定義があるとき、信頼度をスコアリング
3. **Search at query time, applying permissions** — [ACL](https://en.wikipedia.org/wiki/Access-control_list)・Unity Catalog 権限を適用して検索
4. **Inject relevant context into the agent loop** — 関連コンテキストを [エージェント](https://www.anthropic.com/research/building-effective-agents) の推論ループに注入

入力は **Modeled Semantics**（[Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/index.html) 上のセマンティクス）と **Learned Knowledge**（[Slack](https://slack.com/)・[Confluence](https://www.atlassian.com/software/confluence) 等の連携アプリから学習）の2系統。[公式発表](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team) も、governed data を ground truth とし、文書断片からの推測ではなく **SQL で curated data を引く** 設計を強調しています。つまり [ベクトル検索](https://en.wikipedia.org/wiki/Vector_database) だけの RAG とは、コンテキストの根拠が異なります。

### 5.1 OntoRank が何をしているか（本質）

OntoRank の核心は、**「どの定義を正とするか」を人間の会議ではなく、観測可能なシグナルに委ねる** 点です。Kazushi 氏のスライド整理では、次の要素が挙げられています。

- 出典・著者の権威
- **利用頻度** — 実際にクエリやダッシュボードで使われているか
- **認証アセット（[certified asset](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)）との結びつき** — ガバナンス済みデータセットか
- **鮮度** — 定義や参照先がいつ更新されたか
- **権限考慮（permissions-aware）** — ユーザーが見えない定義を勝手に採用しない

これは [PageRank](https://en.wikipedia.org/wiki/PageRank) と同型の発想です。「正しさ」を哲学で決めるのではなく、**観測された利用行動から権威を推定します**。

| | Google（公開Web） | Databricks（エンタープライズ） |
| :--- | :--- | :--- |
| **入力** | ページ間リンク、検索・クリック | クエリログ、ダッシュボード利用、認証済みデータセット |
| **アルゴリズム** | PageRank 等 | **OntoRank** |
| **出力** | 検索順位、知識パネル | エージェントに注入する **信頼できるオントロジー snippet** |
| **スケールの源泉** | 利用者の行動統計 | **組織内のデータ利用行動統計** |

人間に [RDF](https://www.w3.org/RDF/) を書かせるのではなく、**すでに存在するデータ資産とその使われ方** から意味を逆算します。セマンティックWebが失敗した「構築」問題を、Google が検索で解いた「統計」問題と同じカテゴリに置いています。

### 5.2 同名の OntoRank——2005年の学術論文との関係

**OntoRank という名前は、Databricks が初めて付けたものではない可能性が高いです。** 調査すると、2005年の [ISWC](https://iswc.semanticweb.org/) 論文に、まったく同じ名称のアルゴリズムが登場します。

> Li Ding, Rong Pan, Tim Finin, Anupam Joshi, Yun Peng, Pranam Kolari,
> **"Finding and Ranking Knowledge on the Semantic Web"**, ISWC 2005, LNCS 3729, pp.156–170
> ([UMBC 公開 PDF](https://ebiquity.umbc.edu/_file_directory_/papers/197.pdf))

この論文は、セマンティックWeb検索エンジン **[Swoogle](https://ebiquity.umbc.edu/project/html/id/53/Swoogle)** の一部として **OntoRank** を提案しています。当時すでに顕在化していた問題は、Databricks がキーノートで語った問題と構造的に酷似しています。

- 同じ概念（例: `person`）に対し、**300以上の異なるオントロジー用語（SWT）** が存在する
- 人間が「正しい定義」を会議で決めるのはスケールしません
- **PageRank だけでは不十分** — 通常のハイパーリンクではオントロジー文書を見つけにくい

Swoogle の OntoRank は、PageRank の **random surfer model** を拡張した **rational surfer model** に基づきます。[Semantic Web Document](https://www.w3.org/TR/rdf-syntax-grammar/)（SWD）間のリンクを、意味のある3種類に一般化して重み付けします。

| リンク種別 | 意味 | 例 |
| :--- | :--- | :--- |
| **IM** (import) | オントロジーの import 関係 | [`owl:imports`](https://www.w3.org/TR/owl-ref/#imports) |
| **EX** (extension) | 用語定義の拡張・継承 | [`rdfs:subClassOf`](https://www.w3.org/TR/rdf-schema/#ch_subclassof) 経由の定義依存 |
| **TM** (use-term) | 他オントロジーの用語の利用 | クラス・プロパティの参照 |

反復計算で各オントロジー文書の `wPR(α)` を求め、import 先へランクを伝播させます（論文の式 (1)–(3)）。用語レベルでは **TermRank** も定義され、文書の OntoRank と用語の出現頻度・利用広がりの積で重要度を推定します。実験では、同一データセット上で PageRank よりオントロジー文書の発見率が平均 **約40%改善** したと報告されています。

:::message
**Swoogle OntoRank (2005) は Genie Ontology OntoRank (2026) の思想的な元ネタか？**

公開資料上、Databricks がこの論文を引用した事実は確認できません。**同一アルゴリズムの移植か、独立した再発明かは不明** です。

ただし、問題設定と解法の骨格は驚くほど重なります。

| | Swoogle OntoRank (2005) | Genie Ontology OntoRank (2026) |
| :--- | :--- | :--- |
| **入力** | SWD 間の意味リンク、用語の利用・定義関係 | テーブル・クエリ・ダッシュボード・連携アプリの snippet |
| **シグナル** | import / 拡張 / 用語参照、出現頻度 | 利用頻度、認証アセット、鮮度、権限 |
| **問い** | どのオントロジー定義を信頼するか | どのビジネス定義をエージェントに渡すか |
| **PageRank との関係** | 意味リンク付き PageRank 変種 | 行動統計による権威推定（詳細未公開） |

2005年の論文が **「セマンティックWeb上で、人間の合意の代わりに利用構造からオントロジーの権威を推定する」** という命題の初期回答だったとすれば、Genie Ontology の OntoRank は、同じ命題を **エンタープライズの Unity Catalog とクエリログ** という入力に置き換えて再提示しています——少なくとも **思想的系譜** として読む余地は大きいです。名前の一致は偶然ではなさそうですが、公式に確認できるまで断定はできません。
:::

第2部が述べた「セマンティックWebの挫折」は、技術が消えたわけではありません。Swoogle は2004年から稼働し、OntoRank は **オントロジー競合の裁定をアルゴリズムに委ねる** というアイデアを、すでに20年前に形式化していました。Databricks の発表は、そのアイデアが **公開Webの RDF** から **社内の governed data 資産** へ入力を移し、LLM エージェント時代に再登場したと捉えると、歴史的なつながりが見えます。

### 5.3 動的な修正——推定されるフィードバックループ

公開資料だけでは内部実装の全詳細は不明ですが、アーキテクチャ上 **利用状況に応じてオントロジーが更新され続ける** 設計になっていることは、公式の「live, self-improving context layer」「continuously extracts and updates」という表現と、OntoRank のシグナル設計から自然に読み取れます。静的な [データカタログ](https://en.wikipedia.org/wiki/Data_catalog) ではなく、**使われ方で重みが変わる** レイヤーです。

- あるメトリクス定義の利用が増える → 権威スコア上昇
- 認証アセットが新バージョンに差し替わる → 鮮度・権威の再計算
- 部門横断のクエリが別の結合パターンを選ぶ → snippet の重み付け変化

つまりオントロジーは **一度書いて終わりのマスタ** ではなく、**データプラットフォームの利用によって育つレイヤー** として扱われます。Kazushi 氏が所感で述べた「回せば回すほどオントロジーが育つ」ループは、この構造の帰結です。2005年の TermRank が「用語の人気」を文書ランクから伝播させたのと同様、**利用のフィードバックが意味の格付けに戻る** 設計と読めます。

:::message
**注記：公式未公開情報と合理的推論について**

Databricks 版 OntoRank のスコア式や更新頻度の詳細は、現時点では公開されていません。本節のフィードバックループは、発表スライド・プレスリリースの記述からの **合理的推論** です。2005年論文の OntoRank との算法的同一性も、現時点では **未確認** です。実装検証は GA 後のドキュメント待ちになります。
:::

---

## 6. 仮想グラフ戦略との接続

[第1部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) で論じた **[仮想グラフ](https://neo4j.com/blog/graph-database/introducing-neo4j-virtual-graph-graph-reasoning-on-the-data-you-already-have/)** — データを物理移動させず [DWH](https://en.wikipedia.org/wiki/Data_warehouse) 上に関係性を重ねる — は、**ストレージとクエリの話** でした。Genie Ontology はその上に載る **意味・コンテキストのレイヤー** です。どのテーブルを JOIN するかが決まっても、「売上」の定義が3つあればエージェントはまだ迷います。

| レイヤー | 問い | 本シリーズでの扱い |
| :--- | :--- | :--- |
| 物理 / 仮想グラフ | データをどう辿るか | 第1部 |
| オントロジー / 知識グラフ | 何が何と関係するか | 第2部 |
| オントロジーの **構築・裁定** | どの定義を信頼するか | **本記事（Genie Ontology / OntoRank）** |
| 物理グラフの変更管理 | スキーマをどう厳格に保つか | 第3部 |

第3部が推奨する **局所的・決定論的** な物理グラフ構築と矛盾しません。コアドメインの [BOM](https://en.wikipedia.org/wiki/Bill_of_materials) やサプライチェインなど、競争優位に直結する領域では、引き続き人間が型と制約を厳格に定義する価値があります。

Genie Ontology が覆すのは、**全社横断の「売上はどれか」問題** — セマンティックレイヤーと部門別定義が競合する領域です。ここを OntoRank が統計的に裁定すれば、[第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) が指摘した「オントロジー設計の運用負荷」は **構築** から **ガバナンスと例外処理** にシフトします。

---

## 7. 何が「実用段階に入った」と言えるのか

キーノートで示されたベンチマーク（精度とレイテンシの同時改善）は、製品宣伝としては当然の主張です。アーキテクト視点で読み替えると、次の **構造的条件** が揃ったことが重要です。個別の数値より、**仕組みの部品が揃ったか** を見るべきです。

1. **入力の観測可能性** — [Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/index.html) にクエリ・利用・認証のメタデータが既に溜まっていること
2. **裁定のアルゴリズム化** — 定義の競合を OntoRank が処理すること（人力会議に全依存しない）
3. **権限の一貫性** — 検索時に [RLS](https://docs.databricks.com/en/security/privacy/row-filter-and-column-mask.html) / ACL を適用し、エージェントが「見えないデータ」を推測しないこと
4. **ground truth の所在** — 文書 [embedding](https://en.wikipedia.org/wiki/Embedding_(machine_learning)) ではなく、governed data への SQL を優先すること

[第2部の表](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2) が「オントロジー設計の難易度が高く、保守負荷が大きい」と書いた行は、**構築コスト** についての評価でした。自動構築と統計的裁定の仕組みがプラットフォームに入ったことで、オントロジーに基づくエージェント推論は **机上の空論** から **データ活用を回し続ける運動** に近づきます。問い → データに当てる → 答え → 次の問い、のループの途中で定義の擦り合わせに止まる時間が減る、という実務上の変化です。

これは「万能 AI」の話ではありません。Ali Ghodsi 自身が [プレスリリース](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team) で述べる通り、**コンテキスト問題** の話です。ソフトウェアエンジニアリングが [ソースコード](https://en.wikipedia.org/wiki/Source_code) という **完全で構造化されたコンテキスト** のおかげで AI 化できた（[コーディングエージェント](https://www.cursor.com/)）ように、ビジネス側にも **統計的に育つ意味レイヤー** が必要でした——Genie Ontology はその宣言です。

---

## 8. 残る問い——自社で何をするか

製品のハウツーは公式と現地レポートに任せ、実装者が持ち帰るべき問いを3つに絞ります。

**① 観測可能なシグナルは十分か**

OntoRank は [Unity Catalog](https://docs.databricks.com/en/data-governance/unity-catalog/index.html) と連携アプリの **利用実績** を前提に動きます。クエリログ・認証済みアセット・鮮度のいずれかが貧弱だと、Google にリンクが無いページと同様、**権威を推定する材料が足りません**。[データカタログ](https://en.wikipedia.org/wiki/Data_catalog) が形だけで実績が無い環境では、OntoRank は空回りします。Genie Ontology を検討する前に、「行動統計がどこに溜まっているか」を点検するのが最初の設計判断です。

**② 統計的裁定と決定論的コアの境界**

全社横断のメトリクス（「売上」はどれか）は OntoRank に寄せ、BOM やサプライチェインなど競争優位に直結するコアドメインは [第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) のように [Pydantic](https://docs.pydantic.dev/) で厳格に管理する——この **二層** が現実的です。「すべてを一つの知識グラフに」は引き続き破綻しやすく、**どこまでを統計に任せ、どこからを人間が固定するか** が設計の本体になります。境界が曖昧だと、エージェントは「公式な定義」と「よく使われる定義」を混同します。

**③ ベンダーロックと移植性**

Genie Ontology と OntoRank は **Databricks 限定** で、Unity Catalog の統計・権限に深く依存します。[第1部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what) で触れた Snowflake や Google Cloud が同型機能を **追従する可能性** はあり、追従すればネイティブ実装が最も安価です。Databricks 以外の環境で同様のアプローチを取る場合は、OntoRank の思想を参考に [OpenMetadata](https://open-metadata.org/) や [DataHub](https://datahubproject.io/) にシグナルを蓄積して **cloud agnostic な自前実装** を検討し、[論理フェデレーション](https://zenn.dev/yohei/articles/2026-06-06-supply-chain-impact-analysis-agent2) では「どのカタログが裁定を持つか」を先に決めます。

---

## おわりに

[セマンティックWeb](https://www.w3.org/standards/semanticweb/) は **意味を先に書く** ことで敗れ、Google は **意味を後から統計で復元** することで検索を制しました。エンタープライズ AI は今、同じ分岐点にいます。LLM は柔軟な推論器ですが、オントロジーの構築を100%任せると嘘をつき、人力に戻すとスケールしません。

[OntoRank](https://ebiquity.umbc.edu/_file_directory_/papers/197.pdf) は、この死角に対する **PageRank 型の回答** です。Web のリンクの代わりに社内のクエリと認証済みデータセットを、哲学の合意の代わりに利用頻度と鮮度を入力にします。2005年の Swoogle 論文がセマンティックWeb上で示した「利用構造からオントロジーを格付けする」発想が、エンタープライズのデータカタログへ入力を移した形——と読むこともできます（算法的同一性は未確認）。オントロジーが **自動で構築・更新される仕組み** がプラットフォームに入ったとき、初めてオントロジーに基づくエージェント推論は、グラフアルゴリズムのデモを超えて **インフラ** になります。

[第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3) が「人力で厳格に」という How を示したのに対し、本記事は **「なぜ今、プラットフォームが統計的オントロジー構築に賭けたのか」** という Why です。次に検証すべきは、自社の Unity Catalog（または同等のカタログ）に、OntoRank が効くだけの **行動統計が溜まっているか** という一点に尽きます。

## 参考文献

### 発表・レポート

- [Databricks — Genie One 発表プレスリリース（2026-06-16）](https://www.databricks.com/company/newsroom/press-releases/databricks-launches-genie-one-all-new-agentic-coworker-every-team)
- [Kazushi 氏 — Data + AI Summit 2026 初日 Keynote：Genie Ontology を現地スライドで読み解く](https://zenn.dev/kazushi6/articles/3d58cfe511bcc3)
- [Databricks — Unity Catalog ドキュメント](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)

### 学術・歴史

- [Ding ら — セマンティック Web 上の知識の発見とランキング（ISWC 2005）](https://ebiquity.umbc.edu/_file_directory_/papers/197.pdf) — Swoogle の **OntoRank** 原論文
- [Swoogle プロジェクト（UMBC）](https://ebiquity.umbc.edu/project/html/id/53/Swoogle)
- [Page, Brin ら — PageRank 引用ランキング原論文（1999）](https://ilpubs.stanford.edu:8090/422/1/1999-66.pdf)
- [W3C — セマンティック Web 標準](https://www.w3.org/standards/semanticweb/)

### 本シリーズ（仮想グラフ戦略 3 部作）

- [第1部：仮想グラフ戦略](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)
- [第2部：知識表現と推論になぜグラフが使われるのか](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2)
- [第3部：物理グラフDBの変更管理と安定運用戦略](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)
