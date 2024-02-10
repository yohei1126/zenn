---
title: "Airflow を使ったFivetran Sync ジョブのスケジューリング"
emoji: "😎"
type: "tech"
topics: [fivetran,airflow]
published: false
---

# 背景

以前、Fivetran にはカスタムコネクタという機能があり、AWS Lambda や GCP Cloud Functions といった FaaS を使うことで Fivetran がサポートしていないデータソースからもデータを取り込むことができる点を紹介しました。

https://zenn.dev/dataheroes/articles/2023-12-03-fivetran-custom-connector-dbt-snowlfake
https://zenn.dev/dataheroes/articles/2023-12-23-fivetran-custom-connector

本記事では、Airflow を使って Fivetran 外部から Sync ジョブをスケジューリングする方法について紹介します。

# そもそも Airflow を使う必要あるのか？

Fivetran のコネクタには簡易的にスケジールを設定できるため、Airflow のような外部スケジューラは必須ではありません。
また、Fivetran から dbt Core や dbt Cloud のジョブを起動できるため、データの取り込みから dbt モデルの更新まで、Fivetran だけで完結させることができます。データエンジニアや DevOps エンジニアがいないチームの場合は、Fivetran でスケジューリングを完結する方が嬉しい場合もあるでしょう。

https://fivetran.com/docs/transformations/transformation-scheduling
https://fivetran.com/docs/transformations/dbt
https://fivetran.com/docs/transformations/dbt-cloud

一方で、パイプラインが複雑化したり、外部の API を多用する高度なユースケースにおいて、データパイプラインのオーケストレーションツールとして Airflow を導入している場合、 Fivetran の内部スケジューラを使うより、すべてのスケジューリングを Airflow に集約した方がスケジュールの管理が楽になります。

よって、Fivetran 内部スケジューラを使うべきか、Airflow のような外部スケジューラを使うべきかはチームの状況によって決めるべきでしょう。

# Astronomer 製 OSS パッケージ airflow-provider-fivetran-async の概要

Fivetran は REST API を公開しているため、Airflow Operator を自作することは可能ですが、すでに開発された OSS のパッケージをお探しの場合は、Astronomer (managed Airflow サービスの開発ベンダ) が開発した airflow-provider-fivetran-async というパッケージが存在するため、こちらを使いましょう。

https://github.com/astronomer/airflow-provider-fivetran-async

こちらのパッケージは内部的に Deferrable Operators や Deferrable Sensors という比較的新しい機能を導入して実装されているため、 Airflow 2.2 以上で利用可能です。

なお、以前に同じ開発元が同じ目的のパッケージを出していますが、こちらはすでに開発が停止しています。今後は airflow-provider-fivetran-async の方を使いましょう。

https://github.com/fivetran/airflow-provider-fivetran

airflow-provider-fivetran-async を利用する際は pip でインストールできます。そのほか、poetry など他のパッケージマネジャでもインストール可能です。

```
pip install airflow-provider-fivetran-async
```

# Fivetran Sync ジョブをスケジュールするサンプル DAG

Fivetran Sync ジョブをスケジュールするサンプル DAG は以下の通りです。　`os.environ["no_proxy"]="*"` の箇所は筆者の社内環境固有の問題の可能性があるため、無視してください。
FivetranOperator に指定する connector_id は Fivetran のコネクタ ID を指定します。コネクタ ID はコネクタの詳細をUIで開くと確認できます。 UI 上で目にするコネクタ名とは異なる点に注意してください。
https://fivetran.com/docs/using-fivetran/fivetran-dashboard/connectors

以下の DAG の場合、Fivetran Sync ジョブのステータスが正常になると、 Airflow のタスクも正常終了します。

```
import os
from datetime import timedelta
from airflow import DAG
from airflow.utils.dates import days_ago
from fivetran_provider_async.operators import FivetranOperator
 
# This is required to fix connectivity issue when you run this DAG locally
# https://stackoverflow.com/a/73983599
os.environ["no_proxy"]="*"
 
with DAG(
    "fivetran_test",
    default_args={
        "depends_on_past": False,
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
    description="A simple tutorial DAG",
    #schedule='@once',
    start_date=days_ago(1),
    catchup=False,
    tags=["example","fivetran"],
) as dag:
 
    FivetranOperator (
        task_id="trigger",
        connector_id="xxx_yyy",
    )
```

# Airflow コネクションの作成

FivetranOperator はデフォルトで `fivetran` という名前の Airflow コネクションを参照するため、動作確認の際には先に作っておきましょう。
https://github.com/astronomer/airflow-provider-fivetran-async/blob/8d1dc6b19ff349dab51f5bad6e6fd5403190f0a3/fivetran_provider_async/operators.py#L65

Airflow コネクションの login には Fivetran REST API キーの API キー、password には API シークレットを設定する必要があります。Fivetran REST API キーの生成方法については以下を参照ください。 
https://fivetran.com/docs/rest-api/getting-started

なお、API キーの所有者はスケジュール対象の Fivetran コネクタを起動できる権限が事前に付与されている必要があります。コネクションを作成したユーザのAPIキーをAirflowに使う場合は問題ありませんが、別のユーザのキーを使う場合は、権限に注意しましょう。権限管理に必要なロールについては以下を参照ください。
https://fivetran.com/docs/using-fivetran/fivetran-dashboard/account-management/role-based-access-control

# Airflow Triggers の有効化

airflow-provider-fivetran-async 内部では Deferrable Operators および Sensors が利用されている点はすでに説明しました。
この機能は、以前の標準的な Operators や Sensors が待機状態の時にスケジューラにポーリングを継続的に実行することで、スケジューラへ負荷をかけてしまう問題を解決するために導入された機能です。
Deferrable Operators および Sensors はスケジューラへの負荷を軽減するため、Triggers という Airflow の新しい機構を使って非同期でタスクを実行される工夫が導入されています。
機能詳細は以下を参照ください。

https://airflow.apache.org/docs/apache-airflow/2.3.4/concepts/deferring.html

この Deferrable Operators および Sensors を利用するためには、Airflow クラスタ側で事前に Triggers を有効化させる必要があります。
GCP Composer の場合に有効化する手順は以下を参照下さい。

https://cloud.google.com/composer/docs/composer-2/use-deferrable-operators
https://cloud.google.com/composer/docs/composer-2/scale-environments#triggerer-count

AWS MWAA における Trigger の設定は以下を参照ください。

https://docs.aws.amazon.com/mwaa/latest/userguide/configuring-env-variables.html

# まとめ

本記事では、Airflow を使って Fivetran Sync ジョブをスケジューリングする方法について紹介しました。前回のカスタムコネクタの記事と合わせると、ネイティブコネクタでもカスタムコネクタでもスケジューリングを Airflow に集約することができます。
もしスケジューリング、オーケストレーションを Airflow に集約したいニーズがある場合は本記事が参考になれば幸いです。
