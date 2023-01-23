---
title: "Snowflake: The Definitive Guide 読書メモ"
emoji: "❄️"
type: "tech"
topics: [snowflake,book]
published: true
publication_name: "dataheroes"
---

本記事は、2022 年 9 月に O'Reilly Media 社より出版予定の "Snowflake: The Definitive Guide: Architecting, Designing, and Deploying on the Snowflake Data Cloud" の読書メモです。各章を読み次第、メモを追記していきます。

* https://learning.oreilly.com/library/view/snowflake-the-definitive/9781098103811/
* https://www.amazon.co.jp/dp/1098103823/
* https://www.amazon.com/dp/1098103823/

# 著者について

* 著者の Joyce Kay Avila は SpringML 社という Snowflaek の技術パートナー企業で、Snowflake および AWS、Salesforce などの導入のコンサルティングを行なっている方。
* また、2022 年の Data Superheroes （Snowflake コミュニティリーダー）の一人。　
* https://www.linkedin.com/in/joycekayavila
* https://community.snowflake.com/s/profile/0050Z000008mJdkQAE

# Chapter 1. Getting Started

* 第 1 章は Snowflake 社および製品の歴史や概要の紹介、Web UI を使ったチュートリアル、ユーザコミュニティ、認定試験などの紹介を扱っています。 

# Chapter 2. Creating and Managing the Snowflake Architecture

* 第 2 章は、過去の代表的なデータウェアハウスのアーキテクチャの概要や限界 Snowflake のアーキテチャの優位性の紹介をしている。
* 共有ディスクアーキテクチャ - Shared Disk (Scalable) Architecture
  * 初期に採用されたスケーリングのためのアプローチ
  * 中央ストレージがコンピュートクラスタ（CPU、メモリ）と分離されている。中央ストレージ上の共有ディスクにデータが書き込まれるため、コンピュートクラスタから見ればデータの一貫性が担保される。
  * 理論的にデータ管理がシンプルである反面、データ一貫性維持のためディスクロックの仕組みが必要になり、小ンピュートクラスタを拡張しても処理能力がスケールしない。
* 共有なしアーキテクチャ - Shared-Nothing (Scalable) Architecture
  * 共有ディスクアーキテクチャの限界に応えるため、設計された。MPP（massively parallel processing）とも呼ばれる。例としては、IBM DB2, Vertica, and Pivotal Greenplumなど。
  * クラスタノードがCPU、メモリ、ディスクを保有しており、ストレージとコンピュートが共にスケールする。
  * ただし、ノード間でデータのシャッフルが必要になり、これがオーバヘッドとなる。
  * ストレージとコンピュートのバランスが非常に難しく、クラスタのリサイズに時間がかかる。多くの場合、過剰にプロビジョニングされてしまい、使用されない計算リソースが出てしまう。
* NoSQL
  * 多くの場合、共有なしアーキテクチャを採用しており、同様の制限がある。
  * 利点としては、データの変換なしにデータベースにデータをロードできる。スキーマを必要としない。
  * 種類：
    - document stores - MongoDB
    - key-value (KV) stores - DynamoDB
    - column family data stores - Cassandra
    - wide column data stores
    - graph databases - Neo4j, AWS Neptune
  * 大量レコードを処理する際のパフォーマンスが貧弱。
  * テーブルの個別レコードに対する CRUD には良いが、アドホック分析には向かない。
* Snowflake Architecture 
  * 以下の URL の内容とほぼ同じ。より細かく書かれている印象。Shared-Nothing (Scalable) Architecture からの改善内容については明示的に書かれていません。
  * Key concepts https://docs.snowflake.com/en/user-guide/intro-key-concepts.html
  * Virtual warehouse https://docs.snowflake.com/en/user-guide/warehouses.html
  * Multi cluster warehouse https://docs.snowflake.com/en/user-guide/warehouses-multicluster.html
  * Understanding Virtual Warehouse, Storage, and Cloud Services Usage https://docs.snowflake.com/en/user-guide/credits.html
  * Zero copy cloning https://docs.snowflake.com/en/user-guide/tables-storage-considerations.html#label-cloning-tables
  * Time Travel https://docs.snowflake.com/en/user-guide/data-time-travel.html
  * Caching in Snowflake Warehouse https://community.snowflake.com/s/article/Caching-in-Snowflake-Data-Warehouse

# Chapter 3. Creating and Managing Snowflake Securable Database Objects

# Chapter 4. Exploring Snowflake SQL Commands, Data Types, and Functions

# Chapter 5. Leveraging Snowflake Access Controls

# Chapter 6. Data Loading and Unloading

# Chapter 7. Implementing Data Governance, Account Security, and Data Protection & Recovery

# Chapter 8. Managing Snowflake Account Costs

# Chapter 9. Analyzing and Improving Snowflake Query Performance

# Chapter 10. Configuring and Managing Secure Data Sharing

# Chapter 11. Visualizing Data in Snowsight

# Chapter 12. Workloads for the Snowflake Data Cloud


