---
title: "Snowflake GPA フレームワークに基づいたノーコード・ローコードなモニタリング戦略"
emoji: "❄️"
type: "tech"
topics: ["snowflake", "cortex", "monitoring", "gpa"]
published: true
---

## 概要

Snowflake Cortex Agent や Cortex Analyst をエンタープライズ環境で継続的に運用するにあたり、「回答が正しいか」「思考プロセスが妥当か」「リソース消費が適正か」の三軸を常に把握することが求められる。本記事では、Snowflakeが提唱する **GPA（Goal-Plan-Action）フレームワーク** をモニタリングの評価軸として採用し、主に Snowsight UI の画面操作で実現できる具体的な監視・改善サイクルを整理する。

> **前提スキルについて：** 大部分の操作は Snowsight の UI 操作（ノーコード）のみで完結する。ただし、自動アラートの設定には `CREATE ALERT` 文などの **最小限の SQL 知識（ローコード）** が必要となる箇所がある。SQL や Python の専門知識は不要だが、SQL の基本的な読み書きができると本記事を最大限活用できる。

## 想定読者

本記事は、以下に該当する方を対象としている。

| 対象 | 具体例 |
|:---|:---|
| **データアナリスト / ビジネスアナリスト** | Snowflake を使ってデータ分析・レポートを行っている |
| **データサイエンティスト** | Cortex Agent / Analyst を活用した AI ワークフローを設計・検証している |
| **ビジネスユーザー** | 自然言語でデータに問い合わせる AI ツールを日常業務で使っている |

**前提スキル：** DevOps・ソフトウェア開発・クラウドインフラの専門知識は不要。本記事で紹介するモニタリングとアラートの大部分は Snowsight の UI 操作のみで実現でき、一部の自動アラート設定には最小限 of SQL 知識（`CREATE ALERT` 文の書き換え程度）があれば十分である。

---

## GPAフレームワークとは

Snowflake AI Research チームが TruLens ライブラリで公開した評価フレームワークで、エージェントの動作を3つの階層に分解し、それぞれの整合性を定量的に測定する。

| 階層 | 問い | 主な失敗パターン |
|:---|:---|:---|
| **Goal（目標）** | ユーザーの意図に対して回答は正確・関連・根拠付きか | ハルシネーション、的外れな回答 |
| **Plan（計画）** | 目標達成のためのロードマップが適切に設計・選択されたか | 誤ったツール選択、計画の欠落 |
| **Action（実行）** | 計画通りにツールが呼び出され、効率的に実行されたか | 無駄なツール呼び出し、パラメーター誤り |

GPAフレームワークのベンチマーク（TRAIL/GAIA データセット）では、ベースラインの LLM ジャッジが 55% のエラーしか検出できなかったのに対し、GPA ジャッジは **95% のエラーを検出** し、86% の精度でエラーが発生したトレース上の箇所を特定できることが実証されている（[Snowflake Engineering Blog](https://www.snowflake.com/en/engineering-blog/ai-agent-evaluation-gpa-framework/)、[論文（arxiv）](https://arxiv.org/abs/2510.08847)）。

---

## GPA × Snowsight 機能マッピング

GPA の各階層を Snowsight が提供するノーコード機能に対応させると以下のとおりとなる。

| GPA 階層 | メトリクス | 対応する Snowsight 機能 | 確認場所 |
|:---|:---|:---|:---|
| **Goal** | Answer Correctness | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) | 評価スコア一覧 |
| **Goal** | Answer Relevance | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) | 評価スコア一覧 |
| **Goal** | Groundedness | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) | 評価スコア一覧 |
| **Plan** | Plan Quality | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（GENERATION スパン） | ウォーターフォール図 |
| **Plan** | Tool Selection | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（TOOL スパン） | スパン詳細 |
| **Action** | Plan Adherence | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（思考・リフレクション イベント） | イベント詳細 |
| **Action** | Tool Calling | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（TOOL スパン パラメーター） | スパン詳細 |
| **G-P-A 横断** | Logical Consistency | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications)（正解データ不要） | 評価スコア一覧 |
| **G-P-A 横断** | Execution Efficiency | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) | 評価スコア一覧 |
| **性能** | レイテンシ | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（スパン実行時間） | ウォーターフォール図 |
| **コスト** | クレジット消費 | [Admin > Cost Management](https://docs.snowflake.com/en/user-guide-manage) | ダッシュボード |
| **コスト** | トークン消費 | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)（GENERATION スパン） | スパン詳細 |

---

## Goal モニタリング：回答の正確性・関連性・根拠

### 評価の実行（Evaluations タブ）

Snowsight の [`AI & ML > Agents`](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) から対象エージェントを選択し、`Evaluations` タブを開く。

**評価セットの準備：**

- 期待される質問（Query）と正解（Ground Truth）のペアをテーブルとして Snowsight 上で準備する
- 正解データがない場合でも「Logical Consistency」だけは算出可能

**評価の作成手順：**

1. `Create evaluation run` をクリック
2. データセットを選択し、質問列・正解列をドロップダウンでマッピング
3. 測定したいメトリクス（Answer Correctness、Groundedness など）にチェックを入れて実行

**結果の解釈：**

- スコアは 0〜1 の範囲で表示され、しきい値（例：0.7 以上）を下回る質問を抽出して詳細調査する
- `Record details` パネルからは、LLM ジャッジが付与したスコアの **理由（テキスト）** も確認できる

### 比較分析（サイドバイサイド）

オーケストレーション指示やセマンティックモデルを変更した前後で評価を実行し、UI 上のコンパリソンビューで改善度を比較する。コードを書かず、パラメーター調整の効果を定量的に検証できる。

---

## Plan モニタリング：ツール選択と計画の妥当性

### トレースによる計画の可視化（Traces）

[`Cortex AI > Agents > {エージェント} > Monitoring`](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability) で、エージェントのすべてのインタラクションが時系列で記録される。各トレースはウォーターフォール図（フレームグラフ）で表示され、以下のスパンタイプを確認できる。

| スパンタイプ | Plan モニタリングにおける確認ポイント |
|:---|:---|
| **GENERATION** | LLM がどのツールを選択したか（Tool Selection）、どのような推論を行ったか（Plan Quality） |
| **TOOL** | Cortex Analyst への呼び出しパラメーター、生成された SQL、返り値の妥当性 |
| **RETRIEVAL** | Cortex Search の検索クエリと取得コンテキスト、関連性スコア |

### 思考・リフレクションイベントの確認

最新の Cortex Agent は「なぜそのツールを選んだか」「前のステップの結果が不十分だとなぜ判断したか」という推論の根拠を **イベント** として放出する。Snowsight の UI はこのイベントを捕捉し、エージェントの意思決定プロセスをテキストで表示する。

**Plan の問題を発見したときの対処（ノーコード）：**
トレースで「誤ったツール選択」が散見される場合、エージェント設定画面でツールの説明文（Tool Description）をより具体的に修正する。例えば `SalesQuery` ではなく `AnnualRevenueMetrics_CortexAnalyst` のように命名し、「使用すべきでないケース（When NOT to use）」を明文化することで、オーケストレーターの迷いを排除できる。

---

## Action モニタリング：ツール実行の精度と効率

### Cortex Analyst 専用モニタリングタブ

Snowsight の[セマンティックビュー管理画面](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)には専用の `Monitoring` タブが統合されており、Cortex Analyst に送られた全クエリのログをほぼリアルタイムで確認できる。

| 確認できる情報 | Action モニタリングにおける活用 |
|:---|:---|
| 生成された SQL 全文 | ビジネス定義に対してどのカラム・テーブルにマッピングされたか検証 |
| エラー・警告の内訳 | Tool Calling の失敗パターンを特定 |
| リクエスト＆レスポンスボディ | 誤ったパラメーター渡しの原因を特定 |

ログから誤った SQL が生成されていると判明した場合、同じ画面からセマンティックモデルにシノニム（類義語）や説明文を追加し、次回以降の精度を改善できる。

### ユーザーフィードバックの収集と活用

Snowflake Intelligence や Streamlit in Snowflake（SiS）上のアプリに標準提供される「サムズアップ / サムズダウン」ボタンの評価は、オブザーバビリティテーブルに記録される。Snowsight の監視画面で「Bad Feedback」フィルターを適用し、不満の多いリクエストを優先的に調査することで、Action レイヤーの問題箇所を効率的に特定できる。

### Semantic View Autopilot による継続改善

[`Semantic View Autopilot`](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-suggestions) は、クエリ履歴を自動分析して、より関連性の高いメトリクス・ディメンション定義を提案する。管理者はUI上でレビューしてクリックするだけでモデルを更新できる。また、頻繁に質問されるが精度が低いものは「[Verified Queries（検証済みクエリ）](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/verified-query-repository)」として登録することで、推論を経ずに高精度・低レイテンシで回答させることが可能になる。

---

## 性能モニタリング：レイテンシのボトルネック特定

トレースのウォーターフォール図では、各スパンの **実行時間** が視覚的に表示される。「回答が遅い」という問題が発生したとき、以下を即座に切り分けられる。

| レイテンシの原因 | 確認するスパン |
|:---|:---|
| LLM の推論時間 | GENERATION スパン |
| Cortex Search の検索時間 | RETRIEVAL スパン |
| Cortex Analyst の SQL 実行時間 | TOOL スパン |
| エージェント全体の往復時間 | RECORD_ROOT スパン |

---

## コストモニタリング：AI クレジットの可視化とガバナンス

### AI クレジットの消費ダッシュボード

[`Admin > Cost Management`](https://docs.snowflake.com/en/user-guide-manage) では、AI 機能によるクレジット消費を日次・週次・月次で可視化できる。Snowflake Intelligence・Cortex Agent・Cortex Code は「AIクレジット」として一律請求されるため、他のデータウェアハウス利用と分離して AI プロジェクト単体の ROI を評価しやすくなっている。

### タグベースの予算管理（Budgets）

[`Admin > Cost Management > Budgets`](https://docs.snowflake.com/en/user-guide/budgets) から部門・プロジェクト別に予算上限を設定できる。

**設定手順（UI のみ）：**

1. `+ Budget` をクリック、予算名と月間クレジット上限を入力
2. スコープとしてコストセンタータグ（例：`cost_center = 'Analytics'`）を選択
3. 監視対象として `Cortex Agents`・`AI Functions` などのドメインを有効化
4. しきい値アクションを設定（例：80% 消費でメール通知、100% 到達で権限剥奪）

### トークンレベルのコスト分析

各トレースの GENERATION スパン詳細には、`input_tokens`・`output_tokens`・`cached_input_tokens` が記録される。プロンプトキャッシュが有効に機能している場合、キャッシュ入力トークンは通常の **10%** のコストで請求されるため、セマンティック定義や共通システムプロンプトをキャッシュ効率が高い設計にすることで大幅な節約が可能である。

### モデル別コスト効率の確認

| モデルクラス | 用途 | コスト特性 |
|:---|:---|:---|
| フロンティア（Claude Opus 等） | 複雑な計画・論理推論 | 高コスト。正確性最優先の場面のみ使用 |
| ミッドレンジ（Claude Sonnet 等） | 標準的なオーケストレーション・SQL生成 | バランス型。多くのアナリスト業務に適合 |
| 小規模（Llama 3.1 8B 等） | 分類・要約・ルーティング | 低コスト。大量リクエスト処理に有効 |

トレース詳細でモデル名とトークン数を定期サンプリングすることで、オーケストレーション指示を調整し、より安価なモデルへの代替可否を判断する材料が得られる。

---

## アラートの設定：異常の自動通知

### コスト異常（ノーコード）

[Budgets のしきい値通知](#コストモニタリングai-クレジットの可視化とガバナンス)で対応できる。月間消費が設定値に達した際にメールを自動送信する。

### 性能・精度の異常（SQL）

コスト以外の異常検知には [Snowflake Alerts](https://docs.snowflake.com/en/user-guide/alerts) を使用する。SQL で一度定義すれば以降はスケジュール実行される。

**手順 1：メール通知インテグレーションの作成（初回のみ）**

```sql
CREATE NOTIFICATION INTEGRATION cortex_alert_email
  TYPE = EMAIL
  ENABLED = TRUE;
```

**手順 2：レイテンシアラート**（平均応答時間がしきい値超過）

```sql
CREATE OR REPLACE ALERT cortex_latency_alert
  WAREHOUSE = <warehouse_name>
  SCHEDULE = 'USING CRON 0 * * * * UTC'    -- 毎時チェック
  IF (EXISTS (
    SELECT 1 FROM (
      SELECT AVG(duration_ms) AS avg_ms
      FROM <event_table>                    -- AI Observability のイベントテーブル
      WHERE record_type = 'SPAN'
        AND record:name::STRING = 'RECORD_ROOT'
        AND timestamp > DATEADD('hour', -1, CURRENT_TIMESTAMP())
    )
    WHERE avg_ms > 10000                    -- 10 秒超で発火
  ))
  THEN CALL SYSTEM$SEND_EMAIL(
    'cortex_alert_email',
    'alert@example.com',
    'Cortex Agent: レイテンシ異常',
    '直近1時間の平均応答時間が 10 秒を超えました。Cortex AI > Agents > Monitoring でトレースを確認してください。'
  );
```

**手順 3：精度スコアアラート**（評価スコアがしきい値未満）

```sql
CREATE OR REPLACE ALERT cortex_accuracy_alert
  WAREHOUSE = <warehouse_name>
  SCHEDULE = 'USING CRON 0 9 * * * UTC'    -- 毎朝 9 時チェック
  IF (EXISTS (
    SELECT 1 FROM (
      SELECT AVG(score) AS avg_score
      FROM <evaluation_results_table>       -- Evaluations の結果テーブル
      WHERE metric_name = 'answer_correctness'
        AND run_timestamp > DATEADD('day', -1, CURRENT_TIMESTAMP())
    )
    WHERE avg_score < 0.7                   -- 0.7 未満で発火
  ))
  THEN CALL SYSTEM$SEND_EMAIL(
    'cortex_alert_email',
    'alert@example.com',
    'Cortex Agent: 精度スコア低下',
    '直近の answer_correctness スコアが 0.7 を下回りました。Evaluations タブで詳細を確認してください。'
  );
```

**手順 4：アラートの有効化**

作成直後はデフォルトで停止状態のため、明示的に起動する。

```sql
ALTER ALERT cortex_latency_alert RESUME;
ALTER ALERT cortex_accuracy_alert RESUME;
```

### 実行履歴の確認（Snowsight UI）

アラートの実行状況は Snowsight の [`Monitoring > Alert History`](https://docs.snowflake.com/en/user-guide/alerts) で確認できる。

### 監視対象と手段のまとめ

| 監視対象 | ノーコードで可能か | 手段 |
|:---|:---:|:---|
| コスト異常 | ✅ | Budgets のしきい値通知 |
| レイテンシ異常 | ❌ | `CREATE ALERT` + イベントテーブル |
| 精度スコア低下 | ❌ | `CREATE ALERT` + 評価結果テーブル |

---

## モニタリングサイクルの全体像

ノーコードで回せる PDCA サイクルは以下のとおりである。

```text
[Plan]
Evaluations タブで定期評価を実行し、GPA 各メトリクスのベースラインを計測

         ↓

[Do]
トレースのウォーターフォール図で、スコア低下の原因スパンを特定

         ↓

[Check]
Semantic View Monitoring タブで誤 SQL パターンを確認
Feedback の「サムズダウン」フィルターでユーザー不満箇所を抽出

         ↓

[Act]
Semantic View にシノニム・Verified Queries を追加（Analyst 精度向上）
Tool Description を修正（Agent の計画品質向上）
Budget しきい値を調整（コストガバナンス強化）

         ↓ 改善後

[Plan] 再評価で改善前後のスコアを比較検証（サイドバイサイド）
```

---

## まとめ

SnowflakeのGPAフレームワークとSnowsight UIを組み合わせることで、データエンジニアや管理者はコードを一行も書かずに以下を実現できる。

| 監視領域 | 主要ツール | GPA 階層 |
|:---|:---|:---|
| 回答の正確性・根拠 | [AI Observability > Evaluations](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications) | Goal |
| 計画の妥当性・ツール選択 | [Cortex AI > Agents > {エージェント} > Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability) | Plan |
| ツール実行の精度・フィードバック | [Semantic View Monitoring](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)・Feedback | Action |
| 性能（レイテンシ）ボトルネック | [Traces（スパン実行時間）](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability) | 性能 |
| コスト（部門別・モデル別） | [Cost Management](https://docs.snowflake.com/en/user-guide-manage)・[Budgets](https://docs.snowflake.com/en/user-guide/budgets)・[Traces](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability) | コスト |

Snowflake Trail が自動収集するテレメトリデータを活用し、GPAフレームワークの評価軸に沿って継続的に改善を回すことが、エンタープライズにおける信頼できるAI運用の基盤となる。
