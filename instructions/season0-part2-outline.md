# Season 0 第2部原案：知識グラフの二つの系譜（構造編）

## frontmatter（案）

```yaml
title: "知識グラフとオントロジーの源流 - 知識グラフの二つの系譜（構造編）"
emoji: "🕸️"
type: "tech"
topics: ["knowledgegraph", "rdf", "neo4j", "propertygraph", "semanticweb"]
published: false
```

---

## 記事の一行要約

「知識グラフ」と呼ばれるものが **RDF/セマンティック Web 系** と **プロパティグラフ（LPG）系** に分かれる理由を整理し、スキーマ・ traversals ・オープンワールド仮定の違いを説明する。

---

## 想定読者

- Season 0 第1部を読んだ人（または TBox/ABox をなんとなく知っている人）
- Neo4j だけ触って RDF が見えない、またはその逆の人
- Season 1 の「仮想グラフ」と Season 2 の「Neo4j マルチDB」の **位置づけ** を知りたい人

---

## 構成案

### 冒頭 `:::message`

- 第1部からの続き
- 本稿も **製品比較・本番実装なし**（概念例コードあり。[企画メモ §5](./season0-ontology-kg-series-plan.md#5-サンプルコード方針) 参照）

---

### 概要

- 第1部の TBox/ABox を **「どう物理化・API化するか」** の話に進める
- 業界では「KG」が1語で **思想の異なる2系統** を指すことがある
- この分岐を理解しないと、Season 1 の仮想グラフ（DWH ビュー）と Season 2 の Neo4j 実装の **選定理由** が見えにくい

---

### §1. 知識グラフとは何か（最小定義）

**定義案:**

> エンティティをノード、関係をエッジ（またはトリプル）としてモデル化し、**関係性を traversals や推論の対象** にするデータ表現。

- RDB との差 — JOIN/再帰 vs パス探索の自然さ（Season 2 第1部 §4.2 と整合）
- **KG ≠ 必ず OWL** — グラフ構造を持てば KG と呼ばれることもある（曖昧さを認める）

---

### §2. RDF 系：トリプルとセマンティック Web

**要点:**

- すべてが `(subject, predicate, object)` — **細粒度・交換可能**
- **オープンワールド仮定（OWA）** — 未記述 ≠ 否定
- スキーマは **後から足せる**（RDFS/OWL は TBox 層）
- 推論・リンクドデータ・公開語彙（schema.org 等）
- クエリ：**SPARQL**

**長所 / 短所（各3 bullet）**

**図（案）:** トリプル集合 → グラフビュー

**サンプルコード（§2 vs §4）— SPARQL、第1部と同じ問い**

```sparql
PREFIX ex: <http://example.org/bom#>
SELECT ?product WHERE {
  ex:COMP-103 ex:usedIn ?product .
}
```

---

### §3. プロパティグラフ（LPG）系：ラベルとエッジ型

**要点:**

- ノード **ラベル**、エッジ **型** — アプリ開発者に馴染みやすい
- **クローズドワールド** に近い運用が多い（スキーマレス DB でもアプリ層で制約）
- traversals / 最短経路 / パターンマッチ — **Cypher**, **GQL**（名称だけ）
- 代表例：Neo4j、Neptune（LPG モード）等 — **製品深掘りはしない**

**長所 / 短所（各3 bullet）**

**図（案）:** `(Component:COMP-103)-[:USED_IN]->(Product:PROD-901)`

**サンプルコード（§3 vs §4）— Cypher、SPARQL と並置**

```cypher
MATCH (c:Component {id: 'COMP-103'})-[:USED_IN]->(p:Product)
RETURN p.id AS product
```

**注釈:** Season 2 の `Component.id` Bridge Key は LPG 側 `{id: ...}` に近い、と1文。

---

### §4. 二系譜の対照表

| 観点 | RDF / セマンティック Web 系 | プロパティグラフ（LPG）系 |
| :--- | :--- | :--- |
| 原子単位 | トリプル | ラベル付きノード・型付きエッジ |
| スキーマ | RDFS/OWL（TBox）、後付け可能 | ラベル/型、DB またはアプリで強制 |
| 世界仮定 | オープンがデフォルト | クローズドに近い運用が多い |
| クエリ | SPARQL | Cypher / GQL |
| 典型用途 | 公開語彙、統合、推論 | アプリグラフ、分析、エージェント traversals |
| Season 接続 | 仮想グラフ（論理ビュー）の思想 | Season 1 物理グラフ / Season 2 Neo4j |

---

### §5. 「仮想グラフ」と物理グラフ — Season 1 への橋

**目的:** Season 1 第1部を **構造編の帰結** として位置づける。

- **仮想グラフ** — 単一 DWH 上の **論理ビュー統合**（物理コピーなし）
- **物理グラフ DB** — traversals 性能・専用モデル（Season 1 第3部）
- どちらも **1つの統治境界** を前提 — Season 2 の「組織分断」とは **前提が異なる**（第3部で詳述）

**1段落:** Snowflake/Databricks/Google の名前は **例示のみ**、詳細は Season 1

**サンプルコード（§5）— SQL、仮想グラフの最小イメージ（1例のみ）**

```sql
CREATE VIEW graph_used_in AS
SELECT c.component_id, p.product_id
FROM components c
JOIN product_bom b ON c.component_id = b.component_id
JOIN products p ON b.product_id = p.product_id;
```

---

### §6. スキーマレス、スキーマ強制、データ契約

**目的:** Season 1 第3部・Season 2 Graph Contract への橋。

| 概念 | 位置づけ |
| :--- | :--- |
| **スキーマレス（DB）** | 柔軟だが変更管理が地獄（Season 1 第3部 §2） |
| **アプリ層スキーマ強制** | Pydantic 等 = TBox 寄りの厳格層 |
| **データ契約 / Graph Contract** | 組織間・フェデレーションの約束（Season 2） |

**`:::message` 案 — TBox vs Playbook（初出）**

- **TBox 寄り:** 何が存在しうるか（型・接続ルール）
- **Playbook 寄り:** どう使うか（分析手順、探索テンプレート、Skill 説明）
- Season 1 は両方を SSOT に含めた再定義 → Season 2 で Playbook/契約が **Graph Contract として独立** しやすい、と予告

**サンプルコード（§6）— YAML、TBox vs Playbook 対**

```yaml
# TBox 寄り: 存在してよいエッジ
allowed_edges:
  USED_IN:     [Component, Product]
  SUPPLIED_BY: [Component, Supplier]
  PRODUCED_BY: [Product, Process]
```

```yaml
# Playbook 寄り: 分析手順（概念のみ）
steps:
  - domain: sourcing
    query: supplier_to_components
    output: component_ids
  - domain: ebom
    query: components_to_products
    input: component_ids
  - domain: routing
    query: products_to_processes
    input: product_ids
```

---

### §7. まとめ — 第3部へ

- KG は **1つの技術** ではなく **2つの文化圏** が主流
- Season 1 は主に **LPG + アプリ層 SSOT**、Season 2 は **組織境界 + 契約**
- 次回（第3部）— 古典・KG 文化が **エンタープライズ現場と LLM 時代** でなぜ限界に達するか

---

## 分量・トーン

- **目標:** 4,500–6,000字
- **図:** 対照表 + トリプル/LPG 各1図 + スタックとの関係1図
- **コード:** 概念例のみ（[企画メモ §5.3 第2部](./season0-ontology-kg-series-plan.md#53-部別載せるコードと配置)）。SPARQL + Cypher 並置、SQL 1、YAML 2。**合計 200行以内**

---

## チェックリスト

- [ ] RDF 系を貶しすぎず、LPG 系を正と読ませすぎないか
- [ ] Season 1 仮想グラフ記事との **重複段落** を避け、リンクで委譲しているか
- [ ] TBox vs Playbook が Season 2 Graph Contract 説明の伏線になっているか
- [ ] SPARQL / Cypher が **同一問い**（`COMP-103` → 親製品）で並置されているか
- [ ] §6 YAML で TBox（`allowed_edges`）と Playbook（`steps`）が視覚的に分離されているか
