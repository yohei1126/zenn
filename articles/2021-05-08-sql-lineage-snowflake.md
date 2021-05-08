---
title: "Python モジュール sqllineage を利用した Snowflake でのデータリネージの実現"
emoji: "❄️"
type: "tech"
topics: [python,sql,snowflake,visualization]
published: falses
---

# 本記事の背景

先日、自社のデータアナリストやデータサイエンティストに Snowflake の概要を紹介した際に、データリネージをどう実現するのか聞かれる機会がありました。本記事では、比較的簡易的に実現する方法として、Python モジュールの sqllineage を紹介します。

# データリネージとは

https://en.wikipedia.org/wiki/Data_lineage

> Data lineage includes the data origin, what happens to it and where it moves over time.[1] Data lineage gives visibility while greatly simplifying the ability to trace errors back to the root cause in a data analytics process.[2]

リネージ (lineage) は日本語では系統や血統を意味します。データリネージと言えば、データパイプラインやデータウェアハウスにおいて、データがどこから投入され、どう変換され、どう利用されたか、データの流れ・系統を可視化したものを指します。

GCP の公式サイトにも日本語でよくまったドキュメントがいくつかあったのでこちらを紹介します。

データ ウェアハウス用のデータリネージ システム  https://cloud.google.com/architecture/architecture-concept-data-lineage-systems-in-a-data-warehouse?hl=ja

> データリネージを使用すると、データの発信元がわかります。データリネージには、データに適用している変換も示されます。たとえば、ソースデータと他のデータを組み合わせることで、データを拡充できます。また、変換によってデータの操作（数学演算子を使用したデータの結合や変更など）を行うこともできます。

> データリネージによってトレーサビリティも確立されます。これにより、データ ウェアハウス内のソースとターゲットが異なるエンティティ間の接続が定義されます。データソースとは、データベース内のテーブル、ストレージ システム上のファイル、メッセージバスやキューなど、処理するデータが最初に読み込みまたは取得される地点のことです。データリネージ レコードに含まれるソース エンティティは、データがどこから取得されたものかを示します。ターゲット（またはデータの宛先）エンティティは、処理後にデータを書き込む場所を示します。ソース エンティティとターゲット エンティティはどちらも、データを一時的にまたは永続的に保存するシステムとして定義できます。

> データリネージの管理は、データアクセス管理にとっても重要になります。データ ガバナンスのためにデータリネージに関する情報を効果的に収集するには、データ ウェアハウスの運用で生成された運用メタデータを利用します。

# データリネージの用途

データリネージは、データの内容や意味を理解したい場合、あるいはデータに品質上の問題があった場合に役立ちます。データリネージ上のより上流をたどることで、どのようにデータが変換されたか理解することで、特にはデータの持つ意味をより深く理解できたり、データ品質の問題の原因を突き止めたりできます。

https://cloud.google.com/architecture/architecture-concept-data-lineage-systems-in-a-data-warehouse?hl=ja#data_lineage_use_cases

> データリネージは、さまざまな状況で役立ちます。さまざまなタイプのユーザーがデータリネージを作業に適用する例を以下に示します。
> * ビジネス ユーザーは、次のアクティビティにデータリネージを使用できます。
>   * データソースと変換を確認してレポート フィールドを検証する。
>   * データ検出を実施し、データリネージとデータの用語集またはカタログを組み合わせる。
> * データ エンジニアは、次のアクティビティのためにデータリネージを使用できます。
>   * アップストリーム ジョブの失敗を引き起こす可能性のある、古いレポートを特定します。
>   * アップストリームの問題を特定して修正する必要があるソースを識別することで、データセット内のデータ品質の問題のトラブルシューティングを行います。
> * データ ガバナンス ユーザーは、次のアクティビティのためにデータリネージを使用できます。
>   * すべてのダウンストリーム用途を識別して、機密データやデータに対し、アクセス制御ポリシーを適用できます。
>   * データ競合（たとえば、データセットを更新する複数のプロセス）を特定します。
>   * 使用していないデータセットや重複するデータセットを削除してコンプライアンスを確保し、ストレージを削減する。
>   * データセットや列を識別することで、ストレージのパフォーマンスの向上またはアクセスの精査をはかる。
>   * データ品質を長期にわたってモニタリングする。
>   * データ ウェアハウスの外部にデータがエクスポートされたときに、データ流出を報告する。

# Python モジュール sqllineage を使った Data Lineage

Snowflake は、現在、公式にはデータリネージを公式にはサポートしていません。

一方で、SQL を読み込んでテーブルやビューの依存関係を可視化する OSS のツールが存在します。ここでは、Python モジュールの sqllineage を紹介します。

https://sqllineage.readthedocs.io/en/latest/
https://github.com/reata/sqllineage

sqllineage は pip を使って簡単にインストールできます。

```
pip install sqllineage
```

また、コマンドラインで以下のように INSERT 文を指定して sqllineage を実行すると、内部で Web サーバが起動し、データリネージの結果を描画します。

```
sqllineage -g -e "insert into db1.table11 select * from db2.table21 union select * from db2.table22; insert into db3.table3 select * from db1.table11 join db1.table12;"
```

![Data Lineage](https://storage.googleapis.com/zenn-user-upload/1s7mt71davkdsjbmq99mxm5i4zg9)

詳しいコマンドラインの詳細は、以下のドキュメントを参照ください。

https://sqllineage.readthedocs.io/en/latest/

# Snowflake QUERY_HISTORY を使った SQL 実行記録の取得

Snowflake 上の過去のクエリ実行結果を取得し、sqllineage のコマンドに与えることで、Snowflake 上のリソースのリネージを作成できます。過去のクエリ実行結果は、QUERY HISTORY を使って取得できます。

https://docs.snowflake.com/en/sql-reference/functions/query_history.html

例えば、以下のクエリでは、過去7日間の INSERT、MERGE、UPDATE といったテーブルを更新したクエリを抽出します。
このクエリで抽出した過去のクエリを sqllineage に適用することで、データリネージを取得できます。

```
SELECT QUERY_TEXT
FROM TABLE(
    INFORMATION_SCHEMA.QUERY_HISTORY(
        DATEADD('DADYS',-7,CURRENT_TIMESTAMP()),
        CURRENT_TIMESTAMP()))
WHERE
  LOWER(QUERY_TEXT) LIKE 'insert%'
  OR LOWER(QUERY_TEXT) LIKE 'merge%'
  OR LOWER(QUERY_TEXT) LIKE 'update%'
ORDER BY START_TIME;
```

# 実際に利用する上での注意点

上記のInformation Schema table function の QUERY_HISTORY は最大7日前まで履歴が取得できます。

また、以下のビューの方は最大1年前まで履歴を取得できます。

https://docs.snowflake.com/en/sql-reference/account-usage/query_history.html

履歴の保持期間をすぎると実行履歴を取得できなくなるので、データリネージも生成できなくなります。
よって別途テーブルを作成し、バッチジョブなどで定期的に履歴をバックアップするような処理をして、1年以上過去の履歴からもデータリネージを作成できるようにしたほうが良いでしょう。

# おわりに

本記事では、Python のモジュールを使って SQL からデータリネージ図を生成する方法を紹介しました。
Snowflake の場合、クエリの実行履歴で過去に実行したクエリを取得できますので、そちらをデータリネージ生成の入力にできます。
ただし、クエリ履歴を保持できる期限があるので、実際に利用する上では履歴を失わないようにバックアップする必要があります。

本記事がデータリネージに取り組みたい方の参考になれば幸いです。
