---
title: "Snowflake でサポート対象外のバージョンでアクセスしているクライアントを見つける"
emoji: "❄️"
type: "tech"
topics: [snowflake,sql]
published: false
---

本記事は、[Snowflake Advent Calendar 2022](https://qiita.com/advent-calendar/2022/snowflake) の1日目です。

# 記事の背景

Snowflake のドキュメントには、クライアント種類ごとに Recommended Version （推奨バージョン）と Minimum Version （最小バージョン）の両方が掲載されています。この Minimum Version とはサポート対象のうち、最も古いバージョンです。これより古いとサポート対象外になるため、セキュリティや接続性の問題が発生する可能性があるため、速やかに推奨バージョンにアップグレードする必要があります。

https://docs.snowflake.com/en/release-notes/requirements.html

> The minimum version for a client identifies the earliest supported version of the client. Any client versions lower than the documented minimum are no longer covered by our support policy (see below) and may encounter issues when connecting to Snowflake.
> As stated in our client support policy (in this topic), we fix issues on the latest client versions only. As such, the minimum versions may contain issues that have been fixed in later versions and, therefore, you should not install the minimum versions.
> They are documented in the table above only as guidelines for managing your installed clients relative to our support policy.

ここで人が Snowflake を利用する場合、通常、Web ブラウザで Snowsight にアクセスすることが多く、このケースはクライアントバージョンが常に最新になるため、特に問題ありません。

問題になるのは、ETL ジョブなど各種アプリケーションが Snowflake にアクセスするケースです。この場合、各ジョブの実行環境に Snowflake クライアントがインストールされ、ジョブを実行することになりますが、一度インストールしたクライアントをそのまま使い続ける場合が多いと思います。最初は最新を使っていたものの数年経った時には、クライアントバージョンが最小バージョンよりも古くなってしまいます。

Snowflake クライアントのセキュリティや接続性の問題を防止するため、Snowflake 管理者はクライアントがどのバージョンを使っているのか監視する必要があります。
古すぎるクライアントバージョンを使っているユーザを見つけたら、クライアントバージョンをアップグレードするように促すことができます。

なお、ドキュメントによると、最小バージョンより古いバージョンを使っているとすぐに接続を拒否されるわけではないようです。接続する拒否する場合は、事前に警告があるようです。

> Client versions that are below the minimum supported version may be blocked from connecting to Snowflake. Note that Snowflake will provide advanced notification before blocking access for a particular client version.

# 最小バージョンより古いクライアントを使っているユーザを見つける

ここから本題です。このクライアントバージョンの監視を以下のクエリで実現しました。

* まず接続したユーザのクライアントバージョンは、login_history view で分かります。 https://docs.snowflake.com/en/sql-reference/account-usage/login_history.html
* Web ページでクライアントの種類ごとに推奨バージョン・最小バージョンを確認して自分で入力する必要があります。 `reported_client_version` がクライアントのバージョンですので、Web ページで確認したバージョンと比較しています。
* ただ、単純にバージョン番号の文字列をそのまま比較すると期待する結果にはならないため、バージョン番号を数値に変換する関数を利用しています。この関数はメジャーバージョンを100の位、マイナーバージョンを10の位、バグフィックスバージョンを 1 の位に対応づけています。
* `event_timestamp` はユーザがログインした時刻です。ログイン履歴を確認したい時刻に変更してください。

```
create or replace function convert_version(ver varchar)
returns number
as
$$
(split( ver, '.'  )[0] * 10000 + split( ver, '.'  )[1] * 100 + split( ver, '.'  )[2])::NUMBER
$$;

select distinct
  client_ip,
  user_name,
  reported_client_type,
  reported_client_version
from snowflake.account_usage.login_history
where
reported_client_type != 'SNOWFLAKE_UI'
and event_timestamp between 'YYYY-MM-DD' and 'YYYY-MM-DD'
and (
    (reported_client_type = 'PYTHON_DRIVER' and convert_version(reported_client_version) < convert_version('2.3.1')) OR
    (reported_client_type = 'JDBC_DRIVER' and convert_version(reported_client_version) < convert_version('3.12.11')) or
    (reported_client_type = 'ODBC_DRIVER' and convert_version(reported_client_version) < convert_version('2.21.8')) or
    (reported_client_type = 'SNOWSQL_CLI' and convert_version(reported_client_version) < convert_version('1.2.9')) or
    (reported_client_type not in (
        'PYTHON_DRIVER',
        'JDBC_DRIVER' ,
        'ODBC_DRIVER',
        'SNOWSQL_CLI',
        'OTHER'
    ))
);
```

# 継続的に監視するにはどうするか？

上記のクエリを手動実行すれば、最小バージョンより古いクライアントを使っているユーザが見つけられることが分かりました。一方で、この監視作業を継続的に実施するにはどうしたら良いでしょうか？

残念ながら推奨バージョン、最小バージョンを SQL 上で取得することはできないため、バージョンの確認は人力で行う必要があります。よって監視作業を自動化することは困難です。月に 1 回程度、点検作業を実施している場合は、その中にクライアントバージョン確認を入れておくと良いでしょう。
