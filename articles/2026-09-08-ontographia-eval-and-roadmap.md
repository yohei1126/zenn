---
title: "Ontographia 第3部 - 検証結果と今後のロードマップ：大規模オントロジー評価と外的妥当性"
emoji: "📊"
type: "tech"
topics: ["neo4j", "cypher", "llm", "evaluation", "ontology"]
published: false
---

:::message
**連載の位置づけ（Ontographia 三部作）**

自然言語からグラフデータベース（Neo4j 等）へ問い合わせを行う際、多くの現場は「LLM に直接 Cypher クエリを書かせるか」「手書きの巨大な固定クエリ／テンプレ集で縛るか」の二者択一で揺れ動きます。

本連載では、その妥協案として普及しつつある **Agent Skills + ユースケース別テンプレ選定（現行ハイブリッド）** の限界を浮き彫りにし、Neo4j アカウントチームから共有された最新研究の潮流を踏まえた上で、**「LLM には意図抽出（Intent JSON）だけを担わせ、Cypher クエリの組み立てはオントロジー拘束付きの決定論的 AST パイプラインで行う」** という新しい方法論（[Ontographia](https://github.com/edgesentry/ontographia) プロジェクト）を提案・検証します。

| 部 | 記事 | 役割 |
| :--- | :--- | :--- |
| **第1部** | [グラフAIのジレンマ：LLMにCypherを書かせるか、テンプレ保守地獄に耐えるか](https://zenn.dev/yohei/articles/2026-09-08-ontographia-template-cost) | 現場の課題・最新研究の整理と新仮説 |
| **第2部** | [Intent-first の設計と実装：決定論的 Cypher 組み立てのアーキテクチャ](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design) | コアとアプリ層の分離・実装詳解 |
| **第3部** | [検証結果と今後のロードマップ：大規模オントロジー評価と外的妥当性](https://zenn.dev/yohei/articles/2026-09-08-ontographia-eval-and-roadmap)（本記事） | 定量的ストレス試験・公開データ検証 |

評価の正本: [Evaluation ガイド](https://edgesentry.github.io/ontographia/evaluation/) · 再現コード: [`examples/llm/eval/`](https://github.com/edgesentry/ontographia/tree/main/examples/llm/eval)  
リポジトリ: [edgesentry/ontographia](https://github.com/edgesentry/ontographia)
:::

## 概要

[第1部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-template-cost)では、テンプレ選択ハイブリッドが抱える保守限界と、Intent-first という新仮説を提示しました。そして[第2部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design)では、LLM に Intent JSON を出させ、決定論的に Cypher を組み立てるアーキテクチャ境界と、Neo4j 先端研究を Intent 層へ写像した拡張（Subset と実行フィードバック）を解説しました。

本記事（第3部）では、この **Intent-first アプローチが実運用の大規模スキーマでどこまで通用し、何が解決され、何が課題として残るのか** を、定量的実験と公開データセットを用いて検証します。

### 本記事で用いる検証フレームワーク（仮説・トラック・実験アーム）

定量的評価に入る前に、本記事で登場する評価用語と実験の枠組みを整理しておきます。

* **3つの検証仮説（H1 / H2 / H3）：** 第2部で提案した各アーキテクチャ機能がもたらす効果に関する仮説です。
  * **H1（動的 Subset）：** 質問に関連する語彙だけに絞り込むことで、トークン消費を抑えつつ誤フィールド選択を防げるか。
  * **H2（実行フィードバック）：** 「コンパイルは成功したが実行結果が 0 件（Empty@Valid）」の際に、実行結果から Intent を再修復できるか。
  * **H3（難易度適応型コスト配分）：** 易しい質問は最小限のリソースで解き、難問のみフルスキーマへエスカレーションして推論コストを最適化できるか。
* **2つの検証トラック（Track A / Track B）：**
  * **Track A（合成ストレステスト）：** 製造ドメインの大規模オントロジー（最大 2,000 プロパティ）を用い、意図的に混入させた類似プロパティ（Distractor）に対する耐性と各機構（H1〜H3）の有効性を測定する社内合成トラック。
  * **Track B（公開データでの外的妥当性）：** Neo4j 公式の公開ベンチマーク（15 個の外部 DB スキーマ）を用い、Ontographia の共通スキーマモデル（COM）が自作スキーマ以外にも汎用的に通用するかを検証するトラック。
* **2つの実験アーム（機械アーム vs ライブ LLM アーム）：**
  * 「アーム（Arm）」とは、統計学や臨床試験・A/B テストにおける **実験群・検証条件** を指す用語です。
  * **機械アーム（Mechanical / Synthetic Arm）：** LLM API の確率的な出力揺らぎや通信コストを排し、プロンプトの妨害語彙に釣られる挙動やリトライの挙動を「決定論的なモックやシミュレーションルール」で再現した実験系。パイプライン構造やアルゴリズム自体の耐性を厳密かつ再現可能に単体測定するために用います。
  * **ライブ LLM アーム（Live LLM Arm）：** 実際に商用 LLM（GPT-4 等）の API を呼び出してエンドツーエンドの推論精度を測定する実験系（今後のロードマップ課題）。

---

本記事の結論を先取りすると、以下の5点に集約されます。

1. **「エラーにならない誤フィールド選択（サイレント誤答）」の実態:** 大規模オントロジーでは、未知名は弾けても「正しい語彙の中の誤った選択」が平然とコンパイルを通ってしまう。
2. **仮説 H1 の実証（動的 Subset / 機械アームで Support）:** 質問トークンに基づく Exact-match Subset 化により、トークン消費量を **約91% 削減** しつつ、プロパティ正答率（Property Hit）を **+50pt 改善** できた。
3. **仮説 H2 の実証（実行フィードバック / 機械アームで Support）:** Empty@Valid（コンパイル成功・実行 0 件）に対し、実行フィードバックで Intent を直し再コンパイルすると最終実行が回復する。
4. **仮説 H3 の実証（難易度適応型配分 / 機械アームで Support）:** 易しい質問では subset-first + 少ないリトライでトークンを **約91% 削減**しつつ品質を維持し、難問のみフルスキーマへ escalate する。
5. **公開データへの外的妥当性（Track B）と正直なロードマップ:** 公開ベンチマーク 15 DB を COM へ 100% 取り込み成功。ライブ LLM アームによる実測や公開 DB 上の Exec Match はこれからの課題。

擬似データだけで「完璧に証明された」と誇張するつもりはありません。現在の到達点と限界を客観的な数値とともに示します。

---

## 1. 検証で答えたい3つの仮説

Ontographia の価値仮説として、第2部で設計・実装した3つの拡張機構に対応する以下の検証目標を設定しています。

| ID | 仮説の内容 | 対応する機能 | 評価状況 |
| :--- | :--- | :--- | :--- |
| **H1** | 大規模オントロジーにおいて、フルスキーマよりも **Subset** をプロンプトに渡す方が、Intent のフィールド選択精度が向上し、トークン消費も激減する。 | 動的 Subset 化 | **検証完了（Support）** |
| **H2** | 静的な構造検証だけでは拾えない空結果・実行時エラーに対し、**Neo4j 実行フィードバックで Intent を再修復** することで最終回答精度が改善する。 | 実行フィードバック (`--refine-on-exec`) | **検証完了（機械アーム Support）** |
| **H3** | 易しい質問ではフルスキーマや多段リトライを省略しても品質を落とさず、**推論コストを大幅に削減できる**。 | 難易度適応型配分 (Adaptive spend) | **検証完了（機械アーム Support）** |

:::message
評価状況における「機械アーム Support」とは、LLM API の呼び出し揺らぎを排した決定論的シミュレーション（機械アーム）において、パイプラインの修復機構やコスト削減アルゴリズムが意図通りに機能することが実証された状態を指します。
:::

### 各仮説の事前合否判定基準

恣意的な後付け評価を避けるため、実験前にコード上で「支持（Support）」「部分的支持（Partial）」「不支持（Reject）」の判定基準を明義しています。

#### 仮説 H1（動的 Subset）の判定基準
* **支持（Support）:** `large`（2,000 プロパティ）において、Property Hit が Full スキーマより +10pt 以上高く、プロンプトトークン p95 が 30% 以上削減され、Compile 成功率を落とさないこと。
* **部分的支持（Partial）:** トークンは削減されるが品質は同等にとどまること。
* **不支持（Reject）:** Subset 化によって必要な語彙が削られ、コンパイル成功率や品質が有意に劣化すること。

#### 仮説 H2（実行フィードバック）の判定基準
* **支持（Support）:** 空結果誘発（empty-inducing）セットにおいて、refine 有効時の最終実行成功率が +20pt 以上改善し、Intent Exact Match が回復し、かつ出力 Cypher がすべて `Engine.build` と一致していること（決定論的 AST ビルドの不変条件維持）。
* **部分的支持（Partial）:** 実行結果の回復は見られるが、改善幅が +20pt 未満にとどまること。
* **不支持（Reject）:** 実行フィードバックを行っても最終実行成功率が改善しない（または悪化する）こと。

#### 仮説 H3（難易度適応型配分）の判定基準
* **支持（Support）:** `large` かつ易問（easy スライス）において、always_full_fixed に対しトークン p95 が 30% 以上削減され、平均 LLM 呼び出し回数が増加せず、Compile 成功率・Property Hit を落とさないこと（難問 hard スライスではフルへ escalate して回復すること）。
* **部分的支持（Partial）:** コストは削減されるが品質にばらつきが出る、または特定条件でしか効果が出ないこと。
* **不支持（Reject）:** 適応型配分によって品質が劣化する、またはコストが削減されないこと。

---

## 2. Track A — 「通る誤フィールド」の定量的再現

Track A は、実務で直面する大規模オントロジーの類似語彙環境を模した**合成ストレステスト**です。
ここでは、まず現状のフルスキーマ（全件プロンプト投入）において、誤ったフィールド選択がどれほど「サイレントに通過してしまうか」を定量的に再現し、その上で仮説 H1〜H3 の各機構の有効性を測定します。

### 問い
数千プロパティ規模の巨大オントロジー上で、Intent が **「それらしいが間違っているプロパティ」** を選んだ場合、コアの検証器（`validate_intent`）はどう振る舞うか？

製造ドメインの 40 問の Gold Intent に対し、意図的に「似て非なるプロパティ（Near-duplicate な邪魔要素: Distractor）」へ機械的に差し替えたデータを作成しました（例: 正解の `Plant.name` を、同じオントロジー内に存在する無関係な `PlantName` や類似プロパティへ置換）。

オントロジー規模は `small`（16プロパティ）、`mid`（200プロパティ）、`large`（2,000プロパティ）の 3 段階で評価しました。

### フルスキーマにおけるベースライン結果

| オントロジー規模 | プロパティ数 | Gold コンパイル | サイレント誤答コンパイル | サイレント誤答検知 | トークン数 (Full) | トークン数 (Subset) |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| **small** | 16 | 40 / 40 | 0 | **40** | 1,359 | 1,246 |
| **mid** | 200 | 40 / 40 | **40 / 40** | 0 | 2,460 | 1,247 |
| **large** | 2,000 | 40 / 40 | **40 / 40** | 0 | **13,710** | **1,247** |

### この結果が意味すること
* `small` スキーマでは、不要なプロパティが存在しないため、誤ったプロパティ名を含む Intent は未知名エラーとして 100% 弾かれました。
* しかし `mid` や `large` になると、**誤ったプロパティであってもオントロジー内に実在するため、コアのバリデーションを完全に通過し、正常に Cypher へコンパイルされてしまいました（40/40）**。

これが、実務で最も恐ろしい **「失敗がエラーにならない（サイレント誤答）」** 現象です。
構文検査器や AST ビルダーは、「その名前がスキーマに実在するか」は検査できても、「ユーザーの意図に合致しているか」までは判断できません。さらに、フルスキーマのプロンプトは `large` で 13,710 トークンまで肥大化し、コストとレイテンシを激しく圧迫します。

詳細と再現スクリプト: [Evaluation — Track A](https://edgesentry.github.io/ontographia/evaluation/#track-a-distractor-ontology-stress-test)
```bash
uv run python examples/llm/eval/run_track_a.py --record
```

---

## 3. 仮説 H1 の実証 — Full vs Subset vs Subset+Fallback

次に、[第2部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design)で導入した **Ontology Subset（動的語彙絞り込み）** が、このサイレント誤答とトークン肥大化をどれだけ防げるかを検証しました。

### 実験条件
* **Full:** 全オントロジーをプロンプトにダンプする。
* **Subset:** 質問文との Exact-match（語彙マッチ）により、関連するクラスとリレーションのみに絞り込む。
* **Subset + Fallback:** Subset で Intent 検証が通らない、または語彙が不足している場合のみ、自動でフルスキーマに戻す（実運用の推奨設定）。

### 結果（large オントロジー環境）

| 条件 | Property Hit (正答率) | Compile 成功率 | 妨害プロパティ露出 | 誘発された誤答数 | Fallback 発生率 | トークン数 (p95) |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| **Full** | 0.50 | 40 / 40 | 40 | 40 | 0% | 13,710 |
| **Subset** | **1.00** | 40 / 40 | **0** | **0** | 0% | **1,247** |
| **Subset + Fallback** | **1.00** | 40 / 40 | **0** | **0** | 0% | **1,247** |

### 判定：仮説 H1 は「支持（Support）」
事前基準を圧倒的に上回る成果が確認されました。
* **Property Hit:** 0.50 → **1.00 (+50pt 改善)**。質問に関係のないプロパティがプロンプトから不可視化されたため、誤選択が構造的に排除された。
* **トークン消費量 (p95):** 13,710 → **1,247（約 91% 削減）**。大規模オントロジーであっても小規模並みのプロンプトコストで動作。
* **コンパイル成功率:** 40 / 40 を維持。
* **Fallback 率:** 本評価フィクスチャでは 0%（必要な語彙が確実に Subset で捕捉された）。

> [!WARNING]
> **重要な前提と限界（Caveat）**
> この実験は「機械アーム（Prompt-induced distractibility）」による制御実験です。実際のライブ LLM は、プロンプトに存在しないプロパティ名をモデルの事前学習知識から勝手に捏造（発明）する可能性があります。このライブ LLM での挙動確認は、後述のロードマップとして継続追跡中です。

再現スクリプト:
```bash
uv run python examples/llm/eval/run_track_a_h1.py --record
```

---

## 4. Track B — 公開 Text2Cypher ベンチマークへの外的妥当性

自前の製造業オントロジーを用いた Track A（合成ストレステスト）に対し、**Track B** では、Ontographia のスキーマ表現（COM）が自社製以外の多様なドメインスキーマにも耐えうるかという**外的妥当性（Generalizability）** を検証します。

### 問い
Ontographia のオントロジー表現（COM）は、自作のデモ用スキーマだけでなく、世の中に公開されている多様なグラフスキーマを正しく取り込めるか？

Neo4j 社が公開しているベンチマークデータセット **[neo4j/text2cypher-2025v1](https://huggingface.co/datasets/neo4j/text2cypher-2025v1)** から、`Node properties` 形式を持つ 15 のデモデータベーススキーマを抽出し、COM 形式への自動変換（`schema_convert.py`）を試みました。

### 取り込み結果

| 測定メトリクス | 測定値 |
| :--- | ---: |
| **デモ DB 変換・`Engine.load` 成功率** | **15 / 15 (100%)** |
| **平均ノードラベル・カバレッジ** | **約 96%** |
| **平均リレーションシップ・カバレッジ** | **100%** |
| **平均プロパティ・カバレッジ** | **約 81%** |

映画情報、ソーシャルグラフ、サプライチェーンなど、多種多様な公開 DB スキーマが、Ontographia の Canonical Ontology Model へ安定して変換できることが確認できました。プロパティカバレッジの 19% の未達は、元スキーマテキストの記載揺れや抽出ノイズに起因するものであり、コアエンジンの表現力としては十分な汎用性を示しています。

---

## 5. 仮説 H2 の実証 — 実行フィードバックによる Empty@Valid 回復

[第2部](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design)で解説した「Neo4j の実行結果から Intent を再修復するループ（`--refine-on-exec`）」は実装済みです。仮説 H2 については、ライブ LLM なしの**機械アーム**で Empty@Valid（コンパイルは通るが実行 0 件）からの回復を定量しました。

### 実験条件
* Gold Intent のフィルタ値だけを故意に壊し、`Engine.build` は成功するがモック実行は空になるケースを 40 問用意。
* **no_refine:** 実行フィードバックなし（1 回の空結果で終了）。
* **with_refine:** 空結果を Intent 訂正プロンプトへ戻し、訂正後に再度 `Engine.build`（Cypher 文字列は LLM に触らせない）。
* 対照: 壊していない Gold Intent（余分な refine が走らないこと）。

### 結果（empty-inducing セット）

| 条件 | Empty@Valid | 最終実行 OK | Intent Exact | 回復率 | Cypher = Engine.build |
| :--- | ---: | ---: | ---: | ---: | ---: |
| **no_refine** | 1.00 | 0.00 | 0.00 | 0.00 | 1.00 |
| **with_refine** | 1.00 | **1.00** | **1.00** | **1.00** | 1.00 |

### 判定：仮説 H2 は「支持（Support）」（機械アーム）
* 最終実行成功率が 0 → 1（+100pt）。訂正が成功すれば Empty@Valid から復帰できる。
* すべての出力 Cypher が `Engine.build` と一致（LLM が Cypher を書き換えない不変条件）。

> [!WARNING]
> **Caveat:** このアームは「訂正が正しければループが回復する」ことを示します。ライブ LLM の訂正品質や、実 Neo4j 上の Exec Match は別途の課題です。

再現:
```bash
uv run python examples/llm/eval/run_track_a_h2.py --record
```

実 DB での opt-in 実行例:
```bash
uv run python examples/run_llm_e2e.py \
  --question "Which plant hosts production Line-1?" \
  --execute \
  --refine-on-exec \
  --password ontographia
```

---

## 6. 仮説 H3 の実証 — 難易度適応型コスト配分（Adaptive Spend）

H1 の Subset と H2 の実行フィードバックに加え、「易しい質問ではフルスキーマ／多段 retry を払わない」という **難易度適応型配分**（[#47](https://github.com/edgesentry/ontographia/issues/47)）を実装し、機械アームで定量しました。

### 実験条件
* **always_full_fixed:** 常にフルスキーマ + 固定 `max_retries=5`（コスト上限の対照）。
* **adaptive:** subset-first、`initial_retries=1`；検証失敗時のみフルスキーマへ escalate（`escalated_retries=5`）。
* **easy スライス:** モック抽出器が最初の 1 回で Gold Intent を返す。
* **hard スライス:** subset では意図的に検証失敗させ、full で Gold を返す（escalate の sanity）。

### 結果（large オントロジー）

| スライス | 条件 | Property Hit | Compile | Escalate 率 | 平均 LLM calls | トークン final p95 |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: |
| **easy** | always_full_fixed | 1.00 | 40 / 40 | 0.00 | 1.00 | 13,710 |
| **easy** | adaptive | **1.00** | 40 / 40 | 0.00 | 1.00 | **1,247** |
| **hard** | always_full_fixed | 1.00 | 40 / 40 | 0.00 | 1.00 | 13,710 |
| **hard** | adaptive | **1.00** | 40 / 40 | **1.00** | 2.00 | 13,710 |

### 判定：仮説 H3 は「支持（Support）」（機械アーム）
* easy: トークン p95 を約 **91% 削減**しつつ、Property Hit / Compile を落とさない。
* hard: escalate 率 1.00 でフルへ戻り、コンパイルを回復。

> [!WARNING]
> **Caveat:** モック抽出器によるコスト配分の検証です。ライブ LLM の難易度判定や実モデルの訂正品質は [#68](https://github.com/edgesentry/ontographia/issues/68) など別課題です。

再現:
```bash
uv run python examples/llm/eval/run_track_a_h3.py --record
```

E2E での既定（`--schema-policy auto`）:
```bash
uv run python examples/run_llm_e2e.py \
  --question "Which plant hosts production Line-1?" \
  --schema-policy auto \
  --initial-retries 1 --escalated-retries 5
```

---

## 7. 今後のロードマップ（積み残しと開発計画）

Ontographia は現在も活発に開発が進められています。現時点で明確になっている課題とロードマップは以下の通りです。

| 課題・ロードマップ項目 | 位置づけと目的 |
| :--- | :--- |
| **Track A ライブ LLM アームの計測** | 機械アームだけでなく、実 LLM（GPT-4 等）で Subset / adaptive の効果を再検証する。 |
| **公開 DB 上での実行結果一致（Exec Match）** | Track B の公開 DB 実体に対して、Gold Cypher との実行結果一致率を測定する。 |
| **業務用語マッピングの一般化** | 現場特有の略語や同義語をオントロジー語彙へマッピングするメタデータ層の整備。 |

---

## 8. Ontographia 三部作のまとめ

本連載三部作を通じて、私たちが追求してきた設計哲学を振り返ります。

1. **[第1部：グラフAIのジレンマ](https://zenn.dev/yohei/articles/2026-09-08-ontographia-template-cost)**
   * LLM による Cypher 直接生成は事故の温床であり、手書き固定クエリは硬直する。
   * その妥協案である「テンプレ選定ハイブリッド」は、保守コストを人間へ移転させ、テンプレ枚数爆発で行き詰まる。
   * 必要なのは、柔軟性の単位を「テンプレ枚数」から変えることである。
2. **[第2部：Intent-first の設計と実装](https://zenn.dev/yohei/articles/2026-09-08-ontographia-intent-first-design)**
   * 「LLM は Intent JSON、Cypher の組み立ては決定論的 AST」という厳格な責務分離。
   * オントロジーを唯一の正本とし、パラメータバインディングを構造的に強制する。
   * Neo4j 最新研究（Schema Filtering / Iterative Refinement / Adaptive Spend）を、Cypher レベルではなく Intent 層へ写像して適用する。
3. **第3部：検証結果と今後のロードマップ（本記事）**
   * 大規模オントロジーで発生する「サイレント誤答」を定量的に再現。
   * Exact-match Subset により、トークン消費を **約91% 削減** し、正答率を **+50pt 改善**（仮説 H1 を支持）。
   * 実行フィードバックにより Empty@Valid から Intent を再修復できることを機械アームで支持（仮説 H2）。
   * Adaptive spend により易しい質問のコストを大幅削減しつつ、難問のみ escalate（仮説 H3 を支持）。
   * 公開データへの適合性を実証しつつ、残された課題（ライブ LLM、公開 DB Exec Match）をオープンに共有。

エンタープライズのグラフ AI エージェントにおいて、「安全性」と「スケール（保守性）」は二者択一ではありません。
適切なアーキテクチャ境界とオントロジーの拘束力を持たせることで、その両立は十分に可能です。

Ontographia はオープンソースとしてコードと評価ハーネスをすべて公開しています。ぜひ皆様の現場のオントロジーやグラフでも試してみてください。

* リポジトリ: [github.com/edgesentry/ontographia](https://github.com/edgesentry/ontographia)
* 公式ドキュメント: [edgesentry.github.io/ontographia](https://edgesentry.github.io/ontographia/)

