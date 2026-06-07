# 背景
こちらのイベントに登壇するので、日本語の発表原稿を用意してください。
タイトルは「SnowflakeとDatabricksに見るOLAPとOLTPの統合」です。
https://cdpm.connpass.com/event/357453/
持ち時間は10分のLTなので要点を絞って話す必要があります。
発表原稿の出力先はこちらでお願いします。
/Users/yoheionishi/work/zenn/articles/2025-07-02-cross-cloud-platform.md
あとでzennの記事として公開するので、zennの記事のフォーマットを利用してください。

# 発表原稿の内容

## 公式発表の内容のまとめ
10分以内と短いので、最初の１枚でSnowwflakeとDatabricksが公式に発表したことをまとめてください。
まず、両者がPostgreSQLの新興企業を買収した。
PostgreSQLのマネージドサービスを提供する。
PostgreSQLとオブジェクトストレージ上のIcebergテーブルとの同期を提供する。
他にまとめで指摘することあれば教えて。

## 現状の再確認
なぜ今の話は、多くの会社にとって現状と乖離があると思うので、現状を再確認する。
多くの会社で、SnowflakeやDatabricksのデータ分析基盤にOLAP、つまり分析用データベースがある。
一方で、データの発生源になっているオペレーション系のシステムとOLTP、つまりトランザクション系のDBは、その外部にある。オンプレかもしれないし、AWS・GCP・Azureといったハイパースケーラかもしれない。
OLAPとOLTPのDBへデータを持ってくる必要があるので、FivetranやTroccoのようなELTツールでデータを移行させ、dbtなどでデータを整形して、BIダッシュボードで見たり、レポーティングしたり、Salesforceなどオペレーション系のシステムにデータを提供したりしているかも。
OLAP系のシステムでは、Icebergなどのテーブルフォーマットが普及して、分析系のシステムではデータの相互運用性が高まっているかもしれません。
さらにデータ分析基盤側にはStreamlitのようなインタラクティブにデータを可視化するツールが利用できるようになったり、LLMやAIエージェントが手軽に利用できる仕組みができてきました。
一方で、オペレーション系とアナリティクス系でDBがサイロ化している現状には違いなく、密な連携が困難な状況です。

# 元ネタ記事の内容
元ネタはこちらの原稿です。
https://zenn.dev/yohei/articles/2025-06-14-postgres-snowflake-databricks

# 参考文献
必要に応じて記事の元ネタも参照してください。

SnowflakeによるSnowflake Postgresの発表 
https://www.snowflake.com/en/blog/snowflake-postgres-enterprise-ai-database/

Snowflakeによる買収発表

Crunchy Data による買収発表
https://www.crunchydata.com/blog/crunchy-data-joins-snowflake


DatabricksによるLakebaseの発表
https://www.databricks.com/blog/announcing-lakebase-public-preview

DatabricksによるNeon買収発表
https://www.databricks.com/blog/databricks-neon
