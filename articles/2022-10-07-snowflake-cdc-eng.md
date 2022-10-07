---
title: "Why high frequent data loading to Snowflake table is expensive?"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: false
---

# Background

![DMS snowpipe](https://storage.googleapis.com/zenn-user-upload/3ab8b4ca834d-20220928.png)

AWS DMS and Snowpipe would be very popular tool when you replicate data from on-premise or AWS RDS database to Snowflake table for the following reasons.

* AWS DMS (Data Migration Service) is AWS's official database migration service.
* AWS DMS does not support Snowflake but can export data to S3 bucket.
* Once new file is upload in S3 bucket, Snowpipe can load the file to target Snowflake table immediately.

ただし、このアプローチをとった場合、Snowpipe でロードした先のテーブルにはデータソース側のテーブルの全履歴が残ります。
データ分析をやる上では、全履歴ではなく主キーごとに最新のレコードが知りたいので、Snowflake 側で Stream と Task などを用いて、履歴からデータソース側のテーブルの最新状態を再現する必要があります（以下の図の上側のパイプライン）。

![CDC](https://storage.googleapis.com/zenn-user-upload/4493c01e43a7-20221007.png)

Snowipe は比較的安価なのでコスト効率が高いアプローチですが、単に同期したいだけなのに履歴を移行して、さらに元のテーブルを再現する必要がある点は開発効率が悪いとも思えます。

データソース側の DB に付属したマイグレーションツールがたまたま Snowflake をサポートしていることに気付いたので、上の図の下側のパイプラインのように、直接、Snowflake に同期した方が良いと考え、PoCをやってみたところ、実はウェアハウスコストが予想より格段に高くなることに気付いたので、調査して今回の記事にしました。

なお、下側のアプローチは、Fivetran など ETL の SaaS を使った場合でも起こりうる問題なので、特定の DB やツールの問題ではありません。

# なぜ高頻度で書き込むとウェアハウス代が高くなったか？

* (1) DMS と Snowpipe
* (2) DB のマイグレツールで直接同期

のウェアハウスの使われ方の違いを比較すると、(1) の方は Snowpipe を使っており、Snowflake 内部で管理されているウェアハウスが利用され、勝手にコスト最適になるように調整されていたため、非常にインフラコストが安くなっていました。Snowpipe のコスト面は以下のドキュメントを参照ください。

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
