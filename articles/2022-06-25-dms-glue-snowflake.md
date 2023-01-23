---
title: "AWS DMS と Glue を利用した Snowflake への DB マイグレーションコストの最適化"
emoji: "❄️"
type: "tech"
topics: [snowflake,aws,dms,glue,db]
published: true
publication_name: "dataheroes"
---

![Snowflake](https://storage.googleapis.com/zenn-user-upload/uo9gtabf5bsfbcs5cievdqfjw0lh)

(画像は [Snowflake 公式 Web サイト](https://www.snowflake.com/)のものを流用)

# 本記事の概要

本記事では、以下の2つのアプローチを組み合わせ、AWS 上で OLTP 系 DB （PostgreSQL や MySQL）から Snowflake へデータを移行する際のコストを最適化した事例について紹介します。

* CDC（ニアリアルタイム）・・・AWS DMS と Snowpipe 
* 差分ロード、全件ロード・・・Glue

# 記事の背景

## AWS DMS と Snowpie でニアリアルタイムな RDB マイグレーション用のパイプラインを構築した

以前、AWS RDS のデータベース上の変更をニアリアルタイムで Snowflake に反映させたいという社内からの依頼を受け、AWS DMS と Snowpipe を使ってデータパイプラインを構築しました。DMS は CDC (Change Data Capture) に対応し、データのマイグレーション先として S3 を指定できるため、データベース上の変更を一定時間以内に S3 バケット上に抽出することができます。また、Snowpipe を利用すると、Snowipe に登録した COPY コマンドで S3 バケットに配置したファイルをテーブルに自動ロードできます。

https://zenn.dev/yohei/articles/2021-04-24-snowflake-dms-rds

## ビューに CDC が利用できず、Full Load Task を検討 

上記の CDC パイプラインを導入後、その他のデータベースにも導入したいとの要望があり、オンプレのデータベースもマイグレ対象に拡大しました。この時、オンプレ DB 側を担当していた同僚から指摘されたのは、「Oracle のビュー経由でデータを移行したいが、DMS CDC task はビューをサポートしていない」というものでした。

(この時、私自身が CDC でサポートできない理由は調査していませんが、おそらく CDC は DB のトランザクションログを利用しており、トランザクションログはテーブルに対してのみ存在しているため、ビューに対しては CDC タスクを実行できないのだと解釈しました。)

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Task.CDC.html

チームで議論した後、DMS でデータを抽出した後、Snowpipe でデータを Snowflake に吸い上げる手法は確立しているので、DMS のもう1つのタスク種別である Full Load Task を定期実行し、ビューからデータを S3 へ抽出しようという結論になりました。

https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Tasks.CustomizingTasks.TaskSettings.FullLoad.html

# 課題： DMS Full Load Task のメモリ使用量に対応するため DMS インスタンスをスケールアップすることでインフラ費用が割高になった

DMS Full Load Task でビューからのデータ移行もできると決着しましたが、ここで大きな問題が出てきました。

DMS Full Load Task は移行元テーブルやビューのデータ全量を DMS インスタンスのメモリにロードしようとするため、差分移行の CDC と比べると大量のメモリを使用してしまいます。メモリ不足でタスクがエラーになるのを防ぐには、十分なメモリ量を確保できる大きなインスタンスにスケールアップする必要があります。

しかし、Full Load Task の大半は1日1回だけやれば十分なものが多かったため、普段はあまりメモリを使用していないのにインスタンス代が高額になるというコスパが悪い状況になることが分かりました。

![メモリ使用量が割高に](https://storage.googleapis.com/zenn-user-upload/5712f6dbb18d-20220717.png)

# 解決策: DMS CDC Task でサポートできないデータは AWS Glue で移行する

ここで、コスト削減のため、DMS CDC で対応できないケースについては、AWS Glue で移行することにしました。

https://aws.amazon.com/jp/glue/

Glue を使うと、カスタム実装が必要になりますが、PySpark を使って移行元の DB には JDBC 接続し、全件移行したり、タイムスタンプを見て差分移行したりするジョブを実装できます。

Glue ジョブを実装にあたっては、データソースごとにジョブを実装しなくても良くするため、様々なデータベースや多様な移行方法（全件移行、差分移行）に対応できるよう再利用可能なジョブにしました。また、ジョブスケジューラである Airflow で定期実行するバッチジョブとして作成しました。

将来的な障害時の検証などに利用することを想定し、ジョブで抽出したデータは S3 に書き出し、Snowpipe ではなくバルクロードで Snowflake にデータを入れる方式を取りました。

# 効果: DMS Full Load Task を Glue に移行することで DMS インスタンスをスケールダウンできた

DMS Full Load Task で移行していた分は、Glue ジョブに移行することでジョブ実行時に使用したリソース分だけ費用を支払えばよく、DMS インスタンスも CDC タスクに耐えうるメモリ量のインスタンスにスケールダウンでき、全体のコストを低減できました。

なお、Glue ジョブの費用は以下にある通り、最低 2 DPU 必要であり、1DPU / 時間 = 0.44 USD 課金されます。常時稼働する DMS インスタンスをスケールアップするよりは大幅に割安です。

https://aws.amazon.com/jp/glue/pricing/
https://aws.amazon.com/jp/dms/pricing/


# まとめ

本記事では、AWS DMS CDC と Snowpipe でデータベースをニアリアルタイムにデータ移行していたプロジェクトにおいて、CDC タスクが対応できないデータソースについて Glue ジョブを利用することで、DMS インスタンスを必要最低限のサイズに留め、コストを最適化したことを説明しました。

# 後日談

と、ここまで色々と書いてきましたが、今、改めて冷静に見るとカスタム実装を色々頑張るよりは、最近人気の ETL ツールである Fivetran や Airbyte を導入し、出来合いのコネクタを使って移行する方が 100 倍楽だと思っています ~~; 

（ただし、その際はコストの観点で SaaS 方式の従量課金モデルが望ましいと思います。自前でクラスタを組んだりすると、クラスタがある程度の規模にならないと、上記のDMS インスタンススケールアップが割高になったのと同じ問題が発生します。）

本プロジェクトを始めた当初は、これらのツールの存在を知らなかったので、AWS のサービスだけで頑張ってきましたが、長期的に楽をするため、どこかの段階で既存の ETL ツールを導入しようと思っています。評価次第、また所感を記事に書きたいと思います。

https://www.fivetran.com/
https://airbyte.com/