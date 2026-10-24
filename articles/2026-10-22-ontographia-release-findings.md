---
title: "Ontographia 第4部 - 新しい LLM での精度評価とハルシネーション防止機構の検証"
emoji: "🔬"
type: "tech"
topics: ["neo4j", "cypher", "llm", "mcp", "ontology"]
published: false
---

:::message
**連載の位置づけ（Ontographia）**

自然言語からグラフデータベース（Neo4j 等）へ問い合わせるとき、LLM に Cypher を書かせるか、固定テンプレで縛るかの二者択一になりやすい。本連載は、Intent JSON だけを LLM に任せ、Cypher はオントロジー拘束の決定論的パイプラインで組み立てる [Ontographia](https://github.com/edgesentry/ontographia) を設計・検証する。

| 部 | 記事 | 役割 |
| :--- | :--- | :--- |
| **第1部** | [グラフAIのジレンマ：LLMにCypherを書かせるか、テンプレ保守地獄に耐えるか](https://zenn.dev/yohei/articles/2026-09-08-ontographia-template-cost) | 課題と仮説 |
| **第2部** | [Intent-first の設計と実装](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design) | アーキテクチャ |
| **第3部** | [検証結果と今後のロードマップ](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap) | Track A / B の定量評価 |
| **第4部** | 新しい LLM での精度評価とハルシネーション防止機構の検証（本記事） | 公開パッケージでの追試 |

リポジトリ: [edgesentry/ontographia](https://github.com/edgesentry/ontographia) · 評価ベースライン: [`examples/llm/eval/baselines/`](https://github.com/edgesentry/ontographia/tree/main/examples/llm/eval/baselines)
:::

## 概要

[第3部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap)では、Intent-first の仮説を Track A / Track B で測った。その後、2026-10-21 に [v0.1.6](https://github.com/edgesentry/ontographia/releases/tag/v0.1.6) が公開され、Intent 層は `pip install "ontographia[llm]"`、実験的 MCP サーバは `pip install "ontographia[mcp]"` で入れられるようになった（いずれも experimental / 0.x。関連: [PR #93](https://github.com/edgesentry/ontographia/pull/93)、[PR #94](https://github.com/edgesentry/ontographia/pull/94)、実 Neo4j 向け CI: [PR #99](https://github.com/edgesentry/ontographia/pull/99)）。

本記事は、公開 PyPI パッケージ上で第3部と同条件のライブ評価をやり直し（Gemini 3.7 Flash / 3.8 Flash）、実 LLM と実 Neo4j の end-to-end（E2E）も記録したうえで、次の 3 点に絞る。数値はリポジトリにコミットされたベースラインからの引用である（比較表: [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md)。記録 PR: [PR #107](https://github.com/edgesentry/ontographia/pull/107)、[PR #109](https://github.com/edgesentry/ontographia/pull/109)）。

ハルシネーション防止の記述は、次の 2 点に限定する。invent-without-seeing（プロンプトに無い名前の捏造）が 0 であること、およびオントロジーに無いスキーマ名が検証でデータベース到達前に止まることである。すべてのハルシネーションを防ぐ、という意味ではない。

評価条件は temperature 0、Track A は n=40、Track B は n=60（seed 53）、各条件 1 回のみ、実施日 2026-10-22 である。ライブラリは `ontographia[llm]==0.1.6`（PyPI）である。LiteLLM の Gemini エイリアスは版付きのみ（`ontographia-gemini-3.7` / `ontographia-gemini-3.8`）である。無版の `ontographia-gemini` は [PR #109](https://github.com/edgesentry/ontographia/pull/109) で削除済みである。

---

## 1. 実験的 MCP サーバと 4 ツール

v0.1.6 の新機能のひとつが、実験的な MCP サーバ（`ontographia[mcp]`）である。サーバ自身は LLM を呼ばない。クライアントが Intent JSON を出し、サーバは検証・Cypher 生成・（任意で）Neo4j 実行だけを担う（[docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/)）。

| ツール | 役割 |
| :--- | :--- |
| `list_ontology` | クラス / リレーション / プロパティの要約 |
| `intent_schema` | オントロジー拘束の Intent JSON Schema |
| `build_cypher` | Intent → パラメータ付き Cypher（失敗時は `ok: false`） |
| `execute` | 検証済み Intent から生成した Cypher のみを実行（生 Cypher は受け付けない） |

E2E 記録（[`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini)）では、`tools/list` で上記 4 つが返り、保存済み Intent のリプレイで `build_cypher` → `execute` まで通った（結果 2 行）。`execute` の結合テストは実 Neo4j に対して CI でも走っている（[PR #99](https://github.com/edgesentry/ontographia/pull/99)）。

Intent 抽出ヘルパーは別のオプション extra（`ontographia[llm]`、experimental）である。MCP と組み合わせると、ホスト側 LLM が Intent を出し、Ontographia MCP が検証・生成・実行を担う、という責務境界になる。

## 2. 実 LLM と実 Neo4j の E2E

[`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini) には、質問「List suppliers for parts in product SKU SPX-100」を Gemini 3.7 Flash（temperature 0）とローカル Neo4j で試した記録がある。試行は 4 件すべて残してある（[`runs.json`](https://github.com/edgesentry/ontographia/blob/main/examples/e2e/v0.1.6-gemini/runs.json)）。記録時の LiteLLM エイリアスは当時の `ontographia-gemini`（upstream は `gemini-3.7-flash`）である。

| 試行 | 経路 | Cypher | 実行 | 行数 |
| :--- | :--- | :---: | :---: | ---: |
| `cli_run1` | CLI（`run_llm_e2e.py --execute`） | 成功 | 成功 | 2 |
| `cli_run2` | CLI | 失敗（壊れたプロパティ名を検証拒否） | なし | — |
| `mcp_llm` | MCP + LLM | 失敗（例: `"name激as_name"`、traverse 欠落） | なし | — |
| `mcp_replay` | MCP（保存 Intent の再実行、LLM なし） | 成功 | 成功 | 2 |

成功した `cli_run1` の成果物は次のとおり（要約）である。

```json
{
  "start": { "class": "Product", "alias": "product" },
  "traverse": [
    { "relationship": "has_part", "direction": "out", "to": { "class": "Part", "alias": "part" } },
    { "relationship": "supplied_by", "direction": "out", "to": { "class": "Supplier", "alias": "supplier" } }
  ],
  "filter": [{ "alias": "product", "property": "sku", "op": "eq", "value": "SPX-100" }],
  "return": [{ "alias": "supplier", "property": "name", "as_name": "supplier_name" }],
  "limit": 20
}
```

```cypher
CYPHER 25
MATCH (product:Product)-[:has_part]->(part:Part)-[:supplied_by]->(supplier:Supplier)
FILTER product.sku = $param_0
RETURN supplier.name AS supplier_name
LIMIT 20
```

```json
{ "param_0": "SPX-100" }
```

結果行は `MikroMotors` と `FormTech` である。

一方、`cli_run2` と `mcp_llm` では、この 3.7 Flash セッションの LLM 出力に、オントロジーに無いプロパティ名（例: `"name激as_name"`）が含まれた。検証が落ち、Cypher は発行されずデータベースにも届いていない。

ここでいうハルシネーション防止は、オントロジーに無いスキーマ名がクエリとしてデータベースに到達するのを止める機構である。「すべてのハルシネーションが消える」のではない。事実誤認やサイレント誤答（実在するが文脈に合わない語彙の選択）までは排除しない。

なお、この小さなサンプルでは、LLM 経由の E2E 成功は 4 試行中 1 件にとどまる。temperature 0 でも出力は揺れる。

## 3. Gemini 3.7 / 3.8 Flash の精度と、スキーマ名ハルシネーション防止の範囲

第3部と同じ Track A の仮説 H1（動的サブセット）評価（プロファイル `mid` / `large` × 条件 `full` / `subset` / `subset_fallback`）を、公開 PyPI パッケージ上で Gemini 3.7 Flash と 3.8 Flash の両方で取り直した。各条件は 1 回のみである。

まず invent-without-seeing（プロンプトに無い名前の捏造）と near-dup（near-duplicate: 類似妨害語彙）の選択である。どちらも、3 ランすべて・全条件で 0 だった。未知語彙はオントロジー列挙とコア検証で弾かれる。モデルを 3.8 に替えても invent-without-seeing は 0 のままである。ここでも防止の対象は、不正なスキーマ名が Intent を通過しないことに限る。

次に、同じモデル内でオントロジーの渡し方を変えたときの精度とコストである。`large` で推奨の `subset_fallback`（質問に合わせたサブセット、失敗時のみフル）は、同ランの `full`（オントロジー全体をプロンプトに載せる）に対し、Property Hit（プロパティ正答率）が +30pt（3.7）/ +16.25pt（3.8）、プロンプトトークン数の p95（tok p95）はいずれも約 −90.5% だった。3 ランとも H1 の事前ゲートを満たし、ハーネス判定は支持（support）である。公開 PyPI パッケージでも、第3部で見たサブセット効果は再現した。

| 条件 | 第3部 3.7 | v0.1.6 3.7 | v0.1.6 3.8 |
| :--- | ---: | ---: | ---: |
| full Hit | 0.825 | 0.65 | 0.725 |
| full Compile | 33/40 | 27/40 | 30/40 |
| subset_fallback Hit | 0.95 | 0.95 | 0.8875 |
| subset_fallback Compile | 40/40 | 40/40 | 37/40 |

本評価に「オントロジーなし」条件はない。`full` もオントロジー全体をプロンプトに含んでいる。したがって、オントロジー導入そのものの利得は主張しない。同じオントロジーをどう渡すか（全体ダンプか、質問誘導のサブセット＋必要時フォールバックか）で、精度とコストが大きく変わる、とだけ言える。

モデル差し替え（3.7 → 3.8）では、オントロジー供給が弱い条件（`full` と `subset` 単体）で数値が上がった。`large` の `full` Hit は同日の v0.1.6 3.7 の 0.65 → 0.725、`subset` 単体も 0.6125 → 0.75（Compile 25/40 → 31/40）である。一方、推奨の `subset_fallback` では Hit 0.95 → 0.8875、Compile 40/40 → 37/40 とやや下がる。Track B の Compile も 39 → 36/60 である。invent-without-seeing はどちらでも 0 のままである。

このモデル間の差は、同モデル内の `subset_fallback` 対 `full`（+16〜30pt・tok p95 約 −90.5%）より小さい。「新しいモデルだから自動的に良い」とは言えない。差し替え後も invent-without-seeing は 0 のままであり、同じ評価セットで測れる。改善の有無は条件ごとにばらつくので、差し替えるたびに測る。

補足として、3.7 の再計測では `full` / `subset` 単体が第3部より落ちている（例: `mid` の `full` Hit 0.75 vs 0.8875、`large` の `full` 0.65 vs 0.825）。原因はソース上も未特定である。Track B の Exec Match（実行結果の行集合の完全一致）は 3 ランとも 1 件である。Gold が Cypher（Intent ではない）ため、完全一致は弱証拠である、という第3部の注記はそのまま使う。

## インストールと LiteLLM エイリアス

```bash
pip install "ontographia[llm]"   # Intent 層（experimental）
pip install "ontographia[mcp]"   # MCP サーバ（experimental）
```

LiteLLM 経由なら版付きエイリアスを使う（[docs/litellm-local.md](https://edgesentry.github.io/ontographia/litellm-local/)）。

```bash
source scripts/litellm/use-provider.sh gemini-3.7   # または gemini-3.8
# モデル指定例: ontographia-gemini-3.7 / ontographia-gemini-3.8
```

詳細は [docs/llm.md](https://edgesentry.github.io/ontographia/llm/)、[docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/)、E2E 再現手順は [`examples/e2e/v0.1.6-gemini/README.md`](https://github.com/edgesentry/ontographia/blob/main/examples/e2e/v0.1.6-gemini/README.md) を参照する。

## 限界

各条件は 1 回のみであり、temperature 0 でもライブ LLM の出力は揺れる。`full` ベースラインの低下理由は未特定である。E2E の LLM 経由成功率は小さいサンプルで低く、検証器がオントロジーに無いスキーマ名を止めたことと、タスク完了率は別問題である。

Intent gold 化・言い換え許容メトリクス、シノニム付きサブセット、実業務オントロジーでの追試は、第3部で挙げた計画の延長として残る（日付は約束しない）。

公開パッケージと MCP でも、LLM は Intent、Cypher は決定論、という責務境界は維持された。スキーマ名ハルシネーションの防止（invent-without-seeing 0、不正名の検証拒否）と、精度・コストの大きな差（`subset_fallback` 対 `full`）は、いずれもオントロジー拘束とその供給の仕方に由来する。モデル差し替えはその計測を壊さないが、指標を一様には改善しない。
