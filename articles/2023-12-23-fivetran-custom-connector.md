---
title: "Function as a Service を使った Fivetran カスタムコネクタの開発 - 実装上の TIPS"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [fivetran,snowflake]
published: true
publication_name: "dataheroes"
---

本記事は、 [Snowflake Advent Calendar 2023](https://qiita.com/advent-calendar/2023/snowflake) シリーズ 2 の 3 日目の記事です。

前回は、 Function As a Service を使った Fivetran のカスタムコネクタ開発の背景およびコネクタの概要について紹介しました。
https://zenn.dev/dataheroes/articles/2023-12-03-fivetran-custom-connector-dbt-snowlfake

本記事では、簡単な PoC をやった上で気づいた、実際に開発する上で重要になる点について紹介します。

# (1) state で処理済みのレコード位置を記録し、差分ロードに対応する

前回の記事でも Function が Fivetran から HTTP リクエストで受け取るフィールド、および HTTP リクエストで返すフィールドの両方に state があると記載しました。 

state は、ステートレスな function が処理経過を記録するための仕組みです。 state としてどこまで処理したか経過を記した情報を Fivetran と Function の間で共有することで、差分ロードを実現できます。

例えば、データソースのテーブルに更新タイムスタンプがあり、レコードが追加更新されると更新タイムスタンプが更新されるとします。この場合、テーブルごとの state として更新タイムスタンプを Fivetran と共有することで、次回、 function を起動した時に、前回の更新タイムスタンプより新しいタイムスタンプのレコードのみを取得することで、 Fivetran に渡すレコード数を減らすことができます。 Fivetran の価格モデルはレコード数課金のため、 Fivetran の利用料金を減らすことができます。

（参考）以下は公式ドキュメントにおける HTTP リクエスト側の解説:

https://fivetran.com/docs/functions

> state is a JSON object that contains cursors from the previous successful function execution. It is key to performing incremental updates. A cursor is a bookmark that marks the data Fivetran has already synced (for example, a timestamp, ID, or index). For the initial sync, state is an empty JSON object {}. Fivetran expects an updated state object in every response.
> IMPORTANT: The state object can't be NULL. If you perform a full re-sync, the state resets to {}. If there is an error during a full re-sync, Fivetran doesn't save intermediate data. To ensure data integrity, you must trigger the full re-sync again.

（参考）以下は公式ドキュメントにおける HTTP レスポンス側の解説:

> state contains the updated state value(s). Your response must always return an updated state to checkpoint the data fetched in the request.

# (2) 前回と今回の API 応答結果から削除されたレコードを見つける

次は、データソースから削除されたレコードを転送先に転送する方法について紹介します。

Fivetran の API では、 API 応答で delete というフィールドに削除されたレコードを指定することで、 Fivetran が転送先テーブルで論理削除の対応をしてくれます。つまり、物理的にはテーブルを削除しませんが、 _fivetran_deleted というカラムの値を true にすることで、論理的には削除されたレコードであることが分かる様にします。

この時、 Function はステートレスであるため、データソースからの API 応答だけではどのレコードが削除されたのかは不明なため、なんらかの方法で API 応答の結果を保存しておき、前回との差分で削除されたレコードを見つける必要があります。

最も簡易的な方法は転送先テーブルを参照し、削除されたレコードを見つける方法ですが、これでは転送先と Function が密結合してしまい、 Function が再利用不可になってしまいます。再利用可能な Function を実装したい場合は、 Function から参照できる場所に AWS RDS や Cloud SQL のような DB を用意しておき、前回の結果を記録しておく方法が考えられます。

ただ、現実的には多くの場合、 Fivetran がサポートしているデータソースに対して Fivetran を使うことが多いので、そもそもカスタムコネクタを作らざるを得ない状況になるケースが少ないため、記録用に DB を新たに用意する方法は冗長かつコストがかかるので、筆者の環境では転送先のテーブルを参照して削除レコードを見つける方法を取っています。ただし、 Fivetran から Function に渡すペイロードに転送先の Snowflake や BigQuery などの DWH が特定できる情報を渡す方法をとることで、 Function が特定のテーブルに密結合することを防いでいます。

（参考）以下は公式ドキュメントにおける HTTP レスポンス側の解説:

https://fivetran.com/docs/functions

> delete (optional) specifies the entities and records to be deleted. Use this field to mark records as deleted. Fivetran doesn't delete the record; instead it marks the record as deleted by setting _fivetran_deleted column value to true. If you specify the delete field, you must also specify the schema field.
> Fivetran creates the _fivetran_deleted column in the destination table, only if your function response has the delete field.

# おわりに

今回は Fivetran のカスタムコネクタを実際に作る上で気になった点と TIPS を紹介しました。これからカスタムコネクタ開発に取り組む方の参考になれば幸いです。
