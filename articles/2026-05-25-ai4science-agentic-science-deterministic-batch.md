---
title: "AI for Science と Agentic Science — エージェントは調査補助、スコアとランキングは決定論的バッチに置く"
emoji: "🤖"
type: "tech"
topics: ["aiforscience", "llm", "agents", "mlops", "reproducibility", "explainability"]
published: false
---
<!-- markdownlint-disable MD013 MD060 -->

## この記事について

「Agentic Science」「AI エージェントで仮説生成」といった議論が増える一方、査読・監査・安全規制の現場では **「誰が・いつ・何を根拠に判断したか」** がますます厳しく問われます。両立のコツは、**エージェントに「科学の結論」を任せない**ことです。具体的には、**ランキング・スコア・閾値越えのアラート**は決定論的バッチ（または符号付きルールエンジン）だけが生成し、LLM / エージェントは **調査・要約・文献たどり** に限定します。

筆者は [indago](https://github.com/edgesentry/indago)（バッチ）+ [arktrace](https://github.com/edgesentry/arktrace)（読取 UI）+ ローカル LLM brief でこの分離を運用しています。Zheng et al.（2025）や *From AI for Science to Agentic Science*（arXiv, 2025）で語られる将来像は、**下流のオーケストレーション**として読むのが安全です。本記事は、その慎重な接続を AI for Science 向けに整理します。

関連: [スコアと LLM の分離](2026-05-19-explainable-judgment-score-llm-separation.md) · [判断の証跡](2026-05-19-tamper-evident-judgment-audit-chain.md)

---

## 1. Agentic Science で言われること / 言われていないこと

| よくある期待 | 研究インフラで本当に必要なこと |
|--------------|--------------------------------|
| エージェントが仮説を立てる | **再現可能な仮説候補の列挙**（人間が採択） |
| ツールを自律的に呼ぶ | **ツール呼び出しログ**（監査可能） |
| 論文ドラフトを書く | **Methods に run ID を書ける根拠** |
| ランキングを更新する | **固定 artefact 上の順位**（バッチ run） |

Agentic ＝ **自律的に「何が重要か」を決める** と解釈すると、査読でこけやすいです。Agentic ＝ **人間の調査手順を並列化する** と解釈すると、バッチ科学と相性がよいです。

---

## 2. 三層モデル（推奨）

```text
┌─────────────────────────────────────────────────────────────┐
│  Layer 0 — 決定論的バッチ（科学の「結果表」）                  │
│  ingest → 特徴量 → モデル/ルール → スコア・ランク → Parquet   │
│  変更権限: CI のみ · バージョン = git SHA + data publish ID   │
└────────────────────────────┬────────────────────────────────┘
                             │ read-only
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 1 — 構造化根拠（機械可読）                             │
│  SHAP · グラフパス JSON · 監査レコード · メトリクス JSON        │
└────────────────────────────┬────────────────────────────────┘
                             │ optional
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 2 — エージェント / LLM（調査補助）                     │
│  文献要約 · クロスソース質問 · brief 下書き · MCP ツール連携   │
│  禁止: スコア変更 · ランク変更 · 閾値変更 · エッジの追加      │
└─────────────────────────────────────────────────────────────┘
```

筆者の実装対応:

| Layer | 実装 |
|-------|------|
| 0 | indago `data-publish` → ウォッチリスト Parquet |
| 1 | `ownership_chain`, SHAP 列, `metrics/YYYYMMDD.json`, edgesentry-rs 監査 |
| 2 | arktrace Analyst brief（`run_llama.sh`）、Investigate パネル（任意） |

---

## 3. なぜ「エージェントにランキング」を任せないか

### 3.1 再現性

エージェントは **同じプロンプトでも非決定** になり得ます（温度・検索インデックス更新・ツールの副作用）。論文の Table 1 が **run ごとに変わる** のは致命的です。

### 3.2 責任の所在

規制・防衛・臨床前研究では、「アルゴリズムがそう判断した」ではなく **「バージョン X のパイプラインが閾値 Y でフラグした」** と言える必要があります。LLM の自然言語は **証拠にはなりにくい**（[判断の証跡](2026-05-19-tamper-evident-judgment-audit-chain.md)）。

### 3.3 マルチエージェントの複利バグ

Planner → Retriever → Critic の連鎖では、**どの段で順位が変わったか**が追えなくなります。バッチは **単一 DAG** の方がデバッグしやすいです。

---

## 4. エージェントに任せてよいこと（調査補助）

| タスク | 例（indago / arktrace） | 注意 |
|--------|-------------------------|------|
| ナレーション | Analyst brief の Regenerate | 「下書き」ラベル |
| ソースたどり | MarineTraffic / OFAC リンク集（Investigate） | スコア非連動 |
| 文献・ニュース要約 | GDELT コンテキストの要約 | 入力は publish 済み列 |
| メトリクス取得 | `fetch_publish_metrics.py` をエージェントが実行 | **読むだけ** |
| コード生成 | 新特徴量の **PR 草案** | main 直コミット禁止 |

arktrace の LLM は `VesselDetail` から **既存行フィールドだけ**を context に渡し、スコアを API で書き戻しません（[ref-llm-grounding.md](https://github.com/edgesentry/arktrace/blob/main/docs/ref-llm-grounding.md)）。

---

## 5. MCP・ツール呼び出しのガードレール

Agentic Science でツール（MCP, HTTP, DB）を増やすときの最小ルールです。

```text
許可ツール:
  - read_parquet / fetch_metrics / search_literature (read-only)
  - draft_brief / draft_methods_paragraph (write to scratchpad)

禁止ツール:
  - update_score / insert_graph_edge / overwrite_watchlist
  - delete_audit_record
```

**実装パターン:** エージェントの write 先は **Git ブランチ or ノートブックの tmp** のみ。本番 Parquet への write は **CI のみ**。

---

## 6. 「Agentic Science」文献との接続の仕方

論文・ブログで Agentic パイプラインが紹介されるとき、研究グループは次のように **翻訳** すると安全です。

| 文献上の主張 | ラボでの実装 |
|--------------|--------------|
| 自律的仮説探索 | バッチが出した **上位 K 候補**に対し、エージェントが文献を当たる |
| マルチモーダル統合 | Phase 1 はテキスト+表；画像は **別 ingest**（スコア未連動） |
| 人間フィードバック | HITL ラベルは **次週のバッチ**に取り込む（即時スコア変更しない） |

これは [edgesentry-commercial の L0/L2 分離](https://github.com/edgesentry/edgesentry-commercial/blob/main/docs/strategy/layer-model-l0-l3.md) と同型です。**L0（買い手・査読が見る結果）= バッチ**、**L2（OSS の説明・検証）= エージェント可能領域**。

---

## 7. アンチパターン集（AI for Science 版）

1. **「エージェントが異常を発見した」** — 実際は RAG がたまたま強い文献を引いた  
2. **プロンプト出力の confidence を表に載せる** — 再現不能  
3. **エージェントがグラフにエッジを追加** — シードの版が壊れる  
4. **デモだけ Agentic、本番は手動 Excel** — 再現性ゼロ  
5. **クラウド API 必須の調査エージェント** — データ主権で使えない  

---

## 8. 実装チェックリスト

- [ ] スコア・ランク・閾値フラグを変えるコードパスは CI/エンジンに一箇所  
- [ ] エージェントは read-only ツールのみ（または scratchpad write）  
- [ ] LLM 出力に `draft` / `requires_human_review`  
- [ ] 調査ログ（どのツールをいつ呼んだか）を保存  
- [ ] 論文は **バッチ run ID** を引用、エージェントの会話は引用しない  

---

## 9. まとめ

Agentic Science を **「AI が科学を自動でやる」** と読むと、再現性・監査・共同研究と衝突しやすいです。**「人間の調査を速くするオーケストレーション」** と読み、**結論表（スコア・ランク）は決定論的バッチ** に置けば、AI for Science のインフラ投資と矛盾しません。

筆者のスタックは海事ですが、創薬の hit リスト、材料の候補ランキング、観測ネットワークのアラートも、**Layer 0 を固定してから Layer 2 のエージェントを載せる** 順序は同じです。コミュニティでは、エージェントフレームワークの比較記事より **「何を決定論に残したか」** を書く投稿が、長く参照されます。

---

## 参考リンク

- [arktrace ref-llm-grounding](https://github.com/edgesentry/arktrace/blob/main/docs/ref-llm-grounding.md)  
- [indago-interpret-metrics skill](https://github.com/edgesentry/indago/blob/main/.agents/skills/indago-interpret-metrics/SKILL.md)  
- [判断の説明 — スコアと LLM の分離](2026-05-19-explainable-judgment-score-llm-separation.md)  
- [AWS Japan: AI for Science の歩き方 #13 — アクションプラン](https://zenn.dev/aws_japan/articles/ai4s-13-action-2026)
