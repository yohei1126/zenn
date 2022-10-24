---
title: "AWS Managed Airflow (MWAA) でクラスタサイズを最適化する方法"
emoji: "🚀"
type: "tech"
topics: [aws,airflow]
published: true
---

# 背景

AWS には Python ベースのオープンソースワークフローオーケストレーションツールである Apache Airflow のマネージサービス Amazon Managed Workflows for Apache Airflow (以下、MWAA) が提供されています。

https://docs.aws.amazon.com/mwaa/latest/userguide/what-is-mwaa.html

MWAA では、環境（Airflow　のクラスタのこと）を作成する際に、環境のサイズを決めるため、以下のパラメタ値を設定するように求められます。

* 環境クラス - `mw1.small`、`mw1.medium`、`mw1.large`
* ワーカ数（最大数、最小数）
* スケジューラ数

これらのパラメタはユーザが利用したい Airflow クラスタのパフォーマンスやコストを最適化する上で非常に重要です。しかし、適切なパラメタ値を選択するためには、MWAA 環境がどのような仕組みがで動いているかを理解する必要があります。本記事では、MWAA の内部アーキテクチャの仕組み、各パラメタの意味や調整する際の観点などを説明します。

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

# 環境クラス

MWAA の内部アーキテクチャは以上の通りです。ここでクラスタサイズを決める上でのパラメタの 1 つ目である環境クラスに話を戻します。

https://docs.aws.amazon.com/mwaa/latest/userguide/environment-class.html

MWAA ドキュメントでは、環境クラスについて以下の通り説明しています。

> The environment class you choose for your Amazon MWAA environment determines the size of the AWS-managed AWS Fargate containers where the Celery Executor runs, and the AWS-managed Amazon Aurora PostgreSQL metadata database where the Apache Airflow schedulers creates task instances.

*（訳）あなたが選択した Amazon MWAA 環境の環境クラスが Celery Executor が実行される AWS マネージド AWS Fargate コンテナ、 Apache Airflow スケジューラがタスクインスタンスを作成する AWS マネージド Amazon Aurora PostgreSQL メタデータベースのサイズを決定します。*

また MWAA のドキュメントによると MWAA のコンソールで環境を変更する際の以下のような画面が登場します。

![MWAA 環境クラス](https://storage.googleapis.com/zenn-user-upload/ad0c315c56fd-20221023.png)

つまり、環境クラスとは MWAA 上のワークロード負荷度合いに応じた適切なキャパシティのことを指します。環境クラスを 1 つ 上げる度に、スケジューラ・ワーカ・ Web サーバの ECS Task に割り当てされる vCPU や RAM のサイズが 2 倍になり、その分、処理できる並列タスク の量も 2 倍になります。

* `mw1.small`
  * 対応 DAG 数は 50 まで
  * デフォルトで 5 個の並列タスク 
  * 1 vCPUs
  * 2 GB RAM
* `mw1.medium`
  * 対応 DAG 数は 250 まで
  * デフォルトで 10 個の並列タスク 
  * 2 vCPUs
  * 4 GB RAM
* `mw1.large`
  * 対応 DAG 数は 1000 まで
  * デフォルトで 20 個の並列タスク
  * 4 vCPUs
  * 8 GB RAM

なお、画面中に **under typical usage* と注釈されているように MWAA 環境にどの程度負荷がかかるかは、 DAG の処理内容やスケジュールの仕方によって大きく変わります。よってここにある DAG の数はあくまで目安としてお考えください。例えば、以下の 2 つでは負荷のかかり方が全く違います。

* 100 DAG が 1 日 1 回一斉に起動して、30分後に止まる。
* 5 DAG が 1 時間に 1 回一斉に起動し、30分後に止まる。

# ワーカ数（最大数、最小数）

次にクラスタサイズを決める上でのパラメタの 2 つ目であるワーカ数に話を戻します。

上記ですでに説明しているように、 MWAA で使われている Celery Executor では、ジョブキューに溜まっているタスクの数に応じて、ワーカの数を増減させることで、パフォーマンスとコストを最適化します。

MWAA のコンソールでは、ワーカの最小数と最大数を設定できます。最初の状態では、実際のワーカ数は設定したワーカの最小数と同じですが、タスクが増えていくにつれ、負荷状況に応じてスケジューラがワーカの最大値までワーカを増やしていきます。

この時、必要となるワーカ数は以下のドキュメントで示されている通り、(必要なワーカ数) = (実行中のタスク数 + 待機中のタスク数) / (ワーカあたりのタスク数) で決まります。ここで **ワーカあたりのタスク数** は、先ほど説明した通り、環境クラスによって数値が異なります。

> Amazon MWAA uses RunningTasks and QueuedTasks metrics, where (tasks running + tasks queued) / (tasks per worker) = (required workers). If the required number of workers is greater than the current number of workers, Amazon MWAA will add Fargate worker containers to that value, up to the maximum value specified by max-workers.
https://docs.aws.amazon.com/mwaa/latest/userguide/mwaa-autoscaling.html#mwaa-autoscaling-how

なお、実際のワーカ数は MWAA コンソールで設定したワーカ最大数を超えることはできません。CloudWatch メトリクスで (実行中のタスク数 + 待機中のタスク数) を監視しながら、コストやパフォーマンスを考慮しつつ、適切な値に調整しておくと良いでしょう。

# スケジューラ数

最後にクラスタサイズを決める上でのパラメタの 3 つ目であるスケジューラ数に話を戻します。

このスケジューラのパフォーマンスは様々なファクターによって影響を受けるため、パフォーマンスの要因の分析が非常に難しい分野です。

Apache Airflow のドキュメントによると、以下がスケジューラのパフォーマンスに影響を当てる要因です。

https://airflow.apache.org/docs/apache-airflow/2.2.2/concepts/scheduler.html#fine-tuning-your-scheduler-performance

* デプロイの種類
  * DAG を共有するためのファイルシステムの種類（これは DAG ソースコードの読み取りに影響を与える）
  * ファイルシステムの処理速度（クラウドファイルシステムの多くのケースにおいて余計に費用を払うと高速化できる）
  * CPU の処理能力
  * ネットワークスループット
* DAG 構造のロジックと定義
  * DAG ファイル数
  * DAG の数
  * DAG ファイルの大きさ（DAG パーサは n 秒に1回 DAG ファイルを解析する必要がある点に注意）
  * DAG ファイルの複雑さ (DAG ファイルの解析速度、タスクの数や依存関係)
  * DAG ファイルがライブラリを多数ロードしてるか、[トップレベル](https://airflow.apache.org/docs/apache-airflow/2.2.2/best-practices.html#top-level-python-code)で重い処理をしてないか
* スケジューラの設定
  * スケジューラの数
  * スケジューラ上で走る DAG パース処理の数
  * 同じ DAG ファイルを再読み込みする際の待ち時間
  * 1 回のループでスケジューラは何個のタスクを処理するか
  * 1 回のループで何個の DAG を作成し、スケジュールする
  * どの程度の頻度でスケジューラがタスクのクリーニング処理を行うか

スケジューラは、ループの中で繰り返し、DAG ファイルを読み込む、DAG 構造を解釈する、タスクをスケジューリングする、タスクの実行状況を監視するという処理を継続的に行なっています。
 
スケジューラ単体の能力は、上記で設定した環境クラスごとに決められた ECS タスクのサイズによって決まります。またスケジューラの数は MWAA コンソールで設定した数で決まります。スケジューラは、ワーカと異なり、オートスケールは対応しておらず、最小値、最大値は設定できません。

Cloud Watch のメトリクスを見ながら、DAG ソースコードの読み取り (TotalParseTime) に時間がかかっている場合は、使っていない DAG ファイルは削除する、DAG や タスクの依存関係をシンプルにする、DAG ソースコードを簡潔にする、などの改善をしましょう。

https://docs.aws.amazon.com/mwaa/latest/userguide/access-metrics-cw-202.html

モニタリングの結果、スケジューラのパフォーマンスが過剰あるいは不足しているが、環境クラスを変更するほどではないと判断した場合は、スケジューラの数を調整しましょう。

# 補足 - その他の設定項目

OSS 版の Airflow には多数の設定項目があり、各種設定項目は MWAA の環境クラスごとに調整されています。

https://airflow.apache.org/docs/apache-airflow/2.2.0/configurations-ref.html

環境クラス、ワーカ数、スケジューラ数に加え、細かい設定について調整したい場合は以下を参照ください。ただし、Airflow の内部の振る舞いが完全に理解できていない場合、これらの詳細設定を直接変更すると、意図しない影響が出る可能性があります。必ず AWS のサポートの方と相談して調整しましょう。

https://docs.aws.amazon.com/mwaa/latest/userguide/configuring-env-variables.html

# 最後に

本記事では、MWAA での Airflow クラスタを利用する際に利用状況に応じて適切なクラスタサイズに調整する際の観点などを紹介しました。これらの観点を理解する上では、MWAA の内部アーキテクチャを理解する必要があります。

ただし、MWAA のクラスタは AWS によって管理されており、直接は中を覗き見ることができません。もし、Airflow のクラスタについてもう少し詳しく知りたいと思った方は、 OSS 版のコンテナを Docker Compose で動かしてみましょう。MWAA と同一の構成ではありませんが、Redis コンテナを使った Celery Executor の仕組みをローカルで体験できますので、より内部の仕組みを深く理解できると思います。

https://airflow.apache.org/docs/apache-airflow/2.2.0/start/docker.html
