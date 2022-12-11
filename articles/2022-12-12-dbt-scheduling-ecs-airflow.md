---
title: "AWS ECS と Airflow で Snowflake 向け dbt モデルデプロイをスケジューリング実行する"
emoji: "🚀"
type: "tech"
topics: [dbt,snowflake,dbt,airflow,aws]
published: true
---

本記事は、[Snowflake Advent Calendar 2022 その 2](https://qiita.com/advent-calendar/2022/snowflake) の 3日目の記事です。

# 背景

筆者の所属企業では、約 2 年前に Snowflake を導入した際に、各種リソースの構成管理方法・デプロイ方法として、Terraform を導入しました。

https://zenn.dev/yohei/articles/2020-12-28-snowflake-terraform

当初は、Terraform で何でも管理しようと試みていましたが、以下の理由により、テーブルやビューといったデータ関係のリソースについてはデータ変換ツール dbt の OSS 版 dbt core を導入しました。

* Terraform で大量のリソース管理を行うと、Terraform ステート更新に伴う計算量が増大し、必要な CPU・メモリ量が増加、またデプロイが完了するまでの時間が増大した。
* デプロイ対象として、テーブルやビューの数が多いが、利用者に Terraform を学習させるのはコストがかかる。Terraform ファイルを生成するスクリプトで自動化を図ったが、利用者本人が直接 SQL だけを書く方が簡単で、学習コストが低い。
* 世間的にはデータ変換レイヤーで dbt がデファクトとして広まった。

# dbt モデルのデプロイ方法

ここで、dbt は単純なテーブルやビューのデプロイだけでなく、インクリメンタルなテーブルの更新や、Slowly Changing Dimention Type 1/2 といった複雑なテーブルの更新にも対応しています。よって、デプロイ方法としては、以下の 2 通りに対応する必要があります。

* テーブルやビューを単発でデプロイする。
* テーブルの作り直し、あるいは継続的な更新をスケジュール実行する。

前者については、Terraform を使った既存の CICD パイプラインで対応しているユースケースのため、新たに dbt 用のリポジトリと CICD パイプラインを作り、即座に対応しました。後者については未対応だったため、今回、新たに対応することになりました。

# dbt モデルデプロイ・スケジュール実行の要件

次にスケジュール実行にあたって、筆者のプロジェクトで以下の要件を満たす必要がありました。

* Git リポジトリと CICD パイプラインは会社の CCOE (Cloud Center of Excellence) チームが管理している Gitlab を使っている。
* スケジュール実行は、AWS MWAA (Managed Workflow for Apache Airflow) に集約している。dbt モデルのデプロイも Airflow に集約したい。
* dbt モデルデプロイを行うコマンドは Airflow からは独立させて実行したい。これは、dbt は Python パッケージのため、Airflow から直接実行可能だが、Airflow に直接依存してしまうと、バージョン間の衝突により、新しいバージョンの dbt が使えなくなってしまうため。

# CICD パイプラインのアーキテクチャ

実際に構築した CICD パイプラインのアーキテクチャは以下の通りです。

（注）筆者の企業では、Gitlab や ECR といった様々なプロジェクトで利用されるツール・サービス群は、 CCOE (Cloud Center of Excellence) チームが管理しており、Data Engineering Team で管理する Airflow や ECS クラスタとは別の AWS アカウントで管理されています。

1. dbt モデルのソースコードは Gitlab で管理している。新規の変更は Gitlab リポジトリにマージする。
2. 1 回きりのデプロイで良いモデルについては、マージした瞬間に起動する CICD パイプラインで dbt コマンドを実行し、デプロイする。
3. 同時に dbt モデルのソースコードを追加したコンテナイメージをビルドし、ECR に push しておく。
4. Airflow DAG を起動させて、dbt モデルを実行する AWS ECS Fargate コンテナを起動する。なお、事前に ECS クラスタおよびタスク定義を作成しておく必要あり。
5. コンテナイメージは事前に登録した ECR から ECS クラスタへロードされる。 
6. コンテナ内で dbt コマンドが実行され、テーブルが更新される。

![dbt モデルデプロイパイプライン](https://storage.googleapis.com/zenn-user-upload/643606e124f0-20221211.png)

# 2 通りのデプロイに対応するための工夫

上記に挙げた 2 通りのデプロイ方法に対応するためには、どのモデルはスケジュール実行するか判別できる必要があります。よって、筆者のプロジェクトではスケジュール実行対象の印として以下のようにタグ付けしています。
https://docs.getdbt.com/reference/resource-configs/tags

```
{{
    config(
        tags="scheduled"
    )
}}
```

Gitlab Merge Request をマージした際の単発デプロイの場合は、`scheduled` のタグを除いて dbt run コマンドを実行して、意図しないタイミングでのデプロイを避けることができます。

```
dbt run --exclude tag:scheduled
```

一方で、スケジュール実行の際は、モデル名を指定して dbt run コマンドを実行することで、特定のモデルのみデプロイします。

```
dbt run --select model_name
```

# おわりに

今回は、筆者のプロジェクト内で dbt モデルのデプロイをスケジュール実行する際の工夫について紹介しました。今回の工夫により、merge request をマージした際の単発デプロイ、Airflow DAG によるスケジュール実行の両方に対応できるようになりました。

dbt 利用者によっては、dbt Cloud を使ってスケジュール実行されている方も多いと思いますが、あえて Airflow など外部スケジューラを使うことで、他のジョブやリソースのタイミングと調整して実行できるなど複雑なスケジューリングも可能になります。

なお、筆者のプロジェクトでは dbt Python も評価中です。dbt Python についてノウハウが貯まれば、また共有しますので、お楽しみに。
