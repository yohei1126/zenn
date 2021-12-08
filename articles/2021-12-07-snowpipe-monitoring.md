---
title: "Airflow と Snowpipe REST API を使った Snowpipe ステータスモニタリング"
emoji: "❄️"
type: "tech"
topics: [snowflake,devops]
published: false
---

# 本記事の背景

## データサイエンティストからの要望で AWS DMS と Snowpipe によるリアルタイムデータパイプラインを導入した

筆者の所属では、当初、Snowflake を導入した際は、Airflow による日次 or 週次バッチジョブで COPY コマンドを実行して、Snowflake へデータを投入していました。

https://docs.snowflake.com/en/sql-reference/sql/copy-into-table.html

しばらく経った後、データサイエンティストから AWS RDS の特定のテーブルへの変更をリアルタイムに近い形で Snowflake に取り込みたいという要望があり、DMS で CDC 方式で RDS の変更を取り込み、S3 へ吐き出し、Snowpipe で Snowflake にデータを取り込むパイプラインを導入しました。

https://zenn.dev/yohei/articles/2021-04-24-snowflake-dms-rds

## Snowpipe のエラーも自動的に検出できるようにしたい

この Snowpipe の方式は、Snowflake 側で自動的にデータを取り込んでくれる便利さの反面、バッグクラウンドプロセスのため、Python API で COPY コマンドを叩くのとは異なり、何らかのエラーが発生した場合でも即座にユーザにエラーを通知してくれません。

以下のページに Snowpipe のトラブルシューティング方法が掲載されていますが、`SYSTEM$PIPE_STATUS` や `COPY_HISTORY` などSQLを使って Snowpipe の履歴を調査することが推奨されています。つまり Snowpipe でエラーが起きているかどうかは SQL などを使い、能動的に履歴を調べる必要があります。

https://docs.snowflake.com/en/user-guide/data-load-snowpipe-ts.html

# Snowpipe 監視の要件

監視を実現するにあたって検討した要件は、以下の通りです。

* 設定に変更を加えなくても同一アカウント内の Snowpipe を全て検出する。
  * もし確認対象の Snowpipe をバッチジョブの設定ファイルに書き込む方式をとった場合、新規追加された Snowpipe を追加し忘れる可能性があります。
* Snowpipe の状態だけでなく、個別ファイルのロード結果も確認する。
  * 個別ファイルで失敗したものもあるけど、Snowpipe 自体は正常というケースもあることを想定し、個別の結果も把握した方が良いでしょう。
* Snowpipe 状態監視の頻度は1時間に1回。
* 現在、チームで使っているインシデント管理ツールを使いたい。
  * 筆者のチームでは、 Airflow によるバッチジョブについては、エラーをインシデント管理ツールである [Atlassian Opsgenie](https://www.atlassian.com/ja/software/opsgenie) に通知する仕組みを実現していましt。Snowpipe についても同様にエラーを検出して、インシデント管理ツールに通知する仕組みを作りたいと考えました。
  * （注）Grafanaでダッシュボードなども作っていますが、今回は関係なし。

![Snowpipe](https://storage.googleapis.com/zenn-user-upload/b231ee92e743-20211208.png)

# 全ての Snowpipe を抽出する

全ての Snowpipe を抽出する方法としては `SHOW PIPES` が利用できます。
https://docs.snowflake.com/en/sql-reference/sql/show-pipes.html

ただし、状態監視に使うユーザのロールが見える Snowpipe に限られてしまうので、監視用のユーザ・ロールを用意する際には全ての Snowpipe を閲覧できる設定にしておく必要があります。具体的には、少なくとも以下のページで `Pausing or Resuming Pipes` ができるロールをデフォルトロールにしておくと良いです。
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-intro.html#pipe-security

# Snowpipe 自体の状態、個別ロードの結果を確認する

先ほど紹介したトラブルシューティングのドキュメントでは、SQL で以下を調査することを推奨しています。
  * `SYSTEM$PIPE_STATUS` で Snowpipe 自体の状態
  * `COPY_HISTORY` で個別コピーの結果
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-ts.html

これとほぼ同様のことが Snowpipe REST API でも可能です。最初からJSONで結果をもらえるので、REST APIの方が便利かもしれません。
https://docs.snowflake.com/en/user-guide/data-load-snowpipe-rest-apis.html#load-history-reports

今回、状態監視に使いたいのは Load History Reports の方ですが、2つのエンドポイントがあり、それぞれ特性が異なるので、目的に合っているか確認しましょう。

* `insertReport`
  * `insertFiles` でロードされたファイルの履歴を取得できる。
  * 制約
    * 直近の 10,000 イベントを保持できる。
    * 最大10分イベントを保持できる。
* `loadHistoryScan`
  * `insertReport` と違い、指定した期間のロードされたファイルの履歴を取得できる。
  * 制約
    * 1回の呼び出しで、最大10,000件のイベントを取得できる。
    * API呼び出し回数に制限があるので、頻繁に呼び出す場合は `insertFiles` の方が推奨されている。
      * (OK) 8分おきに過去10分の履歴を取得する
      * (NG) 毎分、過去24時間分の履歴を取得する - エラー429が発生する
    * 制約なしに同じ情報を見たい場合は、SQL の `COPY_HISTORY` の利用が推奨されている。

今回は、1時間おきに状態を確認できれば良いので、保持機関の短い `insertFiles` よりも `insertReport` が良いと判断しました。

`loadHistoryScan` の