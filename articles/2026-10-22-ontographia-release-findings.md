---
title: "Ontographia 第4部 - 新しい LLM での精度評価とハルシネーション防止機構の検証"
emoji: "🔬"
type: "tech"
topics: ["neo4j", "cypher", "llm", "mcp", "ontology"]
published: false
---

:::message
**連載の位置づけ（Ontographia）**

自然言語からグラフ DB へ問い合わせるとき、LLM に Cypher を書かせるか、固定テンプレで縛るかの二者択一になりやすい。本連載は、Intent JSON だけを LLM に任せ、Cypher はオントロジー拘束の決定論的パイプラインで組み立てる [Ontographia](https://github.com/edgesentry/ontographia) を設計・検証する。

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

本記事は、公開 PyPI パッケージ上で第3部と同条件のライブ評価をやり直し、実 LLM と実 Neo4j の E2E も記録したうえで、次の3点に絞る。数値はリポジトリにコミットされたベースラインからの引用である（比較表: [`gemini_3.7_vs_3.8_v0.1.6.md`](https://github.com/edgesentry/ontographia/blob/main/examples/llm/eval/baselines/gemini_3.7_vs_3.8_v0.1.6.md)。記録 PR: [PR #107](https://github.com/edgesentry/ontographia/pull/107)、[PR #109](https://github.com/edgesentry/ontographia/pull/109)）。

評価条件は temperature 0、Track A n=40、Track B n=60 seed 53、各条件1回のみ、実施日 2026-10-22。ライブラリは `ontographia[llm]==0.1.6`（PyPI）。LiteLLM の Gemini エイリアスは版付きのみ（`ontographia-gemini-3.7` / `ontographia-gemini-3.8`）。無版の `ontographia-gemini` は [PR #109](https://github.com/edgesentry/ontographia/pull/109) で削除済み。

---

## 1. MCP サーバが入り、4ツールが実機で通った

v0.1.6 の新機能のひとつが、実験的な MCP サーバ（`ontographia[mcp]`）である。サーバ自身は LLM を呼ばない。クライアントが Intent JSON を出し、サーバは検証・Cypher 生成・（任意で）Neo4j 実行だけを担う（[docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/)）。

| ツール | 役割 |
| :--- | :--- |
| `list_ontology` | クラス / リレーション / プロパティの要約 |
| `intent_schema` | オントロジー拘束の Intent JSON Schema |
| `build_cypher` | Intent → パラメータ付き Cypher（失敗時は `ok: false`） |
| `execute` | 検証済み Intent から生成した Cypher のみを実行（生 Cypher は受け付けない） |

E2E 記録（[`examples/e2e/v0.1.6-gemini/`](https://github.com/edgesentry/ontographia/tree/main/examples/e2e/v0.1.6-gemini)）では、`tools/list` で上記4つが返り、保存済み Intent のリプレイで `build_cypher` → `execute` まで通った（結果2行）。`execute` の結合テストは実 Neo4j に対して CI でも走っている（[PR #99](https://github.com/edgesentry/ontographia/pull/99)）。

Intent 抽出ヘルパーは別 extra（`ontographia[llm]`）である。MCP と組み合わせると、ホスト側 LLM → Intent → Ontographia MCP という境界がはっきりする。

## 2. 実 E2E では、不正なスキーマ名が DB に届く前に止まった

同じディレクトリに、質問「List suppliers for parts in product SKU SPX-100」を実 Gemini 3.7 Flash（temperature 0）とローカル Neo4j で試した記録がある。試行は4件すべて残してある（[`runs.json`](https://github.com/edgesentry/ontographia/blob/main/examples/e2e/v0.1.6-gemini/runs.json)）。モデルは Gemini 3.7 Flash（記録時の LiteLLM エイリアスは当時の `ontographia-gemini`）である。

| 試行 | 経路 | Cypher | 実行 | 行数 |
| :--- | :--- | :---: | :---: | ---: |
| `cli_run1` | CLI（`run_llm_e2e.py --execute`） | 成功 | 成功 | 2 |
| `cli_run2` | CLI | 失敗（壊れたプロパティ名を検証拒否） | なし | — |
| `mcp_llm` | MCP + LLM | 失敗（例: `"name激as_name"`、traverse 欠落） | なし | — |
| `mcp_replay` | MCP（保存 Intent の再実行、LLM なし） | 成功 | 成功 | 2 |

成功した `cli_run1` の成果物は次のとおり（要約）。

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

一方、`cli_run2` と `mcp_llm` では、この 3.7 Flash セッションの LLM 出力に壊れたプロパティ名（スキーマ上に存在しない名前）が含まれた。検証が落ち、Cypher は発行されず DB にも届いていない。ここで言うハルシネーション防止は、不正なスキーマ名がクエリとして DB に到達するのを止める機構である。事実誤認やサイレント誤答（実在するが文脈に合わない語彙の選択）まで排除するわけではない。しかし、この小さなサンプルでは LLM 経由の end-to-end 成功は4試行中1件にとどまる。temperature 0 でも出力は揺れる。

## 3. 新しい LLM での精度と、スキーマ名ハルシネーション防止の範囲

第3部と同じ Track A H1（mid / large × full / subset / subset_fallback）を、公開 PyPI パッケージ上で Gemini 3.7 Flash と 3.8 Flash の両方で取り直した。各条件は1回のみである。

まずハルシネーション防止の計測範囲である。invent-without-seeing（プロンプトに無い名前の捏造）と near-dup 選択は、3ランすべて・全条件で0だった。未知語彙はオントロジー列挙とコア検証で弾かれる。モデルを 3.8 に替えても、この境界は崩れていない。ここでも「すべてのハルシネーションが消える」のではなく、不正なスキーマ名が Intent を通過しない、という限定付きの防止である。

次に、同じモデル内でオントロジーの渡し方を変えた精度・コストの比較である。large で推奨の `subset_fallback`（質問に合わせたサブセット、失敗時のみフル）は、同ランの `full`（オントロジー全体をプロンプトに載せる）に対し Property Hit が +30pt（3.7）/ +16.25pt（3.8）、tok p95 はいずれも約 −90.5% だった。3ランとも H1 の事前ゲートを満たし support である。公開 PyPI パッケージでも、第3部で見たサブセット効果は再現した。

| 条件 | 第3部 3.7 | v0.1.6 3.7 | v0.1.6 3.8 |
| :--- | ---: | ---: | ---: |
| full Hit | 0.825 | 0.65 | 0.725 |
| full Compile | 33/40 | 27/40 | 30/40 |
| subset_fallback Hit | 0.95 | 0.95 | 0.8875 |
| subset_fallback Compile | 40/40 | 40/40 | 37/40 |

ここで「オントロジーなし」との比較ではない、と限定する。本評価に「オントロジーなし」条件はない。`full` もオントロジー全体をプロンプトに含んでいる。オントロジー導入そのものの利得は主張しない。言えるのは、同じオントロジーをどう渡すか（全体ダンプか、質問誘導のサブセット＋必要時フォールバックか）で精度とコストが大きく変わる、ということだけである。

モデル差し替え（3.7 → 3.8）では、供給が弱い側で数値が上がった。large full の Hit は同日の v0.1.6 3.7 の 0.65 → 0.725、subset 単体も 0.6125 → 0.75（Compile 25/40 → 31/40）である。一方、推奨の `subset_fallback` では Hit 0.95 → 0.8875、Compile 40/40 → 37/40 とやや下がる。Track B の Compile も 39 → 36/60 である。invent-without-seeing はどちらでも0のままである。

このモデル間の差は、同モデル内の subset_fallback 対 full（+16〜30pt・tok p95 約 −90.5%）より小さい。「新しいモデルだから自動的に良い」とは言えない。差し替えは、スキーマ名ハルシネーション（invent 0）の境界を壊さず、同じ評価セットで測れる。改善の有無は条件ごとにばらつくので、差し替えるたびに測る。

補足として、3.7 の再計測では full / subset 単体が第3部より落ちている（例: mid full Hit 0.75 vs 0.8875、large full 0.65 vs 0.825）。原因はソース上も未特定である。Track B の Exec Match は3ランとも1件である。Gold が Cypher（Intent ではない）ため、完全一致は弱証拠である、という第3部の注記はそのまま使う。

## 試すとき

```bash
pip install "ontographia[llm]"   # Intent 層（experimental）
pip install "ontographia[mcp]"   # MCP サーバ（experimental）
```

LiteLLM 経由なら版付きエイリアスを使う（[docs/litellm-local.md](https://edgesentry.github.io/ontographia/litellm-local/)）。

```bash
source scripts/litellm/use-provider.sh gemini-3.7   # または gemini-3.8
# モデル指定例: ontographia-gemini-3.7 / ontographia-gemini-3.8
```

詳細は [docs/llm.md](https://edgesentry.github.io/ontographia/llm/)、[docs/mcp.md](https://edgesentry.github.io/ontographia/mcp/)、E2E 再現手順は [`examples/e2e/v0.1.6-gemini/README.md`](https://github.com/edgesentry/ontographia/blob/main/examples/e2e/v0.1.6-gemini/README.md)。

## 限界と次

各条件は1回のみであり、temperature 0 でもライブ LLM の出力は揺れる。full ベースラインの低下理由は未特定である。E2E の LLM 経由成功率は小さいサンプルで低く、検証器が不正なスキーマ名を止めたこととタスク完了率は別問題である。ハルシネーション防止機構が保証するのは、不正なスキーマ名が DB に届かないことまでであり、すべてのハルシネーションを防ぐわけではない。Intent gold 化・言い換え許容メトリクス、シノニム付きサブセット、実業務オントロジーでの追試は、第3部で挙げた計画の延長として残る（日付は約束しない）。

LLM は Intent、Cypher は決定論、という境界は、公開パッケージと MCP でも同じ形で動いた。スキーマ名ハルシネーションの防止（invent 0、不正名の検証拒否）も、精度・コストの大きな差（サブセット対フル）も、主にオントロジー拘束とその供給の仕方から来る。モデル差し替えはその境界を壊さず測れるが、自動では良くならない。
