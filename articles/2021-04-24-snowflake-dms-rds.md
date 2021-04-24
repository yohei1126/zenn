---
title: "AWS DMS と Snowpipe を活用した Snowflake 用リアルタイムデータパイプラインの構築"
emoji: "❄️"
type: "tech"
topics: [aws,snowflake,rds,datawarehouse,データウェアハウス]
published: true
---

![Snowflake](https://storage.googleapis.com/zenn-user-upload/uo9gtabf5bsfbcs5cievdqfjw0lh)

(画像は [Snowflake 公式 Web サイト](https://www.snowflake.com/)のものを流用)

# 概要

データエンジニアとして働いていると RDB 上での変更をリアルタイムで近い形でデータウェアハウスに転送し、即座にデータ分析に利用できるようにしたいというニーズについて相談を受ける機会があります。
筆者は、RDB からデータウェアハウスの間のリアルタイムデータパイプライン部分を OSS 中心とクラウドサービス中心の 2 つの構成で構築した経験があります。その際の経験を踏まえて、両者の簡単な比較について紹介します。

* （前職）OSS 中心のデータパイプライン
  * RDB・・・AWS RDS Aurora (PostgreSQL)
  * BigQuery
  * データパイプライン・・・Kafka、Debezium
  * コンテナオーケストレーション・・・データパイプラインを AWS EKS 上 k8s クラスタにデプロイ
* （現職）クラウドサービス中心のデータパイプライン
  * RDB・・・AWS RDS Aurora (MySQL & PostgreSQL)
  * DWH・・・Snowflake
  * データパイプライン・・・AWS DMS (Database Migration Service)、S3、Snowpipe

# RDB からのリアルタイムデータパイプライン構築に対する一般的なアプローチ

RDB の変更をリアルタイムに取得して外部に転送するやり方を一般的に Change Data Capture (CDC) と言います。CDC はトランザクションログをレプリケーションする技術を応用したテクニックであり、昔から存在してきました。リアルタイムな事象に対するデータ分析のニーズが増えてきているので、多くの企業がトランザクション系の DB から CDC で最新の変更を取得し、リアルタイムにデータ分析をしたり、DWHに格納したりしています。

MySQL や PostgreSQL など DBMS によって内部の仕組みは異なりますが、CDC を利用する立場から見た外部の振る舞いは同様です。 

https://hevodata.com/blog/postgresql-cdc/
https://hevodata.com/learn/mysql-cdc/

OSS を中心に CDC を実装するときによく利用されるソフトウェアが以下の記事にある　Kafka と [Debezium](https://debezium.io/) です。Debezium は RDB のデータを Kafka トピックに取り込むための Kafka Connect の実装の 1 つです。Redhat が中心になって OSS として開発されています。データソースとして主要な OSS の RDB をサポートしています。Kafka から主要な DWH へのデータ転送をサポートする Kafka Connect も存在するため、これらを組み合わせると Kafka を開始て、RDB から DWH へリアルタイムでデータを転送できます。

https://www.tigeranalytics.com/blog/building-nrt-data-pipeline-debezium-kafka-snowflake/

![Debezium CDC](https://storage.googleapis.com/zenn-user-upload/7dgpchrf2q2jiraqpufoiu4httjt)

前職で CDC によるリアルタイムデータパイプラインを構築した際は、以下のツールの組み合わせで構築しました。

* DB・・・AWS RDS Aurora (PostgreSQL)
* DWH・・・BigQuery
* データパイプライン・・・Debezium、Kafka
* コンテナオーケストレーション・・・データパイプラインを AWS EKS 上 k8s クラスタにデプロイ

この構成は一から作ろうと思うと大変ですが、当時の会社には k8s に精通した DevOps Engineer が 2 名在籍していたため、すでに Kafka と Debezium は簡単にデプロイできる状態でした。よって、私は主に BigQuery の DDL や Debezium の設定を担当しました。OSS 中心で k8s や Kafka を使っている人には合理的な選択です。

# 今回 AWS DMS と Snowpipe を採用した理由

一方で、現職は以下の構成です。Kafka も k8s も使っていないので、Debezium を簡単には利用できません。よって、RDS 上の変更をニアリアルタイムで Snowflake に取り込みたいと相談を受けた時、前職と同じアプローチは合理的ではないと判断し、AWS と Snowflake の標準サービスの範囲内で同じようなことができる方法を探しました。

* RDB・・・AWS RDS Aurora (MySQL)
* コンテナ・・・AWS ECS Fargate
* DWH・・・Snowflake

そこで見つけたのが以下の組み合わせです。

* AWS DMS を使い、RDS 上の変更を CDC スタイルで取得し、S3 に出力する。
* Snowpipe を使って S3 上に新規ファイルがアップロードされたら自動的にテーブルに取り込む。

![DMS と Snowpipe](https://storage.googleapis.com/zenn-user-upload/805ocwa3kpw1suts6ap3zfef1p0d)

AWS DMS は本来は RDB のマイグレーションを実現するためのサービスですが、RDS 意外にも S3 や Kinesis など多様なサービスにデータを出力することが可能です。サービスの概要は以下を参照ください。

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.html

また、Snowpipe は Snowflake のサービスであり、AWS S3 などオブジェクトストレージへのファイルアップロードをトリガとしてテーブルへのデータ取り込みを実行できます。サービスの概要は以下を参照ください。

https://docs.snowflake.com/en/user-guide/data-load-snowpipe.html


# AWS DMS と Snowpipe を利用するメリット・デメリット

k8s 上に Kafka と Debezium をデプロイして CDC をやる方法と比べた、AWS DMS と Snowpipe のアプローチのメリットは以下の通りです。

* AWS DMS、AWS S3、Snowpipe などフルマネージドのサービスだけで実現できるので、EKS や ECS などのクラスタ管理が一才不要です。コンテナクラスタ管理ツールに精通したインフラや DevOps のエンジニアがいなくても利用できます。
* AWS DMS は AWS の、Snowpipe は Snowflake の標準サービスのため、設定や障害などで困った場合は、サポートに問い合わせできます。

一方でデメリットは、以下の通りです。

* オブジェクトストレージを使っている分、データ転送による多少のレイテンシ増加が考えられます。これは、Debezium を使ったアプローチの方は、Kafka Connector のホストから内部的に Snowpipe で上げており、間にオブジェクトストレージを経由していないためです。
* AWS 固有のサービスであり、AWS 以外の場所では使えません。ただし、同様のサービスが GCP にも存在するので、別のクラウドサービスを使わざるを得ない場合は、そのクラウド固有のもので代替できます。

# DMS を使ったデータパイプラインの構成

DMS を使ったデータパイプラインの構成は以下の図の通りです。

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Components.html

* DMS のデータ転送処理を行うインスタンス（Replication Instance）を作成します。実体は EC2 です。
* データ転送元（Source）の DB に対してエンドポイントを作成します。現職の場合は、データ転送元は RDS Aurora MySQL です。
* データ転送先（Target）に対してもエンドポイントを作成します。現職の場合は、データ転送先は S3 です。
* インスタンスは土台、エンドポイントは出入口に相当し、実際の転送処理はタスク（Replication Task）です。インスタンス、エンドポイントを指定して、タスクを作成するとインスタンスにデプロイされます。タスクを開始すると実際にデータ転送を開始します。

![DMSの構成](https://storage.googleapis.com/zenn-user-upload/v0o71drzl6mzs5nd709r865sqf6h)

# RDS Aurora MySQL に対してソースエンドポイントを作成する

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.MySQL.html#CHAP_Source.MySQL.AmazonManaged

* RDS Parameter Group を変更する必要がありますので、現在利用しているバージョンと適合するデフォルトのパラメタグループから新規作成し、以下を変更してください。
  * `binlog_format` = `ROW`
  * `binlog_checksum` = `NONE`
* Aurora の場合、レプリケーションで参照する binlog が即座に消されてしまうため、リテンションの期間を変更する必要があります。Admdin 権限のユーザで以下を実行してください。
```
call mysql.rds_set_configuration('binlog retention hours', 24);
```
* 新しいパラメタグループを対象のクラスタに適用した状態で再起動すると、新規のパラメタが適用されます。
* セキュリティグループのレベル、MySQL のサーバインスタンス内のレベルの両方で通信を許可する必要があります。DMS のインスタンスから通信を受けられるように設定しておきましょう。

# S3 に対してターゲットエンドポイントを作成する

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.S3.html

私が今回構築する際は以下の設定にしました。

* フォーマットは Apache Parquet にしました。CSV ファイルに対してきっちりテーブルスキーマを作ると、将来的にスキーマ変更があるとスキーマ不適合でパイプラインが壊れる可能性があります。Parquet フォーマットにしておくと Snowflake テーブルの VARIANT 型カラムにデータを投入できます。
* date-based folder partitioning を有効にして、CDC の際にオブジェクトキーに日付別階層を入れられるようにしました。単純に探しやすさのため、後々、もし Athena や Glue でデータを利用する際にテーブルをパーティショニングしやすくするためです。
* その他はドキュメントを参照して要件に合うものを選んでください。

# DMS インスタンスを作成する

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.html

* RDS にアクセスする EC2 インスタンスを作成するのと同じですので、ネットワーク的に RDS と疎通できる VPC にデプロイし、適切なセキュリティグループを設定しましょう。
* 本番環境の場合は、Multi AZ は有効にしておきましょう。有効にすると稼働中のインスタンスとは別の AZ にスタンバイ用のレプリカが作成され、障害の際はフェイルオーバできるようになります。
* 外部インターネットへの公開は必要ないはずなので OFF にしておきましょう。

# DMS タスクを作成する

DMS タスクについては以下を参照ください。

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.html

* マイグレーション方法・・・マイグレーションの種類として、最初にDBにある履歴をフルダンプする Full load、変更だけ抽出する CDC の 2 通りがあります。二つを組み合わせ、Full load のみ、CDC のみ、両方が選べます。
* テーブルマッピング・・・マイグレーション対象のテーブルの選定方法、データ変換方法などが指定できます。私の場合は、とりあえず特定の DB 配下のテーブルはすべてそのまま抽出したかったので、データベース名だけ指定して、変換は指定しませんでした。CDC で読むトランザクションログは 1 枚のテープを前から読んでいくようなものなので、後からテーブルを追加することができません。よって全て出しておいて、Snowflake のテーブルに上げる対象を後で決める方が合理的でしょう。

タスクができたら、タスクを開始すると Full load が始まり、 CDC のモードに切り替わり、変更がある度に DMS 経由で S3 に出力されるようになります。

# Snowpipe を作成する

Snowpipe については以下に詳しく書かれていますので、参照ください。

https://docs.snowflake.com/en/user-guide/data-load-snowpipe.html

Snowpipe は S3 イベントを SQS キューもしくは SNS トピックを通じて Snowflake バックエンドに転送することで、イベント駆動でテーブルへの COPY コマンドを発行する仕組みです。 
DMS を通じて新しいデータが S3 に出力される度に、Snowpipe を通じて、テーブルへのデータ COPY が実行されます。

注意事項としては、Snowpipe 自身も状態を持っていて、RUNNING 以外の時はデータの取り込みが停止されています。DMS でデータ転送する際は Snowpipe が稼働しているか確認しましょう。

# おわりに

手短ではありますが、筆者の経験を元に主に AWS 上で RDS から Snowflake へのリアルタイムデータパイプラインを構築する方法について紹介しました。

以下の通り、2 通りのやり方を示し、今回は後者を楽にやる方法について紹介しました。

* k8s や Kafka を積極的に使っている方は OSS 中心版
* なるべく自前でクラスタ管理や運用をしたくない方はクラウドサービス中心版

データエンジニアはやること多いと思いますので、あまり自社のコアビジネスに関係ない細かいことはあまり手間をかけずに楽に実現できる方法を取るのが良いと思います。その分で浮いた時間をビジネスに貢献する作業に充てると社内で喜ばれるのではと思います。

以上、本記事が皆様のお仕事のお役に立てたら幸いです。ありがとうございました。
