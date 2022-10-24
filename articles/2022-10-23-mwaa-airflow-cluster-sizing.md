---
title: "AWS Managed Airflow (MWAA) でクラスタサイズを最適化する方法"
emoji: "🚀"
type: "tech"
topics: [aws,airflow]
published: true
---

# 背景

AWS にはオープンソースの Python ベースなワークフローオーケストレーションツールである Airflow マネージサービス Amazon Managed Workflows for Apache Airflow (MWAA) が提供されています。

https://docs.aws.amazon.com/mwaa/latest/userguide/what-is-mwaa.html

MWAA では、Airflow　のクラスタ（AWS では環境と呼ばれている）を作成する際に、クラスタのサイズとして以下を選択するように求められます。

* 環境クラス
* スケジューラの数
* ワーカの数

これらのパラメタはユーザが利用したい Airflow クラスタのパフォーマンスやコストを最適化したい場合に、最初に調整を検討するパラメタであり、非常に重要です。

しかし、適切なパラメタ値を選択するためには、MWAA 環境どのような仕組みがで動いているかを理解する必要があります。本記事では、MWAA の内部アーキテクチャの仕組み、各パラメタの意味や調整する際の観点などを説明します。

https://docs.aws.amazon.com/mwaa/latest/userguide/create-environment.html

# MWAA の内部アーキテクチャ

最初に MWAA の内部アーキテクチャについて説明します。MWAA のサイジングとは、環境クラス・スケジューラの数・ワーカの数などのパラメタを調整することになりますが、コスト・パフォーマンスとこれらのパラメタの関係を理解するためには、中の仕組みを理解する必要があります。

MWAA の手順書に沿って環境を作成すると、以下のクラスタが作成されます。（注）Customer VPC は環境作成中に指定した VPC であり、Service VPC は AWS 管理のアカウント内の VPC です。

https://docs.aws.amazon.com/mwaa/latest/userguide/get-started.html

![MWAA のアーキテクチャ](https://storage.googleapis.com/zenn-user-upload/e4df0b292925-20221023.png)

## Customer VPC 側のアーキテクチャ

Customer VPC 側には、Airflow Schedulers と Airflow Workers が AWS ECS Task として配置されています。OSS 版 Airflow の Web サイトによると、それぞれのコンポーネントの役割は以下の通りです。https://airflow.apache.org/docs/apache-airflow/2.2.2/concepts/overview.html

> A scheduler, which handles both triggering scheduled workflows, and submitting Tasks to the executor to run. 

*（訳）スケジューラはスケジュールされたワークフローを駆動し、タスクをエグゼキュータに送信し、実行させます。*

> An executor, which handles running tasks. In the default Airflow installation, this runs everything inside the scheduler, but most production-suitable executors actually push task execution out to workers. 

*（訳）エグゼキュータは、実行中のタスクを制御します。デフォルトの Airflow インストール環境では、エグゼキュータはスケジューラの中で全てを実行しますが、プロダクション向けのエグゼキュータはタスク実行をワーカに移譲します。*

この[エグゼキュータ](https://airflow.apache.org/docs/apache-airflow/2.2.2/executor/index.html#executor-types)とは Airflow におけるタスク実行の仕組みのことです。プラグインの仕組みになっており、環境ごとに別のエグゼキュータを利用できます。MWAA の内部アーキテクチャ図には、エグゼキュータの ECS Task は登場しませんが、以下の通り、[Airflow のアーキテクチャ図](https://airflow.apache.org/docs/apache-airflow/2.2.2/concepts/overview.html)にはスケジューラの一部として登場しています。

![Airflowアーキテクチャ図](https://storage.googleapis.com/zenn-user-upload/6093537d8ae3-20221023.png)

上記解説にある、”デフォルトの Airflow インストール環境でのエグゼキュータ" は、[Sequential Executor](https://airflow.apache.org/docs/apache-airflow/2.2.2/executor/sequential.html) のことを指します。全てのタスクがローカルで、シーケンシャル（1つ1つ順番）に実行されます。

一方で、MWAA で使われている [Celery Executor](https://airflow.apache.org/docs/apache-airflow/2.2.2/executor/celery.html) では、ジョブキューを介して、多数のワーカにタスクを分散させることができ、多数のタスクを同時に並列実行させることができます。

本番環境では、一般的にコストとパフォーマンスのトレードオフを考え、実行中のタスク数が少ない時は少ない数のワーカを走らせ、実行中のタスク数が大きい時はより多くのワーカを走らせることを考えることが多いでしょう。この時、 Celery Executor を使うと、要求のあったタスクをジョブキューにキューイングさせ、ジョブキュー中のタスク数で必要なワーカを起動し、一つ一つタスクをワーカに割り当てていくことで、実行させたいタスクの数に応じてワーカの数を増減させることで、期待するパフォーマンスとコストを最適化できます。

なお、 Celery Executor は RabitMQ 、 Redisなど 様々なジョブキューをサポートしていますが、 MWAA で利用されているのは、 SQS です。

## Service VPC 側のアーキテクチャ

こちらにはメタデータベース （RDS） と Web サーバが配置されます。メタデータベースは Airflow を実行する上で必要なメタデータが格納され、 Web サーバは利用者が Airflow を管理・利用する際の UI を提供します。

# 環境クラスとは

MWAA の内部アーキテクチャは以上の通りです。ここでクラスタサイズを決める上でのパラメタである環境クラスに話を戻します。

https://docs.aws.amazon.com/mwaa/latest/userguide/environment-class.html

MWAA ドキュメントでは、環境クラスについて以下の通り説明しています。

> The environment class you choose for your Amazon MWAA environment determines the size of the AWS-managed AWS Fargate containers where the Celery Executor runs, and the AWS-managed Amazon Aurora PostgreSQL metadata database where the Apache Airflow schedulers creates task instances.

*（訳）あなたが選択した Amazon MWAA 環境の環境クラスが Celery Executor が実行される AWS マネージド AWS Fargate コンテナ、 Apache Airflow スケジューラがタスクインスタンスを作成する AWS マネージド Amazon Aurora PostgreSQL メタデータベースのサイズを決定します。*

また MWAA のドキュメントによると MWAA のコンソールで環境を変更する際の以下のような画面が登場します。つまり、環境クラスとは MWAA 上のワークロード負荷度合いに応じた適切なキャパシティのことを指します。環境クラスを変更すると、スケジューラ・ワーカ・ Web サーバの ECS Task に割り当てされる vCPU も変更され、その分、処理できる DAG の量も変わります。 

なお、画面中に **under typical usage* と注釈されているように MWAA 環境にどの程度負荷がかかるかは、DAG の処理内容やスケジュールの仕方によって大きく変わります。よってここにある DAG の数はあくまで目安としてお考えください。例えば、以下の 2 つでは負荷のかかり方が全く違います。

* 100 DAG が 1 日 1 回一斉に起動して、30分後に止まる。
* 5 DAG が 1 時間に 1 回一斉に起動し、30分後に止まる。

![MWAA 環境クラス](https://storage.googleapis.com/zenn-user-upload/ad0c315c56fd-20221023.png)

