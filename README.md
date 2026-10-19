# zenn

[Zenn](https://zenn.dev) 向けの記事原稿と、連載企画メモを管理するリポジトリです（**Zenn 専用**）。

LinkedIn 向けの英語記事・投稿下書きは、別リポジトリ [yohei1126/writing](https://github.com/yohei1126/writing/tree/main/linkedin) の `linkedin/` で管理します。

## このリポジトリでやっていること

特定ドメイン（主に **サプライチェーン影響分析**）における **知識グラフ × Graph RAG × AI エージェント** の開発課題を、Problem / Design / Build の三部作で整理し、Zenn に公開するための執筆拠点です。

2026 年以降は [IPA Open Dataspaces (ODS)](https://www.ipa.go.jp/digital/architecture/reports/open-dataspaces-design-philosophy.html) との接点（社内 Graph Contract ↔ OSI/DAD/IUC）も企画に含めています。

## 連載アーク（Season）

| Season | テーマ（案） | 状態 | 企画メモ |
| :--- | :--- | :--- | :--- |
| **0** | 知識グラフとオントロジーの源流（概念整理） | 企画中 | [season0-ontology-kg-series-plan.md](instructions/season0-ontology-kg-series-plan.md) |
| **1** | 仮想グラフ → エージェント → 変更管理 | 公開済 | `articles/2026-05-30-vkg-strategy*.md` |
| **2** | 組織分断 → 論理フェデレーション → 実装 | 公開済 | [supply-chain-neo4j-migration-plan.md](instructions/supply-chain-neo4j-migration-plan.md) |
| **3A** | 本番で信頼される契約（Evidence・監査・進化） | 執筆予定 | [season3-production-trust-series-plan.md](instructions/season3-production-trust-series-plan.md) |
| **Epilogue / 4** | B2B + ODS 接続 | 執筆予定 | [season3-trusted-federation-series-plan.md](instructions/season3-trusted-federation-series-plan.md) |

**推奨読者ルート:** Season 0（任意）→ 1 → 2 → 3A → Epilogue

**Season 2 記事（入口）**

- [第1部 背景](articles/2026-06-06-supply-chain-impact-analysis-agent.md)
- [第2部 設計](articles/2026-06-06-supply-chain-impact-analysis-agent2.md)
- [第3部 実装](articles/2026-06-06-supply-chain-impact-analysis-agent3.md)

**コンパニオン実装:** [yohei1126/supply-chain-impact-analysis-agent](https://github.com/yohei1126/supply-chain-impact-analysis-agent)（Neo4j マルチ DB + Graph Contract）

## ディレクトリ構成

```
zenn/
├── articles/          # Zenn 公開原稿（front matter 付き Markdown）
├── images/            # 記事用画像・drawio
├── instructions/      # 連載企画・執筆計画・アウトライン（執筆者向け）
├── raw/               # 外部資料アーカイブ（gitignore。ローカルのみ）
├── analytics/         # 調査・分析メモ（gitignore。ローカルのみ）
├── package.json       # zenn-cli 等
├── README.md          # 本ファイル（人間向け索引）
└── AGENTS.md          # エージェント向け索引
```

### `instructions/` の主要ファイル

| ファイル | 内容 |
| :--- | :--- |
| [season3-trusted-federation-series-plan.md](instructions/season3-trusted-federation-series-plan.md) | **Season 3 索引・テーマ総覧**（まずここ） |
| [season0-ontology-kg-series-plan.md](instructions/season0-ontology-kg-series-plan.md) | Season 0 全体企画 |
| [season3-production-trust-series-plan.md](instructions/season3-production-trust-series-plan.md) | Season 3A 社内本番 |
| [season3-b2b-ods-connection-plan.md](instructions/season3-b2b-ods-connection-plan.md) | B2B / ODS / L4 OSS 接続 |
| [supply-chain-neo4j-migration-plan.md](instructions/supply-chain-neo4j-migration-plan.md) | Season 2 実装リポジトリ整合 |
| [plan-20260706-01.md](instructions/plan-20260706-01.md) | 第3部と実装のアライメント |

### ローカル調査素材（`.gitignore` 対象）

| パス | 内容 |
| :--- | :--- |
| `raw/ods/` | ODS-RAM / ODP / 入門・開発者ガイド等の md アーカイブ |
| `analytics/ods/` | OSS 実装分析（例: SDK-for-semantics） |

ODS L4 参照実装のクローンはリポジトリ外: `/Users/yoheionishi/work/open-dataspaces/`

## 執筆・プレビュー

```bash
npm install
npx zenn preview
```

記事は `articles/` に `YYYY-MM-DD-slug.md` 形式で配置します。連載の前後関係や用語は `instructions/` の企画メモを正とします。

## シリーズと ODS の接点（要約）

本連載（社内 Graph RAG / フェデレーション）と ODS（分散データスペース）は **入口は違うが問いは同型** です。

| 問い | 本シリーズ | ODS |
| :--- | :--- | :--- |
| Where to get | Bridge Keys, Federation Joins | DAD（Discovery） |
| What to mean | Graph Contract, `schema.py` | OSI（SAMM, Ontology Product） |
| Who / How to use | registry, Quality Gates | IUC（Usage Control） |

詳細は [season3-b2b-ods-connection-plan.md](instructions/season3-b2b-ods-connection-plan.md) を参照。

## ライセンス・公開

記事本文の著作権は著者に帰属します。公開先: [Zenn @yohei](https://zenn.dev/yohei)
