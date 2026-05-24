---
title: "Snowflake - Cortex Code を用いた Cortex Agent / Analyst の活用"
emoji: "❄️"
type: "tech"
topics: ["snowflake", "cortex", "cli", "cortexcode"]
published: false
---

## 調査の目的

Snowflake には複数の UI が存在し、それぞれ想定するペルソナと目的が異なる。これらの UI それぞれに対して、**Cortex Analyst・Cortex Agent を別々に構築・管理する必要があるのか？** それとも **一度作れば共通で使い回せるのか？** を明らかにすることが本調査の目的である。

| UI | 主なペルソナ | 目的・ユースケース |
|---|---|---|
| **Snowflake Intelligence** | ビジネスユーザー・経営層・データ消費者（SQL を書かない人） | 自然言語でデータに質問し、すぐにインサイトを得る。Cortex Agent のチャット UI が組み込まれており、コードを書かずにデータ活用できる。2025 年 11 月に GA。 |
| **Cortex Code in Snowsight** | データアナリスト・SQL 開発者（Snowflake を日常的に使う人） | Snowflake 管理画面の中で AI に SQL 補完・クエリ説明・コスト分析・アカウント管理などを補助させる。SQL は書けるが、作業効率を上げたい。2026 年 3 月に GA。 |
| **Cortex Code CLI** | データエンジニア・ML エンジニア・開発者（ローカル環境で作業する人） | VS Code / Cursor などのローカル IDE から Snowflake に接続し、dbt プロジェクト管理・パイプライン構築・Streamlit 開発などを AI エージェントに補助させる。git や bash も含めた複合的な作業を自動化したい。 |
| **Cortex Agents for Microsoft Teams / M365 Copilot** | ビジネスユーザー・チームコラボレーター | Teams や M365 Copilot のチャット UI 内から Cortex Agent に自然言語で質問し、データインサイトを得る。Snowflake Intelligence と同じ Agent オブジェクトを再利用可能。 |

---

## 結論と現時点での推奨事項

**結論：バックエンド（Cortex Analyst・Cortex Agent）は共通で良い。UI ごとの個別実装は不要。**

セマンティックビューと Cortex Agent は一度構築すれば全 UI から再利用できる。

> **補足：** Cortex Analyst のメタデータ定義には旧来のセマンティックモデル YAML（ステージ上のファイル）も利用できるが、後方互換のために残るレガシー形式である。Snowflake は今後セマンティックビュー（Snowflake カタログオブジェクト）を推奨している。

各チームは以下の役割分担に集中すれば良い。

| 役割 | 担当 | やること |
|---|---|---|
| **データ基盤担当** | アナリスト・データエンジニア | Cortex Analyst 向けのセマンティックビューを整備する。UI には依存しない。 |
| **エージェント担当** | データエンジニア・開発者 | Cortex Agent をオーケストレーション層として構築する（`CREATE AGENT` SQL または Snowsight UI / REST API）。各 UI からは Cortex Agents Run API を呼び出すだけで再利用できる。 |

**現時点での推奨：**

1. **ビジネスユーザー向け** → Snowflake Intelligence のチャット画面を使う（最もシンプル・設定不要、GA 済み）
2. **Teams ユーザー向け** → Cortex Agents for Microsoft Teams / M365 Copilot を利用する（Snowflake Intelligence と同じ Agent オブジェクトを再利用可能）
3. **開発者・CLI ユーザー向け** → Cortex Code CLI の組み込みコマンド（`$cortex-agent`、`cortex analyst query` など）を使う（カスタムスクリプト不要）
4. **SQL 開発者向け** → Cortex Code in Snowsight を使う（GA 済み、`CORTEX_AGENT_USER` ロールでエージェント関連ワークフローにも対応）
5. **外部アプリ連携** → Cortex Agents Run API または `CREATE AGENT` SQL でエージェントオブジェクトを作成し、REST API で呼び出す

> **補足：** Cortex Code in Snowsight は GA（2026 年 3 月）以降、`SNOWFLAKE.CORTEX_AGENT_USER` データベースロールをサポートしており、エージェント関連のワークフローに対応している。ただし、Cortex Code CLI と異なり、任意の REST API 呼び出しやローカルファイルアクセスはできないため、用途に応じた使い分けが必要。

---

## 調査詳細

### 仮説

各 UI は「フロントエンド」に過ぎず、バックエンドの Cortex Analyst・Cortex Agent は共通の資産として一度構築すれば使い回せるはずである。

```text
[ Snowflake Intelligence     ] ──┐
[ Cortex Code CLI            ] ──┤
[ 外部アプリ                   ] ──┼──→ Cortex Agents API → [ Cortex Agent ]
[ Cortex Code Snowsight      ] ──┤                                ↓
[ Microsoft Teams / M365     ] ──┘                         [ Cortex Analyst ] ← セマンティックビュー
```

### 検証結果

| レイヤー | 共通化できるか | 備考 |
|---|---|---|
| **セマンティックビュー** | Yes | UI 非依存。アナリストが一元管理する。Marketplace でのリスティング共有にも対応。 |
| **Cortex Agent（オーケストレーション）** | Yes | GA（2025 年 11 月）。`CREATE AGENT` SQL でファーストクラスの SQL オブジェクトとして作成可能。Run API 経由でどの UI からでも呼び出せる。ツール種別は Cortex Analyst・Cortex Search・カスタムツール（UDF / ストアドプロシージャ）・Data to Chart・Web Search に対応。 |
| **UI からの呼び出し方** | UI ごとに異なる | 下記を参照。 |

### Cortex Code in Snowsight の位置づけと制約

**Cortex Code in Snowsight** は 2026 年 3 月に GA となり、`SNOWFLAKE.CORTEX_AGENT_USER` データベースロールをサポートしている。これにより、エージェント関連のワークフロー（アカウント管理・ガバナンス・コスト分析など）に対応している。

ただし Cortex Code CLI と比較すると以下の差異がある：

| 観点 | Cortex Code in Snowsight | Cortex Code CLI |
|---|---|---|
| **アクセスコントロール** | `COPILOT_USER` + (`CORTEX_USER` or `CORTEX_AGENT_USER`) | Snowflake 認証（接続設定） |
| **SQL 実行** | ✅ | ✅ |
| **Cortex Analyst クエリ** | ✅（組み込みツール） | ✅（`cortex analyst query` / `$cortex-agent`） |
| **ローカルファイルアクセス** | ❌ | ✅ |
| **bash / git 操作** | ❌ | ✅ |
| **任意の REST API 呼び出し** | ❌ | ✅（bash 経由） |
| **カスタムスキル・サブエージェント** | ❌ | ✅ |
| **MCP（外部ツール連携）** | ❌ | ✅ |
| **対応モデル** | Claude Opus 4.6 / 4.5、Claude Sonnet 4.5 / 4.0 | Claude Opus 4.6 等 |

### Cortex Code CLI のネイティブ Cortex サポート

Cortex Code CLI には Cortex Agent・Cortex Analyst との連携機能が組み込み済みである。カスタムスクリプトは不要であり、以下のコマンド・ツールがネイティブに利用できる。

| 機能 | 方法 |
|---|---|
| Cortex Agent とのチャット | バンドルスキル `$cortex-agent` → CHAT インテント（マルチターン対応） |
| Cortex Analyst クエリ | `cortex analyst query \"質問\" --view=<セマンティックビュー>` |
| エージェント一覧・詳細 | `cortex agents list` / `cortex agents describe <agent>` |
| セマンティックビュー探索 | `cortex semantic-views search \"キーワード\"` |
| SQL 実行 | `snowflake_sql_execute` ツール |
| 認証 | `cortex connections set <name>` で名前付き接続を設定すれば自動処理（トークン管理不要） |

```bash
# Cortex Agent とチャット（バンドルスキル）
$cortex-agent

# Cortex Analyst に直接クエリ
cortex analyst query "質問" --view=DB.SCHEMA.VIEW_NAME

# エージェント一覧・詳細確認
cortex agents list
cortex agents describe <agent>
```

### Cortex Code CLI における Agent Skill の正しい役割

組み込みコマンドで Cortex サービスを呼び出せるなら、Agent Skill は何のために作るのか。

**Agent Skill は API の代替ではなく、ドメイン知識のカプセル化のために使う。**

Cortex Code CLI は Snowflake の汎用 AI エージェントであり、質問するたびに以下を自力で調べる必要がある：

- どのエージェント・セマンティックビューを使えばよいか
- データの注意事項（対象期間、欠損、業界特有の語彙）
- どのステップを踏めばよいか（分析の手順）

これを毎回試行錯誤させると、コストがかさみ、精度も不安定になる。**Agent Skill にドメイン知識を記述しておくことで、この試行錯誤を削減できる。**

#### Agent Skill に書くべきこと

| 記述すべき内容 | 例 |
|---|---|
| どのセマンティックビュー・エージェントを使うか | `SALES_INTELLIGENCE.AGENTS.SALES_INTELLIGENCE_AGENT` を使う |
| データの注意事項 | 「データは 2024 年 1〜2 月のみ。\"last quarter\" で 0 件になる場合は期間を説明する」 |
| 業務・業界特有の語彙 | 「\"Pending\" は商談進行中、\"Closed\" は受注済み」 |
| よくある質問パターンと推奨ルーティング | 「売上指標 → Cortex Analyst、商談会話の内容 → Cortex Search」 |
| ワークフローテンプレート | 担当者別パフォーマンスレビュー、パイプライン健全性チェックなどの手順 |

#### Agent Skill に書かなくてよいこと

セマンティックビューに記述されている情報は、Cortex Code が実行時に `cortex semantic-views search` や `DESCRIBE` で自力で取得できる。SKILL.md への重複記載は保守コストを増やすだけである。

| 書かなくてよい内容 | 理由 |
|---|---|
| カラム名・データ型 | セマンティックビューの DDL に記載済み |
| カラムの説明・シノニム | セマンティックビューの定義に記載済み |
| サンプル値 | `DESCRIBE` または `SELECT DISTINCT` で取得可能 |

#### 推奨アーキテクチャ

```text
Agent Skill（ドメイン知識のみ）
  ├── どこを見るか（エージェント名・セマンティックビュー名）
  ├── データの注意事項・業界語彙
  └── ワークフロー手順
        ↓（指示を受けて）
Cortex Code CLI（組み込みコマンドで実行）
  ├── cortex analyst query / $cortex-agent
  ├── snowflake_sql_execute
  └── cortex semantic-views search
        ↓
Cortex Agent / Cortex Analyst（バックエンド・共通資産）
```

#### サンプル実装

Snowflake 公式サンプル [sfguide-getting-started-with-cortex-agents](https://github.com/Snowflake-Labs/sfguide-getting-started-with-cortex-agents) のエージェントを対象とした Agent Skill のサンプルを以下で公開している。

- **Agent Skill サンプル：** [yohei1126/agent-skills / sales-agent/SKILL.md](https://github.com/yohei1126/agent-skills/blob/main/sales-agent/SKILL.md)

このサンプルでは、売上指標・商談パイプライン・担当者別パフォーマンスなどの営業分析ユースケースを対象に、ルーティングルール・データ注意事項・ワークフローテンプレートを SKILL.md に記述する具体例を示している。

---

### 将来的な展望と最近の進展

以下は本ドキュメントの初版作成時（2026 年 4 月初旬）以前に実現された主な進展である：

| 進展 | 時期 | 概要 |
|---|---|---|
| **Cortex Agent GA** | 2025 年 11 月 | Cortex Agent が GA。`CREATE AGENT` SQL でファーストクラスの SQL オブジェクトとして管理可能に。 |
| **Snowflake Intelligence GA** | 2025 年 11 月 | ビジネスユーザー向けの既成エージェント UI が GA。 |
| **Cortex Code in Snowsight GA** | 2026 年 3 月 | Snowsight 内の AI コーディングアシスタントが GA。`CORTEX_AGENT_USER` ロールをサポート。 |
| **Microsoft Teams / M365 Copilot 連携** | GA 済み | Cortex Agent を Teams や M365 Copilot から直接利用可能。Intelligence と同じ Agent オブジェクトを再利用。 |
| **カスタムツール対応** | GA 済み | Cortex Agent のツールとして UDF やストアドプロシージャを登録可能。Data to Chart・Web Search も追加。 |

今後の方向性として、以下の発展が見込まれる：

- **Cortex Code in Snowsight のエージェント連携強化**: `CORTEX_AGENT_USER` ロールのサポートにより基盤は整っている。Snowsight 内から直接 Cortex Agent を呼び出す専用ツールの追加が期待される。
- **エージェント評価・モニタリングの成熟**: Cortex Agent Evaluations によるエージェントの品質管理とイテレーションの高度化。
- **マルチエージェント連携**: 複数の特化型エージェントを組み合わせた複雑なワークフローへの対応。

### まとめ

- **作るのは一度で良い：** Cortex Analyst のセマンティックビューと Cortex Agent は UI に依存しない共通資産である。`CREATE AGENT` SQL でオブジェクトとして管理できる。
- **UI は呼び出し方が違うだけ：** Snowflake Intelligence は組み込み、Teams / M365 Copilot は同じ Agent を再利用、CLI は組み込みコマンド（`$cortex-agent`・`cortex analyst query`）、外部アプリは Run API 直接呼び出し。
- **Cortex Code in Snowsight：** GA 済みで `CORTEX_AGENT_USER` ロールに対応。SQL 実行・Cortex Analyst クエリ・アカウント管理に対応するが、CLI ほどの自由度（bash・ローカルファイル・MCP）はない。
- **今すぐ始めるなら：** バックエンドを整備しておけば、UI 側の対応は後から追加できる。先にセマンティックビューと Cortex Agent の構築に集中することを推奨する。
