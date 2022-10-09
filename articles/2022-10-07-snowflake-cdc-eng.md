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
* (2) Dorect table sync by DB migration tool

If you compare how warehouse is used in these 2 approaches, you would notice that (1) Snowpie approach uses Snowflake managed warehouse, which automatically optimize computing resources used in your workload and computing cost. This can reduce warehouse cost. See below URL for more abuot Snowpipe cost.

https://docs.snowflake.com/en/user-guide/data-load-snowpipe-billing.html

一方で、(2) の方は、ユーザ管理のウェアハウスをマイグレツールのユーザに割り当てることになるため、ツールがテーブルに書き込む際にユーザ管理のウェアハウスを起動することになります。

このツールのウェアハウスは以下の設定になっていたため、高頻度（例えば、毎分）で書き込みを行うと、ウェアハウスが起動しっぱなしになっていました。また、自動停止待ち時間が過ぎるまでに次の書き込みが来ると、スケールポリシーにより、新しいクラスタが起動されていることもありました。

* マルチクラスターウェアハウス・・・クラスタの数が複数
* スケールポリシーはデフォルト・・・キューの待ち時間を最小にするため、なるべく新しいクラスタを立ち上げようとする
* 自動停止待ち時間が15分

Snowflake のウェアハウスコストは、データ量ではなく、ウェアハウスのサイズ * 起動してる総時間で決まります。よってデータ量が少量であっても、より多くのウェアハウスがより長く走ってしまうと、ウェアハウスコストがかさんでしまいます。

ウェアハウスのコスト計算の仕組みは以下が参考になるので、参照ください。

https://docs.snowflake.com/en/user-guide/credits.html
https://docs.snowflake.com/en/user-guide/warehouses-considerations.html

# では ETL のウェアハウスコストを下げるにはどうしたら？

Snowflake のウェアハウスコストは、データ量ではなく、ウェアハウスのサイズ * 起動してる総時間で決まる点は、先ほど説明しました。

この価格モデルだと少量のデータを処理するのは非常に効率が悪いので、本当にリアルタイムである必要があるのかよくよく考えて、更新頻度は下げた方が良いと思います（日次、毎時など）。その上で一気にデータを書き込み、終わったらウェアハウスを停止するのが良いでしょう。

その際、以下は設定を変えられるので、コスト優先の場合は変えてもいいでしょう。ただし、あまりクラスタを起動させず、かつすぐにクラスタを停止させる設定にすると、性能は落ちるのでジョブのレイテンシは上がると思います。その点も検討に入れておくと良いでしょう。

* スケールポリシーをエコノミーにする・・・なるべく新しいクラスタを立ち上げないようにする
* 自動停止待ち時間を短くする

# おわりに

今回は、ETL ツールを使った場合のウェアハウスコストについて注意点を紹介しました。コスト最適化は日常的にやってるので、また気付いた知見あれば紹介します。
