---
title: "AWS DMS と Snowpipe を活用した Snowflake 用リアルタイムデータパイプラインの構築"
emoji: "❄️"
type: "tech"
topics: [snowflake,rds,dms,datawarehouse,データウェアハウス]
published: false
---

![Snowflake](https://storage.googleapis.com/zenn-user-upload/uo9gtabf5bsfbcs5cievdqfjw0lh)

(画像は [Snowflake 公式 Web サイト](https://www.snowflake.com/)のものを流用)

# 概要

データエンジニアとして働いていると RDB 上での変更をリアルタイムで近い形でデータウェアハウスに転送し、即座にデータ分析に利用できるようにしたいというニーズについて相談を受ける機会があります。本記事では、以下の構成でニアリアルタイムデータパイプラインを構築する方法について紹介します。

* DB・・・AWS RDS Aurora (MySQL & PostgreSQL)
* DWH・・・Snowflake
* データパイプライン・・・AWS DMS (Database Migration Service)、S3、Snowpipe

# RDB からのリアルタイムデータパイプライン構築に対する一般的なアプローチ

RDB の変更をリアルタイムに取得して外部に転送するやり方を一般的に Change Data Capture (CDC) と言います。CDC はレプリケーションの技術を応用したテクニックであり、昔から存在してきました。リアルタイムな事象に対するデータ分析のニーズが増えてきているので、多くの企業がトランザクション系の DB から CDC で最新の変更を取得し、リアルタイムにデータ分析をしたり、DWHに格納したりしています。

MySQL や PostgreSQL など DBMS によって内部の仕組みは異なりますが、CDC を利用する立場から見た外部の振る舞いは同様です。 

https://hevodata.com/blog/postgresql-cdc/
https://hevodata.com/learn/mysql-cdc/

OSS を中心に CDC を実装するときによく利用されるソフトウェアが以下の記事にある　Kafka と [Debezium](https://debezium.io/) です。Debezium は Redhat が中心になって開発されているアプリケーションです。プラグインアーキテクチャをサポートしており、データソースとして主要な OSS の RDB をサポートしていますし、転送先として RDB だけでなく主要な DWH もサポートしています。

https://www.tigeranalytics.com/blog/building-nrt-data-pipeline-debezium-kafka-snowflake/

![Debezium CDC](https://storage.googleapis.com/zenn-user-upload/7dgpchrf2q2jiraqpufoiu4httjt)

前職で CDC によるリアルタイムデータパイプラインを構築した際は、以下のツールの組み合わせで構築しました。

* DB・・・AWS RDS Aurora PostgreSQL
* DWH・・・BigQuery
* データパイプライン・・・Debezium、Kafka（AWS EKS上にデプロイ）

この構成は一から作ろうと思うと大変ですが、当時の会社には k8s に精通した DevOps Engineer が 2 名在籍していたため、すでに Kafka と Debezium は簡単にデプロイできる状態だったため、私は主に BigQuery の DDL や Debezium の設定を担当しました。OSS 中心で k8s や Kafka を使っている人には合理的な選択です。

# 今回 AWS DMS と Snowpipe を採用した理由

一方で、現職は以下の構成です。Kafka も k8s も使っていないので、Debezium を簡単には利用できません。よって、RDS 上の変更をニアリアルタイムで Snowflake に取り込みたいと相談を受けた時、前職と同じアプローチは合理的ではないと判断し、AWS と Snowflake の標準サービスの範囲内で同じようなことができる方法を探しました。

* RDB・・・AWS RDS Aurora (MySQL と PostgreSQL)
* コンテナ・・・AWS ECS Fargate
* DWH・・・Snowflake

そこで見つけたのが以下の組み合わせです。

* AWS DMS を使い、RDS 上の変更を CDC スタイルで取得し、S3 に出力する。
* Snowpipe を使って S3 上に新規ファイルがアップロードされたら自動的にテーブルに取り込む。

![DMS と Snowpipe](https://storage.googleapis.com/zenn-user-upload/805ocwa3kpw1suts6ap3zfef1p0d)

AWS DMS は本来は RDB のマイグレーションを実現するためのサービスですが、上記のような CDC のアプローチで RDS 上の変更を取り込んで AWS S3 にデータを出力することが可能です。サービスの概要は以下を参照ください。

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.html

また、Snowpipe は Snowflake のサービスであり、AWS S3 などオブジェクトストレージへのファイルアップロードをトリガとしてテーブルへのデータ取り込みを実行できます。サービスの概要は以下を参照ください。

https://docs.snowflake.com/en/user-guide/data-load-snowpipe.html


# AWS DMS と Snowpipe を利用するメリット

k8s 上に Kafka と Debezium をデプロイして CDC をやる方法と比べた、AWS DMS と Snowpipe のアプローチのメリットは以下の通りです。

* AWS DMS、AWS S3、Snowpipe などフルマネージドのサービスだけで実現できるので、EKS や ECS などのクラスタ管理が一才不要です。コンテナクラスタ管理ツールに精通したインフラや DevOps のエンジニアがいなくても利用できます。
* AWS DMS は AWS の、Snowpipe は Snowflake の標準サービスのため、設定や障害などで困った場合は、サポートに問い合わせできます。

Debezium を使ったアプローチは Kafka Connector のホストから内部的に Snowpipe で上げているため、オブジェクトストレージを使わない分、転送のレイテンシが小さい可能性がありますが、大きなデメリットはないように思います。
