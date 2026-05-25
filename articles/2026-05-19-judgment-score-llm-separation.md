---
title: "判断の説明 — スコアはバッチで固定し、グラフとLLMは根拠とナレーションだけを担う"
emoji: "🧭"
type: "tech"
topics: ["llm", "graphrag", "explainability", "duckdb", "oss"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## 概要

2026年、シンガポール国防省（MINDEF）の Future Systems & Technology Directorate とフランス AMIAD が共同で開いている **[CAP Vista AI Joint Challenge](https://accelerator.capvista.com.sg/en/challenges/ai-joint-challenge)**（応募締切 2026年6月8日）に、筆者は **Challenge 1: Anomaly Detection in Complex Datasets** として提案 **Arktrace Explainable OSINT** を出している。

このチャレンジが求めるのは、大規模・多ソースのデータから **異常を検出**し、かつアナリストが **信頼して行動できる説明（explainability）** を伴うことだ。行動分析や意図に近いシグナル、ネットワークとしての不審な連携——海上ドメインでは AIS・制裁リスト・ニュース OSINT などが典型例になる。筆者が直面したのは、「精度の高いランキング」だけでは足りず、**なぜこの船舶か**を監査可能な形で示さないと採用されない、という要件だった。

そこで [EdgeSentry](https://github.com/edgesentry) として、次の OSS スタックを **設計・実装し、公開**した。

| 役割 | リポジトリ | 概要 |
|------|------------|------|
| バッチ異常検知・スコア固定 | [indago](https://github.com/edgesentry/indago) | ingest → 特徴量 → グラフ → スコア → ウォッチリストを Parquet で publish |
| 分析 UI（検出はしない） | [arktrace](https://github.com/edgesentry/arktrace) | DuckDB-WASM で artefact を読み、SHAP・`ownership_chain` を表示 |
| 説明（ナレーション） | [edgesentry-explain](https://github.com/edgesentry/edgesentry-rs/tree/main/crates/edgesentry-explain) | 確定スコアと根拠だけを入力にローカル LLM で brief（[edgesentry-rs](https://github.com/edgesentry/edgesentry-rs)） |

**スコアリングと説明は API 境界で分離**する。バッチだけが順位を決め、UI と LLM は publish 済みデータを読むだけ——LLM が confidence を書き換える経路は意図的に持たない。提出用デモの流れは、ウォッチリスト → SHAP → ownership chain → Analyst brief（Regenerate）の順を想定している。

これは、シンガポール政府側がチャレンジ文書で重視する **説明可能な AI（explainable AI）** の姿に、筆者の理解では近い。いわゆる「LLM に理由を書かせれば説明可能」ではなく、**判断（スコア）と説明（根拠データ・文章）が別プロセス**であり、主権・オンプレでも回るバッチ判断を土台にする、という立場だ。同じ原則は、同チャレンジの **Challenge 2（SWaP）** で別途出している [clarus](https://github.com/edgesentry/clarus) エッジ監視にも通じる。以前の [CAP Vista Accelerator Solicitation 5.0](https://zenn.dev/yohei/articles/2026-05-24-cap-vista-accelerator-solicitation-5-0)（未採択）から、C1 向けに「異常＋説明＋主権バッチ」へ reframing した経緯もある。

**本記事の目的**は、その応募ソリューションを支える **説明可能 AI の概念**（一般の XAI との違い、どこを対象にするか）と、**実装する際の勘所**（三層アーキテクチャ、アンチパターン、チェックリスト）を、調達文書を開かなくても追える形で書くことだ。チャレンジ要件の読み方（実装なし）は別稿 → [政府調達で説明可能AIが求められるとき — CAP Vista チャレンジを具体例に読む](https://zenn.dev/yohei/articles/2026-05-25-cap-vista-xai-requirements)。判断の再現性・証跡は、シリーズの前後稿で扱う。

- 前: [判断の再現性](https://zenn.dev/yohei/articles/2026-05-19-reproducible-judgment-metrics)  
- 次: [判断の証跡](https://zenn.dev/yohei/articles/2026-05-19-tamper-evident-judgment-audit-chain)

---

## 説明可能 AI とは何か

**説明可能 AI（Explainable AI / XAI）** は、AI の出力について **「なぜそうなったか」を人間が追い、責任を持てるようにする**考え方・手法の総称です。一つの製品機能名ではなく、だいたい次の問いの束です。

| 問い | 例 |
|------|-----|
| **解釈（interpretability）** | どの入力・特徴が効いたか（SHAP、重要度） |
| **事後説明（post-hoc explanation）** | 判定後に根拠を示す（パス、類似事例） |
| **透明性（transparency）** | ルール・パイプライン・データ lineage が見える |
| **説明責任（accountability）** | 誰が・いつ・何を根拠に判断したか、再実行できるか |

LLM ブーム以降、「説明可能 AI」＝**プロンプトで根拠段落を書かせるアプリ**と混同されがちです。それだけだと、文章は毎回変わりうるし、**スコア自体が LLM の出力**になりうる——監査やオンプレ運用では、再現性と責任の所在が曖昧になります。

---

## 本記事がターゲットにする範囲

XAI 全体の教科書ではなく、**運用・監査向けの次の切り口だけ**を対象にします。

| 対象にする | 対象にしない（本記事の外） |
|------------|---------------------------|
| 判断（スコア・ランク）と説明（根拠・文章）の **プロセス分離** | 深層学習の内部表現を一般論で解く研究 |
| バッチで固定した判断 ＋ 構造化根拠 ＋ LLM はナレーションのみ | Graph RAG で **検索とスコアを一体化**するデモ |
| 主権・オフライン（クラウド LLM 必須にしない説明） | 「プロンプトを工夫すれば説明可能」という狭い意味だけ |

| 記事の層 | XAI のどれに近いか |
|----------|-------------------|
| レイヤ1 — 決定的スコア（indago バッチ） | 透明性・再現性・説明責任の「判断」そのもの |
| レイヤ2 — グラフパス・SHAP | 解釈可能性・事後説明の機械可読な根拠 |
| レイヤ3 — ローカル LLM brief | 人間向けナレーション（判断の代わりではない） |

---

## なぜ「判断と説明の分離」か

チャレンジ要件を実装に落とすとき、次の三場面が重なる。

| 場面 | 欲しいもの | LLM だけでは足りない理由 |
|------|------------|-------------------------|
| アナリスト | 「なぜこのエンティティか」 | ナレーションは再現不能になりうる |
| 監査・法務 | 根拠データへのトレース | ハルシネーションがスコアに波及すると致命的 |
| 運用 | オフライン・主権バッチ | クラウド API 必須の説明はデプロイできない |

海上 OSINT（制裁・シャドウフリート）では誤報のコストが大きく、**ネットワーク説明**（所有関係の多ホップ）がスカラーだけでは足りない。だから後述の三層——バッチ判断、構造化根拠、ローカル LLM ナレーション——に分けた。

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

公開データから所有関係のシードを CSV で取り込み、CI でグラフエッジを生成する運用をしています。publish 後のウォッチリストには、多ホップの `ownership_chain` のような JSON が載ることがあり、**アナリストが Parquet からパスを再計算できる**形です。

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

アナリストワークフローでは、10 分のブリーフィング準備のように、**人間が承認する前段の下書き**として LLM を置くイメージです。

---

## エッジ側との対称性（clarus）

同じ分離は、リアルタイムの [clarus](https://github.com/edgesentry/clarus) / [edgesentry-rs](https://github.com/edgesentry/edgesentry-rs) にもあります。Rust の物理・ルールエンジンがリスクを決め、LLM は規制引用の自然言語化だけを担います。

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
