---
title: "dbt 特化型 Data Observerbility ツール の Elementary OSS 版と Cloud 版の比較"
emoji: "🦁"
type: "tech"
topics: [dbt,elementary,snowlfake,bigquery]
published: true
publication_name: "dataheroes"
---

# 本記事の背景

以前、 Data Observability という技術分野の概要とその代表として dbt 特化型の Elementary について紹介しました。

https://zenn.dev/yohei/articles/2024-04-15-data-observability

本業で部分的に Elementary OSS 版を部分的に評価中であり、その先のクラウド版との違いについても調査してみようとなりました。

# Elementary の概要

Elementary は主に dbt を対象とした Data Observability ツールです。 dbt data test の結果をデータ品質メトリクスと紐付けてダッシュボードで可視化してくれたり、データ量・スキーマ・鮮度など　dbt data test とは違った観点でデータの異常値を時系列分析手法で検出し、 Slack　に通知してくれたりします。 

OSS 版と Cloud 版のがあり、両方とも顧客のデータウェアハウスに専用のデータベースを作り、 dbt コマンド実行時に蓄積した各種メトリクスを保存しておくという構成になっています。

* https://www.elementary-data.com/
* https://docs.elementary-data.com/introduction
* OSS vs Cloud https://docs.elementary-data.com/overview/cloud-vs-oss

# 他のツールと比較しての Elementary のメリット

厳密なツール比較はしていませんが、現時点での Elementary の良さの所感を書いておきます。

## (1) シンプルさ

主にクラウドデータウェアハウスと dbt に特化しているため、作りがシンプルだと言えます。例えば、データ品質問題の検出の手段は、 dbt data test 結果もしくは異常検知（データの鮮度・量・スキーマなど）のみです。前者は前述の通り、監視対象のデータウェアハウス内に蓄積した dbt run / test の結果を利用し、後者はデータウェアハウスのメタデータ （ Snowflake の Account Usage ） から検知します。

様々なツールから生データを取り込みをする必要がなく、対象ツールも絞られており、ある程度、顧客側で集計されたメタデータを利用する構成になっているため、シンプルな作りになっていると言えます。

## (2) コスト効率性

前述の通り、各種モニタリングで必要になる各種情報（データリネージなど各種メタデータ）の収集と蓄積は、顧客側のデータウェハウス側で dbt パッケージ側で行われる。ツールによっては、高頻度でモニタリング対象のデータウェアハウスをクローリングするような動きをするものもあり、それに比べて Elementary Cloud 側のインフラコストが安く済むと言えます。

freshness, volume and schema の自動モニタリングも、データウェアハウス側のメタデータ　(Snowflake account usage) を取得して行われるので比較的軽量です。

# クラウド版で特に便利な機能

Elementary のドキュメントは無料で利用できる機能とクラウド版で有料の機能があります。どれがクラウド版のみかはドキュメントに記載しているので、そちらを確認してください。特にクラウド版のみの機能で有用だと感じたのは以下です。

https://docs.elementary-data.com/overview/cloud-vs-oss

* Automated freshness, volume and schema monitors - クラウド版の場合、 Snowflake account usage や BigQuery Information Schema を自動的に検査して異常を見つけてくれる。
* Monitored data sets – all tables (not only for dbt) - Snowflake account usage や BigQuery Information Schema を自動的に検査して異常を見つけてくれるので、 dbt models 以外も対応可能。
* Column-level lineage
* Lineage to BI tools - BI と API 連携する。どのテーブルが BI ダッシュボードで使われているかを確認して、データリネージ上に表示してくれる。ドキュメントで BI へのリネージ例を確認できる。　https://docs.elementary-data.com/features/exposures-lineage
* Multiple environments and data warehouses - 複数 dbt プロジェクト、複数データウェハウスに対応できる
* CI - Pull request で dbt モデルの異常を検査する。まだベータ版。

# おわりに

本記事では、 dbt 特化型 Data Observability ツール の Elementary OSS 版と Cloud 版の比較を行いました。
Elementary は OSS が提供されており、 dbt パッケージを入れるだけで利用できるため、 Data Observability に取り組みたい人が気軽に始められ、不要だと思えば気軽に辞められるツールだと言えます。

もし興味を持ったらチュートリアルを参照して、試用してみてください。

https://docs.elementary-data.com/quickstart
