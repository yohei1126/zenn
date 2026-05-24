---
title: "判断の説明 — スコアはバッチで固定し、グラフとLLMは根拠とナレーションだけを担う"
emoji: "🧭"
type: "tech"
topics: ["llm", "graphrag", "explainability", "duckdb", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

「説明可能 AI」と聞くと、プロンプトで根拠を書かせる LLM アプリを想像しがちです。しかし監査やオンプレ運用では、**スコアそのものが LLM の出力に依存している**時点で、再現性と責任の所在が曖昧になります。

筆者は [EdgeSentry](https://github.com/edgesentry) で、バッチ異常検知 [indago](https://github.com/edgesentry/indago)、分析 UI [arktrace](https://github.com/edgesentry/arktrace)、説明クレート [edgesentry-explain](https://github.com/edgesentry/edgesentry-rs/tree/main/crates/edgesentry-explain)（[edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) ワークスペース内）を組み合わせ、**スコアリングと説明を API 境界で分離**しています。本記事はその設計を、特定の公募や顧客要件なしに読める形でまとめます。

---

## 背景：説明可能さが欲しい3つの場面

| 場面 | 欲しいもの | LLM だけでは足りない理由 |
|------|------------|-------------------------|
| アナリスト | 「なぜこのエンティティか」 | ナレーションは再現不能になりうる |
| 監査・法務 | 根拠データへのトレース | ハルシネーションがスコアに波及すると致命的 |
| 運用 | オフライン・主権バッチ | クラウド API 必須の説明はデプロイできない |

共通する要件は、**判断（スコア・ランク）と説明（根拠・文章）が別プロセスであること**です。

---

## アーキテクチャの要点

```text
┌─────────────────────────────────────────────────────────┐
│  BATCH（indago）— ここだけが「何が異常か」を決める       │
│  ingest → 特徴量 → グラフ → 異常スコア → ウォッチリスト   │
│  出力: Parquet / Lance、決定的な数値と順位               │
└───────────────────────────┬─────────────────────────────┘
                            │ publish (R2 等)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  READ（arktrace）— 検出はしない、読むだけ                 │
│  DuckDB-WASM で Parquet をクエリ、SHAP・パスを可視化      │
└───────────────────────────┬─────────────────────────────┘
                            │ 任意・下流
                            ▼
┌─────────────────────────────────────────────────────────┐
│  EXPLAIN（edgesentry-explain）— ナレーションのみ         │
│  ローカル LLM（llama.cpp）で brief・引用文を生成          │
│  スコアは入力として読むが、書き換えない                   │
└─────────────────────────────────────────────────────────┘
```

**ルール:** batch がスコアを決める。LLM は説明だけ。

---

## レイヤ1 — 決定的スコア（バッチ）

異常検知パイプラインでは、例えば次のような **再実行可能な** 成分を組み合わせます。

- **行動特徴** — 時系列ウィンドウ上の AIS 的パターン（ギャップ、速度、寄港など）
- **グラフリスク** — 制裁エンティティへの近接、所有・管理関係のホップ数
- **合成スコア** — 各成分に重みを付けた信頼度（グラフ成分が一定割合を占める、など）

スコアリングの実装は indago 側にあり、学習済みモデル（例: Isolation Forest）とルールベースのグラフスコアの両方が **同じ publish run** の artefact として固定されます。UI や LLM を触っても、**すでに publish されたウォッチリストの順位は変わりません**。

---

## レイヤ2 — 構造化された根拠（グラフ・SHAP）

LLM に「なぜ？」と聞く前に、**機械可読な根拠**を残します。

### グラフパス（Knowledge Graph）

公開データから所有関係のシードを CSV で取り込み、CI でグラフエッジを生成する運用をしています（[ref-knowledge-graph.md](https://github.com/edgesentry/indago/blob/main/docs/ref-knowledge-graph.md)）。publish 後のウォッチリストには、多ホップの `ownership_chain` のような JSON が載ることがあり、**アナリストが Parquet からパスを再計算できる**形です。

これは Neo4j クラスタを常時立てるのではなく、**Lance / 埋め込みグラフ + バッチ書き出し**で足りるケースの一例です。筆者の過去の Zenn 記事で扱った Graph RAG の「概念編」との違いは、**スコアに効くグラフと、説明用のパスが同じデータ契約にある**点です。

### 特徴分解（SHAP 等）

「どの特徴がランクを押し上げたか」は、モデルが支援する場合は SHAP や類似の分解で UI に出します。ここも **数値はバッチ出力のフィールド**であり、LLM が後から捏造するものではありません。

---

## レイヤ3 — ナレーション（ローカル LLM）

[edgesentry-explain](https://github.com/edgesentry/edgesentry-rs/tree/main/crates/edgesentry-explain) は、確定したスコアと構造化根拠を入力に、**人間向けの brief** を生成します。実行は llama.cpp 等の **ローカル推論**を想定しており、データをクラウド API に送る必要はありません。

| やること | やらないこと |
|----------|--------------|
| ウォッチリストの要約 | ランクの再計算 |
| 規制・事件への引用文ドラフト | スコア閾値の変更 |
| アナリストの調査メモ下書き | グラフエッジの追加 |

アナリストワークフローの設計メモは [arktrace の osint-workflow-design](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/arktrace/analysis/osint-workflow-design.md)（commercial リポジトリ）にあります。10 分のブリーフィング準備のように、**人間が承認する前段の下書き**として LLM を置くイメージです。

---

## エッジ側との対称性（clarus）

同じ分離は、リアルタイムの [clarus](https://github.com/edgesentry/clarus) / [edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) にもあります。Rust の物理・ルールエンジンがリスクを決め、LLM は規制引用の自然言語化だけを担います（[architecture-core.md](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/products/clarus/analysis/architecture-core.md)）。

バッチ OSINT とエッジ安全監視はドメインが違っても、**「判断エンジン」と「説明エンジン」は別バイナリ・別デプロイ単位**という原則は共通です。

---

## よくあるアンチパターン

1. **RAG がスコアも返す** — 検索結果の揺れがランキングに直結する  
2. **プロンプトに「confidence: 0.87」と書かせる** — 監査で無効  
3. **フロントエンドで再スコア** — publish と UI の不一致  
4. **説明のためにだけクラウド LLM 必須** — 主権要件でデプロイ不可  

---

## 実装チェックリスト

- [ ] スコア・ランクを変更するコードはバッチ（またはエッジエンジン）だけにある  
- [ ] UI は publish 済み artefact の読み取り専用  
- [ ] グラフパス・SHAP は Parquet / JSON フィールドとして保存  
- [ ] LLM 出力には「下書き」「要人手承認」のラベル  
- [ ] 説明用 LLM はオフライン実行可能（llama.cpp 等）  

---

## まとめ

説明可能さは、プロンプトの巧みさではなく **責務の分離**で担保できます。batch が判断し、構造化データが根拠を運び、LLM はその上にナレーションを載せるだけ——この三層にすると、Graph RAG やオンプレ LLM の議論が「きれいなデモ」で終わらず、運用と監査に耐える形になります。

前の記事 [判断の再現性](https://zenn.dev/yohei/articles/2026-05-19-reproducible-judgment-metrics) ではメトリクス artefact、次の記事 [判断の証跡](https://zenn.dev/yohei/articles/2026-05-19-tamper-evident-judgment-audit-chain) では暗号連鎖と verify を扱います。

---

## 参考リンク

- [indago](https://github.com/edgesentry/indago) — バッチスコアリング・グラフ  
- [arktrace](https://github.com/edgesentry/arktrace) — DuckDB-WASM 分析 UI  
- [edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) — 監査・説明・ルールエンジン共通ライブラリ  
- [ref-knowledge-graph.md](https://github.com/edgesentry/indago/blob/main/docs/ref-knowledge-graph.md) — グラフシードと publish 後のパス
