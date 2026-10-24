---
title: "Ontographia 第4部 - 新しい LLM での精度評価とハルシネーション防止機構の検証"
emoji: "🔬"
type: "tech"
topics: ["neo4j", "cypher", "llm", "mcp", "ontology"]
published: true
---

:::message
**連載の位置づけ（Ontographia）**

自然言語からグラフデータベース（Neo4j 等）へ問い合わせを行う際、多くの現場は「LLM に直接 Cypher クエリを書かせるか」「手書きの巨大な固定クエリ／テンプレ集で縛るか」の二者択一で揺れ動きます。

本連載では、**「LLM には意図抽出（Intent JSON）だけを担わせ、Cypher の組み立てはオントロジー拘束付きの決定論的パイプラインで行う」** という方法論（[Ontographia](https://github.com/edgesentry/ontographia)）を提案・検証します。

| 部 | 記事 | 役割 |
| :--- | :--- | :--- |
| **第1部** | [グラフAIのジレンマ：LLMにCypherを書かせるか、テンプレ保守地獄に耐えるか](https://zenn.dev/yohei/articles/2026-09-08-ontographia-template-cost) | 課題と仮説 |
| **第2部** | [Intent-first の設計と実装](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design) | アーキテクチャ |
| **第3部** | [検証結果と今後のロードマップ](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap) | Track A / B の定量評価 |
| **第4部** | 新しい LLM での精度評価とハルシネーション防止機構の検証（本記事） | 公開パッケージでの追試 |

リポジトリ: [edgesentry/ontographia](https://github.com/edgesentry/ontographia)
:::

## 概要

自然言語で Neo4j に問い合わせる仕組みを LLM で作ると、オントロジーに存在しないプロパティ名をモデルがもっともらしく書き、そのままクエリとして実行されてしまう心配があります。Ontographia はこの問題に対して、LLM の仕事を質問の意図を表す Intent JSON の出力だけに限っています。Cypher を組み立てるのは、オントロジーで拘束した Rust 製の決定論的パイプラインです。パイプラインは Intent をオントロジーと照合して検証し、通過したものだけを、値をパラメータとして切り離した Cypher へ変換します。

[第3部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap)では、この設計をオントロジーの規模を変えながら評価しました。その後、2026-10-21 に [v0.1.6](https://github.com/edgesentry/ontographia/releases/tag/v0.1.6) を公開し、Intent 層の `ontographia[llm]` と実験的な MCP サーバ `ontographia[mcp]` を PyPI から入れられるようにしました。どちらもまだ experimental（0.x）の扱いです。パッケージ化の変更は [PR #93](https://github.com/edgesentry/ontographia/pull/93) と [PR #94](https://github.com/edgesentry/ontographia/pull/94) に、実 Neo4j に対する CI は [PR #99](https://github.com/edgesentry/ontographia/pull/99) にあります。

公開パッケージを手元に入れた人が、第3部と同じ結果を得られるとは限りません。また、LLM のモデルは次々に新しくなるので、差し替えたときに何が変わるのかも確かめておく必要があります。そこで本記事では、公開パッケージの上で第3部と同じ条件のライブ評価をやり直しました。分かったことは三つあります。一つ目は、MCP サーバの 4 ツールが実機で動いたことです。二つ目は、実際に質問を最後まで流した実行で、オントロジーに無いプロパティ名が DB に届く前に検証で止まったことです。三つ目は、Gemini 3.7 Flash と 3.8 Flash を比べると、精度とトークン数を大きく左右したのはモデルよりもオントロジーの渡し方であり、新しいモデルが常に良い結果を出すわけではなかったことです。

測り方は第3部のライブ評価に揃えました。temperature は 0 で、製造ドメインの合成評価である Track A は 40 問、公開ベンチマークを使う Track B は 60 問（seed 53）です。ライブラリは PyPI の `ontographia[llm]==0.1.6` を使い、2026-10-22 に各条件を 1 回ずつ実行しました。1 回だけの計測なので、以下に示す差は「この日の 1 回の結果」として読んでください。数値の出典は [PR #107](https://github.com/edgesentry/ontographia/pull/107) と [PR #109](https://github.com/edgesentry/ontographia/pull/109) で、表や試行ログもそちらに残しています。

---

## 1. 実験的 MCP サーバの 4 ツール

v0.1.6 で加えた実験的な MCP（Model Context Protocol）サーバ `ontographia[mcp]` は、`list_ontology`、`intent_schema`、`build_cypher`、`execute` の 4 ツールを提供します。実機で試したところ、4 ツールはすべて動作しました。保存しておいた Intent をあとから流す使い方でも、`build_cypher` から `execute` まで通っています。

このサーバは、それ自体では LLM を呼び出しません。MCP クライアントの側が Intent JSON を渡し、サーバはそれを検証してから Cypher を組み立てます。そのため、モデルに生の Cypher を書かせないという[第2部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design)の責務の分け方は、MCP クライアントを介して使う場合でも変わりません。

なお、`execute` の結合テストは実 Neo4j に対する CI でも実行しています。動作確認は手元での 1 回にとどまらず、継続的に行われています。サーバの導入手順は [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/) に、CI の内容は [PR #99](https://github.com/edgesentry/ontographia/pull/99) にまとめています。

## 2. 実 E2E 実行でのオントロジーに無いプロパティ名の扱い

次に、Gemini 3.7 Flash とローカルの Neo4j を使い、質問から結果の取得までを end-to-end（E2E）で流しました。この実行では、モデルがオントロジーに無いプロパティ名を Intent に含めた場合、その Intent は検証で不合格になりました。不合格の Intent からは Cypher が発行されないので、問題の名前はデータベースまで届いていません。記録に残っている例は `"name激as_name"` という名前です。

一方で、質問が最後まで解けた件数は多くありません。試行は 4 件すべて記録してあり、LLM を挟んだ E2E が成功したのはそのうち 1 件です。成功した 1 件では、生成された Cypher が `MikroMotors` と `FormTech` の 2 行を返しました。検証が不正な名前を止めたことと、質問に正しく答えられたことは別の事柄であり、この小さなサンプルでは後者の割合は低いままです。

ここでいうハルシネーション防止の範囲は、オントロジーに無いスキーマ名がクエリとして DB に到達するのを止めることに限られます。これは「すべてのハルシネーションを防げる」ことを意味しません。オントロジーに実在する別の名前を誤って選んだ場合、Intent は検証を通過しうるからです。第3部では、このように誤った名前がエラーにならずに通ってしまう現象をサイレント誤答と呼びました。同じく、事実誤認も検証の対象外です。4 件の試行記録は [`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini) にあります。

## 3. Gemini 3.7 Flash と 3.8 Flash の比較

三つ目の評価では、公開パッケージの上で Gemini 3.7 Flash と 3.8 Flash の両方を同じ条件で動かしました。まず、プロンプトに無い名前をモデルが捏造した件数は、どちらのモデルでも全条件で 0 件でした。モデルを替えても、オントロジーの語彙を列挙して渡し、出力を検証するという仕組みは変わらないので、未知の名前はそこで止まります。

### オントロジーの渡し方による差

精度とトークン数の差は、モデルの違いよりも、オントロジーをプロンプトへどう渡すかで大きく開きました。比べた渡し方は三つです。`full` はオントロジー全体を載せ、`subset` は質問に関係する語彙だけを載せます。`subset_fallback` は、まず質問に関係する語彙を渡し、足りないときだけ全体へ戻す方式で、プロジェクトとして推奨しているものです。指標には、Intent が正しいプロパティを選べた割合である Property Hit と、Cypher へのコンパイルに成功した件数（Compile）を使いました。

Track A の大規模オントロジー `large` で比べると、`subset_fallback` は同じランの `full` に対して、Property Hit が 3.7 では +30pt、3.8 では +16.25pt 高くなりました。プロンプトトークン数の p95 は、どちらのモデルでも約 −90.5% です。つまり、関係する語彙を先に渡して足りないときだけ全体へ戻すと、正答率が上がり、トークンも大きく減るという第3部の結果が、公開 PyPI 版でも再現しました。

ただし、この比較から読み取れる範囲には注意が必要です。本評価には「オントロジーを渡さない」条件がなく、`full` もオントロジー全体をプロンプトに載せています。したがって、この結果はオントロジーを使うこと自体の利得を示すものではありません。同じオントロジーでも、渡し方によって Property Hit とトークン数が変わる、ということだけが言えます。

### モデルの差し替えによる差

これに対して、モデルを 3.7 から 3.8 へ替えたときの変化は、条件によって向きが分かれました。`full` と `subset` 単体では上がり、たとえば `large` の `full` では Property Hit が 0.65 から 0.725 になりました。しかし、推奨している `subset_fallback` ではやや下がり、Property Hit は 0.95 から 0.8875 へ、Compile は 40/40 から 37/40 へ減りました。Track B の Compile も 39/60 から 36/60 に減っています。

このように、新しいモデルに替えれば自動的に結果が良くなるわけではありません。上がる条件と下がる条件が混在するので、モデルを差し替えるたびに同じ評価セットで測り直す必要があります。条件ごとの数値の一覧は [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md) にまとめました。

## 限界

今回の結果には、いくつかの限界があります。まず、各条件は 1 回ずつしか実行していないので、ここで示した差がどこまで安定しているかは分かりません。次に、E2E で LLM を経由して質問が解けたのは 4 件中 1 件と、サンプルが小さく成功率も低い状態です。前述のとおり、検証が不正なスキーマ名を止めたこととタスクを完了できたこととは別問題です。

また、Track B の Exec Match（実行結果の行集合が正解と完全に一致した件数）は、3 ランとも 1 件でした。Track B の正解（Gold）は Intent ではなく Cypher で用意されているため、完全一致は弱い証拠にしかなりません。この読み方は第3部と同じです。

今後の課題としては、正解を Intent の形で用意することと、実業務のオントロジーでの追試が残っています。どちらも第3部で挙げた計画の延長ですが、時期は未定です。

## 手元で試すには

手元で試す場合は、`pip install "ontographia[llm]"` で Intent 層を、`pip install "ontographia[mcp]"` で MCP サーバを入れられます。どちらも experimental の扱いです。使い方は [docs/llm.md](https://edgesentry.github.io/ontographia/llm/) と [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/) にあります。
