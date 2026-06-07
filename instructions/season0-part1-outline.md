# Season 0 第1部原案：オントロジーと知識表現の原点（概念編）

## frontmatter（案）

```yaml
title: "知識グラフとオントロジーの源流 - オントロジーと知識表現の原点（概念編）"
emoji: "📖"
type: "tech"
topics: ["ontology", "semanticweb", "knowledgegraph", "rdf", "owl"]
published: false
```

---

## 記事の一行要約

「オントロジー」と聞いて OWL や哲学を思い浮かべる読者に、**古典的オントロジーが何を解こうとしていたか** と **TBox/ABox という整理軸** を渡し、Season 1 以降の「実務的再定義」の前提を作る。

---

## 想定読者

- Season 1 / 2 を読んで「オントロジー再定義」の背景が欲しくなった人
- KG プロジェクトに参画したが、RDF/OWL の用語に馴染みがないデータエンジニア
- 「オントロジー = スキーマ？」と漠然と思っている人

---

## 構成案

### 冒頭 `:::message`（連載案内）

- Season 0 全3部の位置づけ（概念 → 構造 → 現実）
- Season 1・2 へのリンク（**先に Season 1 を読んでもよい** 旨を明記）
- 本記事のコードは **概念例のみ**（実行環境・リポジトリなし。[企画メモ §5](./season0-ontology-kg-series-plan.md#5-サンプルコード方針) 参照）

---

### 概要（300–500字）

- エンタープライズ現場では「オントロジー」がスキーマ、OWL、プロンプト、契約など **多義的** に使われる
- まず **古典的な意味** を整理しないと、Season 1 第3部の再定義も Season 2 の Graph Contract も **何を拡張しているのか** が見えにくい
- 本稿では哲学・知識工学・セマンティック Web に共通する **最小限の概念セット** を地図として提示する

---

### §1. 「オントロジー」という言葉の層

**目的:** 言葉の混線を防ぐ。

1. **哲学的原義** — 存在のカテゴリ、概念の体系（詳述しすぎない）
2. **知識工学・AI での用法** — あるドメインの **概念と関係の形式的記述**
3. **現場での拡張用法（予告）** — スキーマ、制約、Agent Skill、Graph Contract（Season 1/2 で詳述）

**図（案）:** 3層の同心円または積層 — 哲学 ⊃ 知識工学 ⊃ エンタープライズ実務

**避ける:** 哲学史の長い叙述

---

### §2. 知識ベースと TBox / ABox

**目的:** Season 1 以降で「スキーマ vs データ」「辞書 vs 手順」の議論の土台。

| 用語 | 意味 | 例 |
| :--- | :--- | :--- |
| **TBox** | Terminological Box — **用語・概念・関係の定義** | `Component` は部品、`USED_IN` は使用関係 |
| **ABox** | Assertional Box — **具体的事実・インスタンス** | `COMP-103 USED_IN PROD-901` |

- 元ネタ：記述論理（DL）、KL-ONE 系、OWL 界隈の定番整理
- **Open World vs Closed World** を1段落で — RDF/OWL は「知らない ≠ 偽」、RDB/多くの実務 API は closed

**図（案）:**

```
TBox:  Component ──USED_IN──► Product   （型・関係の定義）
ABox:  COMP-103  ──USED_IN──► PROD-901   （具体的事実）
```

**サンプルコード（§2）— Turtle、TBox / ABox 対**

```turtle
@prefix ex:  <http://example.org/bom#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

# --- TBox（用語・関係の定義）---
ex:Component a owl:Class .
ex:Product   a owl:Class .
ex:usedIn a owl:ObjectProperty ;
  rdfs:domain ex:Component ;
  rdfs:range  ex:Product .

# --- ABox（具体的事実）---
ex:COMP-103 a ex:Component ;
  ex:usedIn ex:PROD-901 .
ex:PROD-901 a ex:Product ;
  rdfs:label "製品Y"@ja .
```

**注釈:** 同一形式（Turtle）でも **役割（TBox vs ABox）** が異なることを本文で強調。

---

### §3. 記述論理と「推論して何が分かるか」

**目的:** 「オントロジー = 推論エンジン付き辞書」という印象の正体を示す。

- **記述論理（Description Logic）** — 部分的情報から分類・整合性チェック
- 代表的推論タスク（名称だけ）:
  - **Classification** — 個体がどのクラスに属するか
  - **Realization** — 与えられた型説明を満たすか
  - **Consistency** — 矛盾がないか
- **限界の予告（§5へ）** — 推論は万能ではない。データ品質・更新・例外ルールは別問題

**サンプルコード（§3）— 推論結果のイメージ（擬似テキスト、エンジン実行なし）**

```text
入力 ABox:
  COMP-103 a Component .
  COMP-103 usedIn PROD-901 .
  PROD-901 a Product .

推論器が補完しうるもの（例）:
  COMP-103 usedIn ?x → ?x は Product として分類可能
  （データ品質・更新・例外ルールは推論器の外 → 第3部へ）
```

**避ける:** DL 構文（ALC 等）の詳細

---

### §4. セマンティック Web スタックの地図

**目的:** RDF/OWL/SPARQL を **全体像だけ** 把握させる。

| レイヤ | 技術 | 役割（一行） |
| :--- | :--- | :--- |
| 識別 | URI / IRI | グローバル一意の名前 |
| データモデル | RDF（トリプル） | 主語–述語–目的語 |
| 軽いスキーマ | RDFS | クラス・サブクラス・ドメイン/レンジ |
| 本格オントロジー | OWL | 制約・交差・否定など |
| クエリ | SPARQL | グラフパターンマッチ |

- **トリプル1例** を本文に載せる（製造業の Component 例で Season 2 と語彙を揃える）
- OWL は **TBox 寄り**、インスタンス大量投入は **ABox 寄り**

**サンプルコード（§4）— SPARQL、Where-Used 最小形**

```sparql
PREFIX ex: <http://example.org/bom#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>

SELECT ?product ?label
WHERE {
  ex:COMP-103 ex:usedIn ?product .
  OPTIONAL { ?product rdfs:label ?label }
}
```

**図（案）:** スタック図（下から URI → RDF → RDFS → OWL → SPARQL）

---

### §5. 古典的オントロジーが得意なこと・苦手なこと

**目的:** 第3部・Season 1 への橋。

**得意:**

- 語彙の共有、概念の明示化
- 制約に基づく整合性チェック（TBox レベル）
- 推論可能な構造の記述

**苦手（予告）:**

- 高頻度更新・運用ガバナンス
- 組織間の所有権・セキュリティ
- 分析手順（Playbook）そのもの
- LLM 時代の確率的推論との役割分担

---

### §6. まとめ — 第2部へ

- 古典的オントロジー = **TBox 中心の語彙・制約・（場合により推論）**
- 次回（第2部）では、この概念世界が **知識グラフ実装（RDF 系 vs プロパティグラフ系）** にどう分岐したかを見る
- Season 1 第3部の「再定義」は、この古典から **運用可能な SSOT** へシフトしたもの（詳細は Season 0 第3部）

**連載一覧** — 第1部（本記事）/ 第2部（予定）/ 第3部（予定）

---

## 分量・トーン

- **目標:** 4,000–5,500字
- **トーン:** 教科書よりブログ。用語は初出で括弧英訳
- **コード:** 概念例のみ（[企画メモ §5.3 第1部](./season0-ontology-kg-series-plan.md#53-部別載せるコードと配置)）。共通題材 `COMP-103` / `PROD-901`。Turtle 2ブロック + SPARQL 1 + 擬似テキスト 1。**合計 150行以内**

---

## チェックリスト（執筆後）

- [ ] TBox/ABox を Season 2 第3部 `ontology/` 説明と矛盾なく読めるか
- [ ] 「オントロジー = スキーマ」と読み替えてしまう読者への注意があるか
- [ ] Season 1 を先に読んだ人が「やっと繋がった」と感じるか
- [ ] §2 Turtle で TBox/ABox の **役割の違い** がコード上も分かるか
- [ ] SPARQL 例が第2部 Cypher 例と **同じ問い** の前提になっているか
