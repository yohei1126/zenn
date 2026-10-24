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

[第3部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap)のあと、2026-10-21 に [v0.1.6](https://github.com/edgesentry/ontographia/releases/tag/v0.1.6) が公開されました。Intent 層の `ontographia[llm]` と、実験的な MCP サーバ `ontographia[mcp]` を、PyPI から入れられるようになったリリースです。どちらも experimental / 0.x です。パッケージ化は [PR #93](https://github.com/edgesentry/ontographia/pull/93) と [PR #94](https://github.com/edgesentry/ontographia/pull/94)、実 Neo4j に対する CI は [PR #99](https://github.com/edgesentry/ontographia/pull/99) にあります。

本記事（第4部）では、その公開パッケージの上で第3部と同じ条件のライブ評価をやり直し、分かったことを 3 点にまとめます。リポジトリを手元に落とさなくても結果の意味は追えるようにし、表や試行ログは記録側へ残しました。数値の出典は [PR #107](https://github.com/edgesentry/ontographia/pull/107) と [PR #109](https://github.com/edgesentry/ontographia/pull/109)、比較表の [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md)、E2E の [`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini) です。

測り方は第3部のライブ評価に揃えています。temperature は 0、Track A は n=40、Track B は n=60（seed 53）で、各条件は 1 回だけ、実施日は 2026-10-22 です。使ったライブラリは PyPI の `ontographia[llm]==0.1.6` です。1 回だけの計測なので、あとで示す差は「この日の 1 回」として読んでください。

---

## 1. 実験的 MCP サーバが入り、4 ツールが通った

実験的な MCP サーバ `ontographia[mcp]` を入れると、`list_ontology`、`intent_schema`、`build_cypher`、`execute` の 4 ツールが実機で動きました。保存しておいた Intent をあとから流すと、`build_cypher` から `execute` まで通っています。

サーバ側の実装は LLM を呼びません。クライアントが Intent JSON を渡し、サーバがそれを検証して Cypher を組み立てます。モデルに生の Cypher を書かせない、という第2部の境界が、MCP のクライアント越しでも同じ形で残ります。`execute` の結合テストは実 Neo4j に対する CI でも走っていて、手元の 1 回だけでなく継続的に確認されています。手順は [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/)、CI の内容は [PR #99](https://github.com/edgesentry/ontographia/pull/99) を参照してください。

## 2. 実 E2E では、オントロジーに無い名前が DB に届く前に止まった

Gemini 3.7 Flash とローカル Neo4j で質問を最後まで流すと、オントロジーに無いプロパティ名は検証で落ちました。Cypher は発行されず、データベースにも届いていません。記録に残っている例が `"name激as_name"` です。

成功した 1 件では、生成した Cypher が `MikroMotors` と `FormTech` の 2 行を返しました。試行は 4 件すべて残してあり、LLM を挟んだ end-to-end の成功はそのうち 1 件です。検証が不正な名前を止めたことと、質問が最後まで解けたことは別で、この小さなサンプルでは後者は高くありません。

ここでいうハルシネーション防止は、オントロジーに無いスキーマ名がクエリとして DB に到達するのを止めることです。「すべてのハルシネーションが消える」のではありません。名前がオントロジーに実在する誤選択、つまり第3部のサイレント誤答は、検証を通過しうるからです。事実誤認も対象外です。試行の記録は [`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini) にまとまっています。

## 3. 新しいモデルでも、精度とコストを左右したのはオントロジーの渡し方

公開パッケージ上で Gemini 3.7 Flash と 3.8 Flash の両方を回しても、プロンプトに無い名前をモデルが捏造した件数は全条件で 0 のままでした。モデルを替えても、未知の名前はオントロジーの列挙と検証で止まります。

精度とコストの差の大半は、モデル名より、オントロジーをプロンプトへどう渡すかにありました。`large` で推奨の `subset_fallback` は、同じランの `full` に対して Property Hit が +30pt（3.7）/ +16.25pt（3.8）、プロンプトトークン数の p95 はいずれも約 −90.5% です。質問に関係する語彙を先に渡し、足りないときだけ全体へ戻すと、正答率が上がりトークンも大きく減る、という第3部の結果が、公開 PyPI でも再現しています。

ただし、本評価に「オントロジーなし」条件はありません。`full` もオントロジー全体をプロンプトに載せています。したがって、オントロジーを入れた利得ではなく、同じオントロジーの渡し方で Hit とトークンが変わる、とだけ読めます。

モデルを 3.7 から 3.8 へ差し替えると、向きは条件で分かれました。`full` と `subset` 単体は上がり、たとえば `large` の full Hit は 0.65 → 0.725 です。一方、すでに推奨している `subset_fallback` はやや下がり、Hit は 0.95 → 0.8875、Compile は 40/40 → 37/40 になりました。Track B の Compile も 39 → 36/60 です。新しいモデルが自動的に良いわけではなく、条件によって上がったり下がったりするので、差し替えるたびに同じ評価セットで測る必要があります。数値の一覧は [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md) にあります。

## 限界

各条件は 1 回のみです。E2E の LLM 経由成功率は小さいサンプルで低く、検証が不正なスキーマ名を止めたことと、タスク完了率は別問題です。Track B の Exec Match は 3 ランとも 1 件で、Gold が Cypher（Intent ではない）ため、完全一致は弱証拠です。この読み方は第3部と同じです。Intent の Gold 化や実業務オントロジーでの追試は、第3部で挙げた計画の延長として残ります（時期は未定です）。

手元で試すときは `pip install "ontographia[llm]"` と `"ontographia[mcp]"` です。どちらも experimental です。手順は [docs/llm.md](https://edgesentry.github.io/ontographia/llm/) と [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/) にあります。
