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

[第3部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap)のあと、2026-10-21 に [v0.1.6](https://github.com/edgesentry/ontographia/releases/tag/v0.1.6) が公開され、Intent 層（`ontographia[llm]`）と実験的 MCP サーバ（`ontographia[mcp]`）が PyPI から入れられるようになりました（いずれも experimental / 0.x。[PR #93](https://github.com/edgesentry/ontographia/pull/93)、[PR #94](https://github.com/edgesentry/ontographia/pull/94)、実 Neo4j 向け CI: [PR #99](https://github.com/edgesentry/ontographia/pull/99)）。

本記事（第4部）では、その公開パッケージの上で第3部と同じ条件のライブ評価をやり直し、分かったことを 3 点にまとめます。詳細な表や試行ログはリポジトリ側にあります（[PR #107](https://github.com/edgesentry/ontographia/pull/107)、[PR #109](https://github.com/edgesentry/ontographia/pull/109)、比較表 [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md)、E2E [`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini)）。

条件の要点だけ先に書いておきます。temperature 0、Track A は n=40、Track B は n=60（seed 53）、各条件 1 回のみ、実施日 2026-10-22、ライブラリは `ontographia[llm]==0.1.6`（PyPI）です。

---

## 1. 実験的 MCP サーバが入り、4 ツールが通った

`ontographia[mcp]` の 4 ツール（`list_ontology` / `intent_schema` / `build_cypher` / `execute`）は実機で動き、保存した Intent のリプレイでは `build_cypher` から `execute` まで通りました。サーバ自身は LLM を呼ばず、クライアントが出した Intent を検証して Cypher を組み立てます。`execute` の結合テストは実 Neo4j に対する CI でも走っています（[PR #99](https://github.com/edgesentry/ontographia/pull/99)）。使い方は [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/) を見てください。

## 2. 実 E2E では、オントロジーに無い名前が DB に届く前に止まった

Gemini 3.7 Flash とローカル Neo4j での E2E では、壊れたプロパティ名（例: `"name激as_name"`）を含む Intent が検証で落ち、Cypher は発行されずデータベースにも届きませんでした。成功した 1 件では、生成 Cypher が 2 行（`MikroMotors` / `FormTech`）を返しています。試行は 4 件すべて記録してあり、LLM 経由の end-to-end 成功はそのうち 1 件です。

ここでいうハルシネーション防止は、オントロジーに無いスキーマ名がクエリとして DB に到達するのを止めることです。「すべてのハルシネーションが消える」のではありません。実在語彙の誤選択（第3部のサイレント誤答）は、名前がオントロジーにある限り検証を通過しうるからです。ログと成果物は [`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini) にあります。

## 3. 新しいモデルでも、精度とコストを左右したのはオントロジーの渡し方

公開パッケージ上で Gemini 3.7 Flash と 3.8 Flash の両方を回しても、プロンプトに無い名前をモデルが捏造した件数は全条件で 0 のままでした。精度とコストの差の大半は、モデル名よりオントロジーの渡し方にあります。`large` で推奨の `subset_fallback` は、同ランの `full` に対し Property Hit が +30pt（3.7）/ +16.25pt（3.8）、プロンプトトークン数の p95 はいずれも約 −90.5% でした。公開 PyPI でも、第3部で見たサブセット効果は再現しています。

ただし、本評価に「オントロジーなし」条件はありません。`full` もオントロジー全体をプロンプトに載せています。オントロジー導入そのものの利得ではなく、同じオントロジーをどう渡すかで Hit とトークンが変わる、とだけ言えます。

モデル差し替え（3.7 → 3.8）では、`full` / `subset` 単体は上がり（例: `large` full Hit 0.65 → 0.725）、推奨の `subset_fallback` はやや下がりました（Hit 0.95 → 0.8875、Compile 40/40 → 37/40）。Track B の Compile も 39 → 36/60 です。「新しいモデルだから自動的に良い」とは言えず、差し替えるたびに同じ評価セットで測る必要があります。数値の一覧は [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md) にあります。

## 限界

各条件は 1 回のみです。E2E の LLM 経由成功率は小さいサンプルで低く、検証が不正なスキーマ名を止めたことと、タスク完了率は別問題です。Track B の Exec Match は 3 ランとも 1 件で、Gold が Cypher（Intent ではない）ため完全一致は弱証拠です（第3部と同じ注記です）。Intent の Gold 化や実業務オントロジーでの追試は、第3部で挙げた計画の延長として残ります（時期は未定です）。

試すときは `pip install "ontographia[llm]"` / `"ontographia[mcp]"`（いずれも experimental）です。手順は [docs/llm.md](https://edgesentry.github.io/ontographia/llm/) と [docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/) を参照してください。
