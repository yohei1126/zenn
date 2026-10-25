# AGENTS.md

エージェント向けハイレベル索引。このリポジトリで作業する前に読む。

## リポジトリの目的

**Zenn 専用**の連載原稿（`articles/`）と執筆企画（`instructions/`）の管理。主題は **エンタープライズ向け Graph RAG / 論理フェデレーション / Graph Contract** 。題材は **サプライチェーン影響分析**（ebom / routing / sourcing）。

LinkedIn 向け英語記事・投稿は本リポジトリ外: [yohei1126/writing](https://github.com/yohei1126/writing/tree/main/linkedin)（`linkedin/`）。

ODS（Open Dataspaces）接続は Season 3 以降の企画。宣伝記事ではなく **実装者視点のマッピングと摩擦の記録** が貢献方針。

## 最初に読むファイル

| 優先 | パス | 用途 |
| :---: | :--- | :--- |
| 1 | `instructions/season3-trusted-federation-series-plan.md` | Season 3 索引・ODS インサイト・執筆順 |
| 2 | タスクに応じた season 企画（下表） | 執筆・レビュー・実装整合 |
| 3 | `README.md` | 人間向け概要・ディレクトリ |

### Season 企画ファイル

| Season | ファイル |
| :--- | :--- |
| 0 | `instructions/season0-ontology-kg-series-plan.md`, `season0-part{1,2,3}-outline.md` |
| 2 実装整合 | `instructions/supply-chain-neo4j-migration-plan.md`, `plan-20260706-01.md` |
| 3A 社内本番 | `instructions/season3-production-trust-series-plan.md` |
| 3B / ODS | `instructions/season3-b2b-ods-connection-plan.md` |
| ODS 世界観 | `instructions/ods-owa-vs-cwa-worldview.md`（OWA/CWA・セマンティックWeb系譜） |
| 5 設計・品証・製造 | `instructions/season5-design-qa-mfg-sample-implementation.md` |

別シリーズ（Season 番号なし）: Ontographia 第1〜3部 `articles/2026-09-08-ontographia-*.md`（下書き）

## ディレクトリと gitignore

| パス | コミット | 説明 |
| :--- | :---: | :--- |
| `articles/` | ○ | 公開原稿。front matter 必須 |
| `instructions/` | ○ | 企画メモ。記事執筆の正本 |
| `images/` | ○ | 記事画像 |
| `raw/` | × | 外部資料 md/PDF（ODS 等）。ローカルのみ |
| `analytics/` | × | 調査・分析メモ。ローカルのみ |

## 外部リポジトリ（リポジトリ外）

| パス / URL | 役割 |
| :--- | :--- |
| `github.com/yohei1126/supply-chain-impact-analysis-agent` | Season 2 コンパニオン実装（Neo4j, Graph Contract, tools） |
| `github.com/yohei1126/writing`（`linkedin/`） | LinkedIn 英語記事・投稿下書き |
| `/Users/yoheionishi/work/open-dataspaces/` | ODS L4 OSS クローン（SDK-for-semantics, L4-discovery-*, L4-crawler-service 等） |

## 連載マップ（公開済み記事 slug）

| Season | 記事ファイル |
| :--- | :--- |
| 1 | `articles/2026-05-30-vkg-strategy-what.md`, `vkg-strategy2.md`, `vkg-strategy3.md` |
| 2 | `articles/2026-06-06-supply-chain-impact-analysis-agent.md`, `...agent2.md`, `...agent3.md` |

Season 3 は未執筆。執筆順: **3A → Epilogue → Season 4（任意）**。

## 核心用語（シリーズ ↔ ODS）

| シリーズ | ODS / DPQM |
| :--- | :--- |
| Graph Contract Identity | Ontology Product / OSI |
| Bridge Keys, Federation Joins | DAD / Discovery |
| registry, Quality Gates | IUC / Usage Control |
| プランナー → 決定論的 Cypher | Ontology Query → Data Query |
| `ontology/schema.py` (Pydantic) | Closed 側意味・Data Product |
| `graph_contract.yaml` | 社内意味契約 + Federation Joins |

**Graph Contract** は実装では `ontology/contract/graph_contract.yaml`（旧 `graph_context.yaml` からリネーム済み）。

## 記事執筆ルール

- 応答・記事本文は **日本語**
- **日本語技術文書の推敲規範**: 記事の執筆および推敲時には、必ず `~/.agents/skills/japanese-tech-writing/SKILL.md` の規範を適用する（パラグラフライティング、論証の厳密さ・ツッコミどころの排除、読み手の負荷管理、LLM特有の空句・過剰な修飾や擬人化の排除、冗長の排除）。
- **Zenn 記事の推敲規範**: 記事本文の執筆および推敲時には、`~/.agents/skills/zenn-article/SKILL.md` も適用する。
- **PR 前レビュー**: `articles/` 配下のファイルを追加または変更する PR を開く前、およびその PR を更新する前に、記事本文へ `japanese-tech-writing` と `zenn-article` のレビューを適用する。未レビューの下書きを PR の先端コミットにしない。
- 連載は **Problem / Design / Build** の型を維持
- 新 Season 執筆前に該当 `instructions/*.md` を読み、用語を企画メモに合わせる
- ODS 記事: ODP 網羅・IPA 逐語解説・法務詳細は **やらない**（`season3-b2b-ods-connection-plan.md` §9）
- Season 3A 完成前に B2B/ODS 本編を混ぜない（Epilogue は 1 段落の伏線まで）
- `instructions/` の更新はユーザー明示時のみ（記事執筆タスクで企画変更が必要なら提案して確認）
- git commit はユーザー明示時のみ
- `raw/`, `analytics/` は gitignore。参照用にローカルで読む

## ODS 調査素材（ローカル）

| パス | 内容 |
| :--- | :--- |
| `raw/ods/` | ODS-RAM, ODP (L2/L3/L4), 入門ガイド, Developer Guide の md |
| `analytics/ods/sdk-for-semantics-overview.md` | L4 SDK 実装の仕組み |

## プレビュー

```bash
npx zenn preview
```

## タスク別クイックパス

| タスク | 読むもの |
| :--- | :--- |
| **記事の執筆・推敲全般** | `~/.agents/skills/japanese-tech-writing/SKILL.md`（文章規範）、`~/.agents/skills/zenn-article/SKILL.md`（Zenn 記事体裁）。`articles/` を変える PR の前に両方で本文をレビューする |
| Season 2 記事修正 | `plan-20260706-01.md`, コンパニオン repo, agent/agent2/agent3 |
| Season 3A 執筆 | `season3-production-trust-series-plan.md` |
| ODS / B2B 執筆 | `season3-b2b-ods-connection-plan.md`, `ods-owa-vs-cwa-worldview.md`, `raw/ods/`, `analytics/ods/` |
| Season 0 執筆 | `season0-ontology-kg-series-plan.md`, part outlines |
| Season 5 サンプル実装 | `season5-design-qa-mfg-sample-implementation.md`, 第1–3部記事 |
| 用語の古典的背景 | Season 0 企画、Season 1 第3部 |

## 成功基準（Season 3 全体）

- Graph Contract / Bridge Keys が OSI/DAD/IUC の **別名再発明** に見えない
- 「Bridge Key を社外に渡すだけ」が IUC 的に **不十分** と説明できる
- L4 OSS 接続で仕様外の **摩擦** を1つ以上記録できる

詳細: `instructions/season3-trusted-federation-series-plan.md` §4
