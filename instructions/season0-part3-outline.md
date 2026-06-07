# Season 0 第3部原案：推論・統合・運用の限界（現実編）

## frontmatter（案）

```yaml
title: "知識グラフとオントロジーの源流 - 推論・統合・運用の限界（現実編）"
emoji: "⚖️"
type: "tech"
topics: ["ontology", "knowledgegraph", "llm", "semanticweb", "enterprise"]
published: false
```

---

## 記事の一行要約

古典的オントロジーと KG が **企業現場・LLM 時代** で直面する限界を整理し、Season 1 の「オントロジー再定義」と Season 2 の「Graph Contract」が **なぜ必要か** を3段階マップで締める。

---

## 想定読者

- Season 0 第1–2部を読んだ人
- Season 1/2 を先に読み、「用語の整理」だけ欲しい人（**本章単体でも成立** させる）

---

## 構成案

### 冒頭 `:::message`

- Season 0 最終章
- 本稿読了後の推奨ルート → **Season 1 第1部** へ
- コードは **3段階進化の縦並び** を中心に載せる（[企画メモ §5](./season0-ontology-kg-series-plan.md#5-サンプルコード方針) 参照）

---

### 概要

- 第1部：古典の **理想**
- 第2部：実装文化の **分岐**
- 第3部：エンタープライズと AI エージェントの **現実** — だから Season 1/2 の pragmatic 路線へ

---

### §1. ビッグバン統合オントロジーの罠

**Season 1 第3部 §1② との接続（要約 + リンク）**

- 「全社知識を1枚の KG に」 — スコープ不明瞭、保守不能
- 4条件（コアビジネス直結、課題明確、ドメインエキスパート、グラフ必然性）を **表で再掲**（詳細は Season 1 へ委譲）
- **局所的成功 → ゆるやかな連動 → エージェント**（Season 1 第3部 §3 の mermaid を **簡略参照**）

---

### §2. 推論だけでは足りない — データと組織の現実

**古典推論 vs 運用要件**

| 古典 DL/OWL が想定しやすい | エンタープライズが要求する |
| :--- | :--- |
| TBox の整合性 | 更新頻度・SLA・鮮度 |
| ABox の分類 | 部門別所有権・書き込み権限 |
| 公開語彙 | 機密データ・行レベルセキュリティ |
| 完璧な ABox | 参照整合性の非同期監査 |

- Season 2 第1部「組織分断」の **動機を概念レベルで先出し**（詳細は Season 2 第1部へ）

**サンプルコード（§2）— Turtle、参照整合性の欠落例**

```turtle
@prefix ex: <http://example.org/bom#> .

# sourcing 側 ABox にだけ存在（ebom マスタに COMP-999 なし）
ex:COMP-999 ex:suppliedBy ex:SUP-001 .
```

**注釈:** 古典推論 vs 「他ドメインにも存在すべき」は別問題 → Season 2 非同期監査へ。

---

### §3. LLM 時代の再配置 — 記号推論と確率推論

**Season 1/2 共通テーマの統合**

- **記号AI（ルール・オントロジー・決定論的クエリ）** — 正確、保守コスト
- **LLM（統計的推論）** — 柔軟、ハルシネーション
- Text-to-SPARQL / Text-to-Cypher の限界（Season 1 第3部 §1③、Season 2 第1部 §5）
- **ツール境界** — LLM は Plan、実行は検証済み API（Season 2 第2部 §4）

**図（案）:** 記号層（TBox/Playbook/Tool）と LLM 層の責務分離

**サンプルコード（§3）— Cypher 悪い例 + Python ツール境界**

```cypher
// LLM が hallucinate しがちな接続（存在しないエッジ）
MATCH (proc:Process)-[:SUPPLIED_BY]->(s:Supplier)
WHERE s.region = 'EastAsia'
RETURN proc
```

```python
# 決定論的ツールのみ LLM に公開（概念例）
def bom_supplier_impact(component_ids: list[str]) -> list[str]:
    """影響部品IDから親製品IDを返す（検証済みクエリを内部実行）"""
    ...
# LLM: Plan のみ / Cypher 文字生成はしない
```

---

### §4. 3段階のスコープ — 古典 → Season 1 → Season 2

**本シリーズ群の「総括表」（Season 2 第2部 §3 で再利用する初出定義）**

:::message 案
**3段階のスコープ：古典的オントロジー / シーズン1再定義 / シーズン2 Graph Contract**

| | 古典的オントロジー | シーズン1第3部の再定義 | シーズン2 Graph Contract |
| :--- | :--- | :--- | :--- |
| **主な内容** | 語彙体系 | 型・制約・利用文脈の SSOT | S1 SSOT + 組織間フェデレーション |
| **Context** | 通常含まない | Agent Skill 等の利用設計 | Federation Joins・Quality Gates |
| **スコープ** | 領域全体 | 1グラフDB | 3組織グラフ |
| **表現** | OWL/RDF | Pydantic SSOT | 契約マニフェスト + 生成 JSON |

Graph Contract はオントロジーを **置き換えず上乗せ** する契約レイヤー。
:::

- **TBox vs Playbook** の再整理:
  - TBox 寄り → Season 1 `schema.py` 相当
  - Playbook/契約寄り → Graph Contract、Agent Skill 生成ルール

**サンプルコード（§4）— 3段階進化を縦並び（Season 2 §3 比較表のコード版）**

```turtle
# ① 古典（TBox 再掲・1行でも可）— 第1部 §2 参照
ex:usedIn rdfs:domain ex:Component ; rdfs:range ex:Product .
```

```python
# ② Season 1 再定義（TBox 寄り SSOT・概念例）
ALLOWED_EDGES = {
    "USED_IN": ("Component", "Product"),
    "SUPPLIED_BY": ("Component", "Supplier"),
    "PRODUCED_BY": ("Product", "Process"),
}
```

```yaml
# ③ Season 2 Graph Contract（Playbook/契約寄り・概念例）
bridge_keys: [Component.id, Product.id]
federation_joins:
  - name: supplier_disruption_impact
    steps:
      - {domain: sourcing, via: SUPPLIED_BY, bridge: Component.id}
      - {domain: ebom, via: USED_IN, bridge: Product.id}
      - {domain: routing, via: PRODUCED_BY, bridge: Product.id}
```

**注釈:** 同一題材・同一制約が **スコープ拡張** していくことを本文 + 比較表で二重に示す。

---

### §5. 用語の実務マップ（辞書）

**1ページ相当の早見表**

| 用語 | 古典 | Season 1 | Season 2 |
| :--- | :--- | :--- | :--- |
| オントロジー | OWL 等 | Pydantic SSOT | schema + contract 分離 |
| スキーマ | RDFS/OWL | Pydantic モデル | 同上 + ドメイン registry |
| 制約 | OWL 公理 | ALLOWED_EDGES 等 | + 越境書き込み禁止 |
| 契約 | （明示概念少） | Skill/SSOT 生成 | Graph Contract |
| 推論 | DL エンジン | LLM + 決定論的ツール | フェデレーション Plan |

---

### §6. Season 1 へ — 読者への道案内

**3つの入口**

1. **仮想グラフ・市場動向から** → [Season 1 第1部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy-what)
2. **AI×グラフの理論から** → [Season 1 第2部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy2)
3. **変更管理・Pydantic から** → [Season 1 第3部](https://zenn.dev/yohei/articles/2026-05-30-vkg-strategy3)

**Season 0 を飛ばしてよい人**

- すでに OWL/RDF と LPG の違いを知っている
- Season 1 第3部の再定義パネルで足りる → 必要なら本稿 §4–§5 のみ

---

### §7. まとめ

- 古典的オントロジー / KG は **地図と compass**
- エンタープライズ AI エージェントは **SSOT・契約・ツール境界** が必要 — それが Season 1/2
- Season 0 は **完了**。次は実務シリーズへ

**連載一覧** — 第1部 / 第2部 / 第3部（本記事）+ Season 1 へのリンク

---

## 分量・トーン

- **目標:** 5,000–6,500字（§4 比較表 + コード縦並びが中心）
- **Season 2 第2部との関係:** 比較表は **本稿が canonical**、Season 2 は「Season 0 第3部 §4 参照」に短縮可能
- **コード:** 概念例のみ（[企画メモ §5.3 第3部](./season0-ontology-kg-series-plan.md#53-部別載せるコードと配置)）。Turtle + Cypher + Python + YAML 縦並び。**合計 250行以内**

---

## チェックリスト

- [ ] Season 0 単体で Season 1 に進める **動機** が足りるか
- [ ] Season 1/2 本文との **重複章** をリンク委譲で抑えているか
- [ ] 3段階表が今後のシリーズ全体の **用語の SSOT** として使えるか
- [ ] §4 の Turtle → Python → YAML が **同一制約の進化** として読めるか
- [ ] §3 Cypher 悪い例が ALLOWED_EDGES / Graph Contract の **動機** になっているか

---

## Further Reading（案）

- Baader et al., *The Description Logic Handbook*
- W3C OWL 2 Primer
- Hogan et al., *Knowledge Graphs*（教科書的総論）
- 国内: セマンティック Web 関連解説、Neo4j 公式ドキュメント（LPG 入門）
