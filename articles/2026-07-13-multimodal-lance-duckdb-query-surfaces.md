---
title: "同じ Lance ファイルを LanceDB と DuckDB で使う — 真マルチモーダルの query 面"
emoji: "🦆"
type: "tech"
topics: ["lancedb", "duckdb", "multimodal", "sql", "datalake"]
published: false
---

## 概要

[前編](/yohei1126/articles/multimodal-data-foundation-lance-duckdb) では、世界モデル research が **なぜ Lance を storage default にしたか** — bytes・metadata・embedding の同居、random access、S3 直読み — を整理しました。

本記事（後編）の焦点は **query 面** です。Lance **フォーマット** は1つでも、それを包む **エンジン** は用途で分かれます。

DuckDB 側は **`lance` extension**（2026年3月以降 **core extension**）が Lance テーブルの read/write、vector / FTS / hybrid search、namespace `ATTACH` を SQL から提供します。実装は [lance-format/lance-duckdb](https://github.com/lance-format/lance-duckdb) です。いわゆる「プラグイン」に相当しますが、DuckDB の用語では **extension** です。

**LanceDB**（検索・ML loader）と **DuckDB + `lance` extension**（分析 SQL・JOIN）が **同じ Lance ファイル** を参照する構成を、[公式ブログ](https://www.lancedb.com/blog/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb) をベースに実装者向けにまとめます。

---

## 1. 前編のおさらい — なぜ query 面まで設計するか

前編のチェックリスト第5項は **「ML loader と SQL 分析が同じ Lance ファイルを参照できる」** でした。

典型的な分割構成（object store + vector DB + DWH）では、分析担当が SQL で JOIN したい列と、学習パイプラインが DataLoader で読む bytes が **別系統** に残ります。Lance に **1行同居** させても、クエリ API が1種類だけだと **半分の利用者** が再び glue を書き始めます。

```text
同じ Lance dataset
  ├─ LanceDB … ANN / FTS / hybrid、PyTorch DataLoader
  └─ DuckDB    … 集計・JOIN・lance_vector_search() を SQL で
```

競合ではなく **同じファイルに対する異なる query 面**、と捉えるのが要点です。

---

## 2. 3層の役割分担

| 層 | 役割 | 典型操作 |
| :--- | :--- | :--- |
| **Lance（format）** | bytes + metadata + vec の同居・版 | 部分 read、S3 直読み |
| **LanceDB** | 組み込み/サーバーレス、vector / FTS / hybrid | ANN search、PyTorch DataLoader |
| **DuckDB + `lance` extension** | 分析 SQL、JOIN | `INSTALL lance` / `ATTACH ... TYPE LANCE`、`lance_vector_search()` |

**Lance** は「何をどう格納するか」。**LanceDB** は「アプリや学習がどう取り出すか」。**DuckDB** は「データサイエンス・BI が SQL でどう触るか」——と覚えると混乱しにくいです。

エッジの Agent アプリでは LanceDB 単体、検証・レポートでは DuckDB、**重い ML 学習** では Lance ネイティブ loader — という分担が自然です。重要なのは **中身のファイル形式が1つ** であることです。

---

## 3. DuckDB × Lance — ブログが示す5つの要点

[LanceDB × DuckDB の実践記事](https://www.lancedb.com/blog/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb) が強調するポイントを、実装順に並べます。

### 3.1 namespace で Lance catalog を ATTACH

パスを毎回直書きするより、**catalog 単位で ATTACH** する方が運用しやすい、とブログは述べています。

```sql
INSTALL lance;
LOAD lance;
ATTACH './catalog' AS cat (TYPE LANCE);
```

以降、`cat.main.products` のように **通常の SQL テーブル** として参照できます。

### 3.2 構造化列 + image_bytes を同じ SELECT

embedding 専用 DB では vec だけ返り、画像は別 fetch、という流れがよくあります。Lance 上では **`image_bytes` を SELECT** でき、object store への追加リクエストを減らせます。

```sql
SELECT item_id, title, brand
FROM cat.main.products
LIMIT 5;
```

### 3.3 `lance_vector_search()` — 検索結果を SQL リレーションに

top-k ベクトル検索の結果を **通常の SQL リレーション** として扱えます。サブクエリや CTE に載せ、後段でフィルタ・集計できます。

```sql
SELECT *
FROM lance_vector_search(
  cat.main.products,
  query_vector => [0.1, 0.2, /* ... */],
  limit => 10
);
```

（引数名・型は extension バージョンに依存します。最新の [DuckDB `lance` extension ドキュメント](https://duckdb.org/docs/lts/core_extensions/lance.html) を参照してください。）

### 3.4 他 DuckDB テーブルと JOIN

意味検索でヒットした `item_id` を、売上マスタや在庫テーブルと **同じクエリ内** で JOIN できます。前編で述べた **drift** — vec DB の ID と DWH の行がずれる — を、クエリ設計段階で抑えやすくなります。

```sql
SELECT p.item_id, p.title, s.revenue_30d
FROM lance_vector_search(cat.main.products, /* ... */) AS hits
JOIN sales_summary AS s USING (item_id);
```

### 3.5 結果を Lance に materialize

DuckDB は read-only の統合レイヤーにとどまりません。フィルタ・JOIN・集計した結果を **新しい Lance dataset として書き戻す** ことも、ブログのワークフローに含まれます。分析 → 特徴量テーブル → 再学習、というループが **同じフォーマット** のまま回せます。

---

## 4. LanceDB 側でやること — 検索と ML loader

DuckDB が SQL 面を担う一方、次は **LanceDB** の領域です。

| 用途 | LanceDB | DuckDB |
| :--- | :---: | :---: |
| 低レイテンシ ANN / hybrid search | ◎ | △（SQL 経由） |
| 組み込み（エッジ・サーバーレス） | ◎ | △ |
| PyTorch / JAX DataLoader | ◎ | — |
| 売上・マスタとの JOIN 分析 | △ | ◎ |
| ad hoc SQL・BI 連携 | △ | ◎ |

LanceDB は **インデックス更新**（vector / FTS）や **API サーバ** に向いています。trajectory 学習では Lance ネイティブの batch read が主役になり、カタログ検索では LanceDB の hybrid query が主役になる—— **同じファイル、別の入口** です。

:::message
本記事は DuckDB 連携を厚めに書いていますが、LanceDB 単体で完結する RAG / Agent アプリも多数あります。必要な query 面だけ選べばよく、**両方使うのは「検索も SQL も本番で要る」場合** の典型パターンです。
:::

---

## 5. 1行が持つべき列 — 2つのスキーマ例

フォーマットが同じでも、**行の意味** はドメインで変わります。前編の「真マルチモーダル」条件を、具体例に落とします。

### 5.1 カタログ型（検索 + 分析）

DuckDB 記事の product catalog に近い形です。LanceDB で hybrid search、DuckDB で売上 JOIN、という分担がそのまま効きます。

```text
item_id, title, brand, category, price,
image_bytes, fts_text, multimodal_vec, text_vec
```

- **LanceDB**: `multimodal_vec` / `text_vec` で検索、`fts_text` で hybrid  
- **DuckDB**: `brand`・`category` で集計、`image_bytes` をレポート用に抽出  

### 5.2 trajectory 型（世界モデル学習）

[stable-worldmodel](https://arxiv.org/abs/2605.21800) が collect する Lance dataset のイメージです。こちらは **Lance ネイティブ loader + LanceDB** が中心で、DuckDB は **episode 統計・品質監査** に使う場面が多いです。

```text
episode_id, step, timestamp,
observation_bytes,   -- または frame_ref
action, reward, done, …
```

どちらも **「モダリティごとに別ストア」にしない** 点が共通です。スキーマはドメイン依存ですが、**同居・版・random access** の条件は同じです。

---

## 6. 設計レビュー — query 面のチェックリスト

前編の5項目に、後編用の3項目を足します。

6. **入口の明示** — 学習・検索・分析それぞれが **どの engine** 経由で Lance を読むか決まっている  
7. **JOIN の単一ソース** — 意味検索の ID と分析マスタが **同じ version の Lance 行** を指せる  
8. **書き戻し** — 分析結果を別 Parquet に逃がさず、必要なら **Lance に materialize** する道がある  

---

## Further Reading

- [前編: 真マルチモーダルデータ基盤とは何か](/yohei1126/articles/multimodal-data-foundation-lance-duckdb)  
- [Make your SQL Workflows Multimodal With LanceDB × DuckDB](https://www.lancedb.com/blog/make-your-sql-workflows-multimodal-with-lancedb-x-duckdb)  
- [DuckDB `lance` core extension](https://duckdb.org/docs/lts/core_extensions/lance.html) / [lance-duckdb repo](https://github.com/lance-format/lance-duckdb)  
- [Lance format](https://lancedb.github.io/lance/)  
- [stable-worldmodel 論文 (arXiv:2605.21800)](https://arxiv.org/abs/2605.21800)  

---

## おわりに

真マルチモーダル基盤は **フォーマット選びで終わりません**。bytes と vec が同じ Lance 行にあっても、分析担当が SQL で触れなければ、再び DWH と object store の **3系統 glue** に戻ります。

LanceDB と DuckDB は **同じ Lance ファイルに対する異なる query 面** です。前編で論文が示した I/O 要件を満たしたうえで、組織内の **検索・学習・分析** が同じ dataset version を参照できるか——そこまで設計して初めて、前編のチェックリストは揃います。
