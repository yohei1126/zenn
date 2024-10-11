---
title: "Table schema evolutionを使った Snowflake テーブルへのカラムの自動追加"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: true
publication_name: "dataheroes"
---

# 本記事の背景

本記事では、 データソースから S3 上に JSON ファイルが抽出される環境において、 COPY コマンドを使って Snowflake 上のテーブルにロードする際に、データソース側のカラム追加を自動的に対応する機能として、 Table schema evolution を紹介します。

検討に至った背景としては、カラム追加に対応する際のコミュニケーションコスト低減があげられます。カラム追加の作業自体は単純ですが、適切に新規カラムをターゲットのテーブルに取り込むためには、データソース側とターゲットテーブル側でスキーマを一致する必要があり、変更前に両者でスキーマを合わせる作業が非常にコミュニケーションコストが高いため、自動的に対応する方法はないかという意見があがり、調査するに至りました。

# Table schema evolution 機能の概要

以下に Table schema evolution 機能の概要を紹介します。

https://docs.snowflake.com/en/user-guide/data-load-schema-evolution

Table schema evolution は COPY コマンド実行の際に、 COPY 元のファイルと COPY 先のテーブルのスキーマを比較し、 COPY 元のスキーマ変更に自動的に対応してくれる機能です。現在対応できる変更は、カラムの自動追加のみです。

サポート対象のファイルフォーマットは Parquet, CSV, JSON が対応済み。

Table schema evolution は、以下の条件が揃っている場合に機能がが有効になります。

* CREATE TABLE もしくは ALTER TABLE で ENABLE_SCHEMA_EVOLUTION を TRUE にしておく。
  * https://docs.snowflake.com/en/sql-reference/sql/create-table
  * https://docs.snowflake.com/en/sql-reference/sql/alter-table 
* COPY INTO で MATCH_BY_COLUMN_NAME を有効にする。
  * https://docs.snowflake.com/en/sql-reference/sql/copy-into-table
  * MATCH_BY_COLUMN_NAME に設定できる有効な値は、 CASE_SENSITIVE 、CASE_INSENSITIVE 、NONE のいずれか。
* COPY INTO を実行するロールが対象テーブルの EVOLVE SCHEMA もしくは OWNERSHIP 権限を持っている。

# 制約事項

* デフォルトで COPY コマンドのつき、最大 10 カラム追加もしくは 1 スキーマに対応。
* Task や Snowpipe Streaming はサポートしていない。

# 注意事項

NOT NULL カラムがファイルに入っていない場合は、 COPY の際に自動的に NOT NULL 制約が外されてしまうリスクがあリます。これを防ぐアプローチとしては、ターゲットのテーブルと同じスキーマの一次テーブルを作って先にそちらへ COPY を実行することで、制約違反を検出する方法も考えうる。もしエラーにならなければ、目的のテーブルに COPY する方法が考えられます。

データソース側でのカラム名変更は対応できせん。もしデータ生成元で、 NOT NULL 制約がないカラムのカラム名が間違って変更されていた場合、新規のカラムとして追加されるので、カラム変更の有無を検出できません。後方互換性を厳密に取る場合は、以下のように厳密にデータコントラクト的な手法も考えられます

* (1) データ提供元にスキーマを定義してもらう。
* (2) カスタム実装として以下をやる。
  * スキーマ変更の広報互換性チェック
  * スキーマに沿った形で対象テーブルのスキーマ変更
  * COPY コマンドの実行

スキーマ判定に既存の INFER SCHEMA が使われていると想定すると、取り込み対象のファイルのスキーマをそのまま解釈するので、文脈を解釈できません。問題となるシナリオの例としては、データソース側でタイムスタンプを UNIX TIME として整数で出力する仕様の場合が挙げられます。 INFER SCHEMA はそれを整数と解釈するしかない。整数を UNIX TIME としてタイムスタンプ型として取り込む必要がある場合、明示的に型を指定する必要があります。

# Table schema evolution のサンプルコード

```
use schema test.test;

-- サンプルデータの JSON をアップロードする際のステージを用意する
CREATE STAGE IF NOT EXISTS my_int_stage
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');
```

この時点で以下のような JSON ファイルをステージにアップロードしておきます。

```
-- input1.json
{"name": "apple","size": "large","color": "red"}
{"name": "grape","size": "small","color": "purple"}

-- input2.json
{"name": "watermelon","size": "medium","color": "green", "weight": 10000}
{"name": "banana","size": "small","color": "yellow", "weight": 150}

-- input3.json
{"name": "watermelon","size": "medium","color": "green", "weight": 10000}
{"name": "banana","size": "small","color": "yellow", "weight": 150}
```

INFER_SCHEMA に FILE FORMAT 指定が必要のため、事前に FILE FORMAT を作っておきます。

```
CREATE FILE FORMAT IF NOT EXISTS my_json_format
  TYPE = json;

-- ファイルスキーマを確認する
SELECT *
FROM TABLE(
  INFER_SCHEMA(
    LOCATION=>'@my_int_stage/input1.json',
    FILE_FORMAT=>'my_json_format'
  )
);

-- @my_int_stage/input1.json のファイル内容を確認
-- 2 records
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input1[.]json'
) t;
```

input1.json からテーブルを作成する。

```
CREATE OR REPLACE TABLE fruits
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION =>'@my_int_stage/input1.json',
      FILE_FORMAT=>'my_json_format'
    )
  )
);
```
schema evolution を有効にする。
```
ALTER TABLE fruits SET ENABLE_SCHEMA_EVOLUTION = TRUE;
```

input1.json をテーブルに COPY する。

```
COPY INTO fruits
  FROM @my_int_stage/input1.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 2 records がロードされている
select * from fruits;
```

input2.json には新規コラム weight があり、 COPY 後にコラムが追加されている。 

```
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input2[.]json'
) t;

COPY INTO fruits
  FROM @my_int_stage/input2.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 新カラム weight がテーブルに追加されている
select * from fruits;
```

input3.json には weight がないが、 nullable なので問題なし。

```
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input3[.]json'
) t;

COPY INTO fruits
  FROM @my_int_stage/input3.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

select * from fruits;
```

# おわりに

本記事では、バッチベースの COPY コマンドを実行している環境で、 Snowflake の Table schema evolution の機能を使い、データソース側で新規追加されたカラムを検出し、 COPY 先のテーブルに自動追加する方法を紹介しました。一方で、 NOT NULL 制約の取り扱い、カラム変更に対応できない、データ型の文脈を解釈できないなどの制約事項も紹介しました。

もし、本機能を本番環境で利用する場合は、上記の制約事項が問題ならないか事前の検討をお薦めします。
