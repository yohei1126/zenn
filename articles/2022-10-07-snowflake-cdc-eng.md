---
title: "Why high frequent data loading is expensive in Snowflake?"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: false
---

# Background

![DMS snowpipe](https://storage.googleapis.com/zenn-user-upload/3ab8b4ca834d-20220928.png)

AWS DMS and Snowpipe would be one of the most popular tools when you replicate data from on-premise database or AWS RDS database to Snowflake table in near real time because of the following reasons.

* AWS DMS (Data Migration Service) is AWS's official database migration service.
* AWS DMS does not support Snowflake but can export data to S3 bucket.
* Once new file is upload in S3 bucket, Snowpipe can load the file to target Snowflake table immediately.

If you choose this approach, you will load entire transaction history of the source table to target table. You would also want to know the latest records for each primary key or unique key instead of entire history. Then you need to maintain the latest records in another table using Stream and task just like the upper pipeline in the following diagram.

![CDC](https://storage.googleapis.com/zenn-user-upload/4493c01e43a7-20221007.png)

This is cost-efficient approach as compute cost for Snowpipe is quite cheap, but you might feel you do not want to implement Stream and task just to replicate data.

Some RDBMS also provides database migration tool that can directly sync source table to target table in Snowflake just like the lower pipeline in the above diagram. This can reduce development cost compared with DMS and Snowpipe approach, so I tried this in my project, but it turns out that warehouse cost for this type of high frequent data loading is quite expensive.

This issue would also happen when you use ETL service like Fivetran. It is not an issue on specific tool. I will explain why high frequent data loading is expensive in this article.

# Why warehouse cost for high frequent data loading was expensive?

* (1) DMS and Snowpipe
* (2) Direct table sync by DB migration tool

If you compare how warehouse is used in these 2 approaches, you would notice that (1) Snowpipe approach uses Snowflake managed warehouse, which automatically optimize computing resources used in your workload and computing cost. This can reduce warehouse cost. See below URL for more about Snowpipe cost.

https://docs.snowflake.com/en/user-guide/data-load-snowpipe-billing.html

On the other hand, (2) direct table sync by DB migration tool uses a user managed warehouse. In our project, default configurations for the warehouse was like follows. If the tool loads data frequently such as every minute, it would keep the warehouse running. Snowflake also start new warehouse when new data comes in before the auto suspend time has passed.

* Multi cluster warehouse 
* Default scaling policy: Snowflake tries to keep latency minimum by starting a new warehouse
* Default auto suspend time: 10 minutes

Snowflake warehouse cost is calculated based on warehouse size * a number of warehouses * duration of warehouse running instead of data volume. Even if data volume is small, warehouse cost would increase if more warehouses runs in longer time. See the below URLs for more about warehouse cost.

https://docs.snowflake.com/en/user-guide/credits.html
https://docs.snowflake.com/en/user-guide/warehouses-considerations.html

# How can we do to reduce warehouse cost?

Snowflake のウェアハウスコストは、データ量ではなく、ウェアハウスのサイズ * 起動してる総時間で決まる点は、先ほど説明しました。

この価格モデルだと少量のデータを処理するのは非常に効率が悪いので、本当にリアルタイムである必要があるのかよくよく考えて、更新頻度は下げた方が良いと思います（日次、毎時など）。その上で一気にデータを書き込み、終わったらウェアハウスを停止するのが良いでしょう。

その際、以下は設定を変えられるので、コスト優先の場合は変えてもいいでしょう。ただし、あまりクラスタを起動させず、かつすぐにクラスタを停止させる設定にすると、性能は落ちるのでジョブのレイテンシは上がると思います。その点も検討に入れておくと良いでしょう。

* スケールポリシーをエコノミーにする・・・なるべく新しいクラスタを立ち上げないようにする
* 自動停止待ち時間を短くする

# おわりに

今回は、ETL ツールを使った場合のウェアハウスコストについて注意点を紹介しました。コスト最適化は日常的にやってるので、また気付いた知見あれば紹介します。
