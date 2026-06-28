---
title: "真マルチモーダルデータ基盤とは何か — 世界モデル研究が Lance を選んだ理由"
emoji: "🗃️"
type: "tech"
topics: ["lancedb", "multimodal", "machinelearning", "datalake", "worldmodel"]
published: false
---

## 概要

マルチモーダル AI を「ベクトル DB に embedding を入れ、画像は object store に置く」と割り切る構成は、デモでは動きますが、**学習・監査・再現** の段階で破綻しやすいです。

本記事（前編）では、最近公開された世界モデル research プラットフォーム [stable-worldmodel](https://arxiv.org/abs/2605.21800)（arXiv:2605.21800）が **なぜ storage 層に Lance を default にしたか** を手がかりに、**真マルチモーダルデータ基盤** が満たすべき条件を整理します。

世界モデルの理論や動画生成の話題は **データが何を要求するか** の説明にとどめ、実装の中心は **Lance フォーマットと I/O** です。LanceDB と DuckDB の役割分担・SQL 連携は [後編](/yohei1126/articles/multimodal-lance-duckdb-query-surfaces) で述べます。

---

## 1. 「embedding DB + object store」だけでは足りない

典型的な分割構成は次のとおりです。

```text
object store … 画像・動画の実体（S3 等）
vector DB    … embedding とメタデータの一部
DWH / SQL    … 売上・マスタ・集計
```

[LanceDB × DuckDB の実践記事](https://www.lancedb.com/blog/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb) が指摘する通り、3系統は **別々の cadence で更新** されます。embedding だけ最新で bytes が古い、ID の結合先が消えている、インデックスが存在しない画像を指している——問題は **クエリ時まで表面化しません**（drift）。

Agentic AI や学習パイプラインでは、次が同時に欲しくなります。

- **同じ行** に structured フィールド、blob、embedding
- **同じ dataset version** で bytes・vec・index が揃っている
- **必要な行・列だけ** をランダムに読める（全ファイル decode 不要）

これを本記事では **真マルチモーダルデータ基盤** と呼びます。製品名ではなく、満たすべき性質の話です。

---

## 2. 世界モデルがデータに求めるもの（ほどほど）

[stable-worldmodel](https://arxiv.org/abs/2605.21800) は世界モデル **アルゴリズムの新提案** というより、研究パイプライン（データ収集・学習・計画・評価）を共通化する OSS です。ここでは **storage 選定の背景** だけ触れます。

### 2.1 世界モデルとは（最小限）

世界モデルは、観測と action から **環境の dynamics（次の状態がどう変わるか）** を学び、それを planning 等に使う predictive model です。動画生成 AI そのものではありません。論文では encoder が観測を潜在状態に、predictor が action 付きで次状態を予測する、という構図で整理されています。

### 2.2 学習データの形

学習には **時系列 trajectory** が要ります。

- 連続するフレーム（または観測）
- 各 step の action
- 場合により proprioception 等

DataLoader は **連続時間ブロック** を取りつつ、**シャッフル可能な random access** も必要です。画像分類の「1ファイル1ラベル」と I/O パターンが違います。

論文 §3.1 の指摘: この要求のせいで **data loading が bottleneck になり GPU が starvation する** — モデル以前の問題、という位置づけです。

---

## 3. MP4 と HDF5 が詰まる理由

論文は trajectory 保存形式として **フレーム単位**、**MP4 動画**、**HDF5**、**Lance** 等を比較しています。構造的なトレードオフは次のとおりです。

| 方式 | 利点 | 問題 |
| :--- | :--- | :--- |
| フレーム画像の羅列 | random access しやすい | ファイルヘッダ decode のオーバーヘッド、容量 |
| MP4 等の動画 | 容量効率が良い | **途中フレーム** のため先頭から decode が必要 |
| HDF5 | 定番の科学計算ストア | ローカルは可も **S3 上で極端に遅い** |

Push-T 環境での **throughput（samples/sec）** は論文 Fig.3 のとおりです。

| Format | local | S3 |
| :--- | ---: | ---: |
| HDF5 | 1,416 | **9** |
| Video (MP4) | 1,331 | — |
| **Lance** | **4,815** | **3,184** |

S3 上の HDF5 が **9 samples/sec** 級であるのに対し、Lance は **3,000 超** — クラウド直読みで学習する設計と相性が良い、という empirics です。MP4 は容量は良くても random access に向きません。

:::message
数値は論文の Push-T 設定に依存します。本質は **「trajectory 向き random access + リモート読み」** の両立が従来形式では難しい、という点です。
:::

---

## 4. なぜ Lance か — 論文と実務が重なる点

stable-worldmodel は Lance を **primary storage** とし、MP4 / HDF5 / [LeRobot](https://github.com/huggingface/lerobot) から **1コマンド変換** も提供します（論文 §3.3）。採用理由を論文記述と実務要件に分解すると次のとおりです。

### 4.1 列指向 + blob 同居

Lance は ML 向け **columnar** フォーマットです。1行（1 sample または 1 product）に、

- 文字列・数値メタデータ
- `large_binary` の **画像/フレーム bytes**
- `list<float32>` の **embedding 列**

を **同じテーブル** に置けます。object store と vector DB を別管理する必要が減り、§1 の drift クラスを避けやすくなります。

### 4.2 random access

trajectory 学習は「episode 内の step 列」を **飛び飛びに** 読みます。動画コンテナのシークより、**列・行単位の部分読み** に向いた設計です。これが §3 の MP4 差の根本です。

### 4.3 versioning と zero-copy evolution

LanceDB 記事が強調する **dataset versioning** は、協調者が「version N の bytes・embedding・index」を再現するのに効きます。embedding 列だけ追加する **zero-copy evolution** も、全再書き込み型 lake との差分になります。

### 4.4 オブジェクトストレージ直読み

論文は S3 からの streaming を前提に benchmark しています。学習前に **全量 sync しない** 運用 — スポット中断や多リージョン実験 — と相性が良い、とブログ・論文双方で述べられています。

### 4.5 LanceDB 共著の位置づけ

論文共著者に LanceDB の ML Engineer が含まれますが、stable-worldmodel の主題は **research 基盤** です。Lance 採用は「製品連携」というより、**WM community が同じ I/O 壁にぶつかっていた** ことへの回答として読むのが正確です（LanceDB ブログでも data layer として紹介されています）。

---

## 5. stable-worldmodel が示すシグナル

論文の主結果の多くは planning 成功率や distribution shift 下の fragility についてです。storage 層に関して読者が持ち帰れるのは次の1点です。

> **最先端の world model research でも、ボトルネックはしばしばモデルではなく I/O だった — だから Lance が default になった。**

LeRobot 等の既存 dataset も swm 経由で Lance に変換可能、と論文は述べています。**研究コミュニティが format を揃え始めた** 信号として、エンタープライズ側のマルチモーダル基盤設計の参考にできます。

世界モデルそのものを本番投入する話は別途、評価プロトコル（論文の Factors of Variation 等）が要ります。本記事のスコープ外です。

---

## 6. 真マルチモーダルデータ基盤 — チェックリスト

実装・設計のレビュー用に、5項目に圧縮します（query 面の詳細は後編）。

1. **同居** — bytes・structured metadata・embedding（必要なら action 列）が **同じ table / version**  
2. **random access** — 学習・検索で **部分 read** でき、動画全体 decode に依存しない  
3. **drift 耐性** — glue で3系統を同期しない  
4. **リモート** — object storage 直読みが現実的な throughput  
5. **query 面** — ML loader と SQL 分析が **同じ Lance ファイル** を参照できる  

vector DB だけ、lake だけ、object store だけでは **1–2 は満たしにくい** 場面が、trajectory 学習で顕在化した — それが stable-worldmodel 論文の storage 章のメッセージです。

---

## Further Reading

- [stable-worldmodel 論文 (arXiv:2605.21800)](https://arxiv.org/abs/2605.21800) / [GitHub](https://github.com/galilai-group/stable-worldmodel)  
- [Make your SQL Workflows Multimodal With LanceDB × DuckDB](https://www.lancedb.com/blog/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb)  
- [Lance format](https://lancedb.github.io/lance/)  

---

## おわりに

マルチモーダル AI のデータ層は、RAG 用 embedding ストアの延長ではありません。**時系列・blob・ベクトル・メタデータが同じ版で読める** ことが、検索だけでなく **学習** でも効いてきます。世界モデル research が Lance を default にしたのは、その要求の過酷な実例に過ぎません。

フォーマットが決まっても、**誰がどうクエリするか** は別問題です。[後編](/yohei1126/articles/multimodal-lance-duckdb-query-surfaces) では、LanceDB と DuckDB が同じ Lance ファイルに対してどう役割分担するか、スキーマ例と SQL まで踏み込みます。
