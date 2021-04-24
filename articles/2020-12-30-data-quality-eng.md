---
title: "Data quality measurement using Amazon Deequ"
emoji: "✨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [deequ,data,quality,measurement,cicd]
published: false
---

# Background

As a Data Engineer, I am currently working on data pipelines and data management. I have been recently observed data quality issues in our systems such as data record mismatch. To deal with such data quality issues, I have done some research on data quality measurement and improvement as a part of data governance and management activities.

I have found 2 OSS data quality profiling tools. In this article, I will mainly introduce [Amazon Deequ](https://github.com/awslabs/deequ) and my data measturement approach and how to deploy it to production environment.

# What is data quality? Why it is important

Before dig into the details of Deequ, let me explain about why data quality is important, which is my motivation of this work.

According to ISO 9000 quality management standard, The term quality is the degree to which a set of inherent characteristics of an object fulfils requirements.

This might be unclear for you. [The AWS blog article which introduced Amazon Deequ](https://aws.amazon.com/blogs/big-data/test-data-quality-at-scale-with-deequ/) gives us some examples regarding data quality issues as follows.

> Incorrect or malformed data can have a large impact on production systems. Examples of data quality issues are:
> * Missing values can lead to failures in production system that require non-null values (NullPointerException).
> * Changes in the distribution of data can lead to unexpected outputs of machine learning models.
> * Aggregations of incorrect data can lead to wrong business decisions.

The expectation of data users for the first example is that there is no NULL values in data. So, if actual data contains NULL values, it is against the user expectations. Definition of data quality standard may vary in each project but it is certain that this type of unexpected values can cause any system failures. This type of issue may happen when you forget to set enough constraints in RDB table definitions. 

The second example is like input data fit with expected data distribution. Machine learning models are trained using input data. So if distribution of input data changes it may also change quality of machine learning models. You will face this quality issue as decline of prediction accurracy. So you also need to monitor distribution of input data as well as model training metrics in machine model training.

The third example often happens when there is some issue in data processing instead of data itself. I support your company monitor some KPIs using BI tool to make better decisions. If you aggregate your data wrongly, you definitely make wrong decitions.

以上のようにデータ品質に問題があることが分かった場合、システムの不具合や間違った意思決定といった一次な被害が発生するだけでなく、機械学習モデルやBIの前処理で問題を解決する必要性が発生することで、作業コストの増大や生産性の低下に繋がる二次被害の問題が出てきます。問題が表面化する前から自分たちが活用しているデータの品質を把握し、改善の手を打っておくことが重要だと言えます。

# データ品質計測のOSS

さあ、データ品質を改善したいと思った際にまず取り組むべきは計測です。改善対象の現状を把握し、どこにどういう問題が発生しているかを理解できれば、取りうる改善のアプローチも自ずから見つかってきます。

データ品質を計測する際に使うのが、Data Qualoty Profilingと呼ばれるツール群です。最近では、高価な商用ツールでなくても以下のようにOSSで便利なものが出ています。まずは小さく始めてみたい場合にはOSSを活用すると良いと思います。

* Amazon Deequ https://github.com/awslabs/deequ
* Great Expectations https://greatexpectations.io/

# Deequの内部的な仕組み

* Deequへの入力は計測対象のData（図の左）と利用者が定義したデータ品質の特性（Data Quality Constraints図の上）です。
* これら入力を元に品質特性の検証(Constraints Verification; 図の中央左上)を行ったり、メトリクスを計測（Metrics Computation; 図の中央下）します。
* 出力はデータの品質計測結果のレポート（Data Quality Report; 図の右）とメトリクス(Metrics; 図の右)です。

![Deequコンポーネントの概要](https://storage.googleapis.com/zenn-user-upload/5fx3n2cmshxd19hrnqs0ldxp10ma)

[Deequコンポーネントの概要](https://aws.amazon.com/jp/blogs/news/test-data-quality-at-scale-with-deequ/) - AWS blogより引用

# Deequの応用例 - SageMaker Data Quality Monitor

なお、Deequ は AWS の ML Ops サービスである SageMaker の機能である [Data Quality Monitor](https://docs.aws.amazon.com/sagemaker/latest/dg/model-monitor-data-quality.html) に使われています。SageMaker のヘビーユーザの方であれば、知らないうちに使っているかもしれません。

# DeequとGreat Expectationsの共通点

これらのツールは、基本的なアプローチとしては非常に似ています。

（注：本記事のコード例は全てDeequのものです）

## (1) データのテストを記述する

似たアプローチ1つ目は、データのテストを記述するという点です。

以下はAWSのブログに記載されたDeequのサンプルコードですが、計測対象のデータセットに対して一般的なプログラミング言語の単体テストフレームワークのような形でデータに対する期待値のテストを記述します。

* レコード数
* 最大値・最小値
* NULLを許容するか
* 重複を許容するか
* 許容する値の範囲

ここで言うデータセットは、同じスキーマを共有する構造化データだと考えてください。CSVやRDBのテーブルなどがデータセットにあたり、テストコードでは各列（カラム）に対してテスト項目を設定しています。テスト項目は同じ列のすべてのレコードに対して実施されます。

もし計測対象のデータが期待に沿わない場合は、テストが失敗し、エラーの内容を確認できます。この1つ目のアプローチは、前述のデータ品質の問題の1つ目、データが不正確あるいは不正であることによって発生するシステム上の問題を検出できます。

https://aws.amazon.com/jp/blogs/news/test-data-quality-at-scale-with-deequ/

```scala
import com.amazon.deequ.{VerificationSuite, VerificationResult}
import com.amazon.deequ.VerificationResult.checkResultsAsDataFrame
import com.amazon.deequ.checks.{Check, CheckLevel}

val verificationResult: VerificationResult = { VerificationSuite()
  // data to run the verification on
  .onData(dataset)
  // define a data quality check
  .addCheck(
    Check(CheckLevel.Error, "Review Check")
      .hasSize(_ >= 3000000) // at least 3 million rows
      .hasMin("star_rating", _ == 1.0) // min is 1.0
      .hasMax("star_rating", _ == 5.0) // max is 5.0
      .isComplete("review_id") // should never be NULL
      .isUnique("review_id") // should not contain duplicates
      .isComplete("marketplace") // should never be NULL
      // contains only the listed values
      .isContainedIn("marketplace", Array("US", "UK", "DE", "JP", "FR"))
      .isNonNegative("year")) // should not contain negative values
  // compute metrics and verify check conditions
  .run()
}

// convert check results to a Spark data frame
val resultDataFrame = checkResultsAsDataFrame(spark, verificationResult)
```

## (2) メトリクスを計測できる

似たアプローチ2つ目はデータのメトリクス計測です。

以下もAWSのブログに掲載されているサンプルコードです。以下のコードでは計測対象のデータセット（テーブル）に対して以下のようなメトリクスを計測しています。

* レコード量
* NULLの有無
* 重複の有無、数
* 中央値
* 許容する値の範囲に収まっている数
* カラム間の相関

```scala
import com.amazon.deequ.analyzers.runners.{AnalysisRunner, AnalyzerContext}
import com.amazon.deequ.analyzers.runners.AnalyzerContext.successMetricsAsDataFrame
import com.amazon.deequ.analyzers.{Compliance, Correlation, Size, Completeness, Mean, ApproxCountDistinct}

val analysisResult: AnalyzerContext = { AnalysisRunner
  // data to run the analysis on
  .onData(dataset)
  // define analyzers that compute metrics
  .addAnalyzer(Size())
  .addAnalyzer(Completeness("review_id"))
  .addAnalyzer(ApproxCountDistinct("review_id"))
  .addAnalyzer(Mean("star_rating"))
  .addAnalyzer(Compliance("top star_rating", "star_rating >= 4.0"))
  .addAnalyzer(Correlation("total_votes", "star_rating"))
  .addAnalyzer(Correlation("total_votes", "helpful_votes"))
  // compute metrics
  .run()
}
```

## (3) Spark上で動作するため大規模データに対応できる

DeequはSpark上に構築されており、大規模データにも対応できます。

また、Great Expectationsも複数種類のデータソースに対応しており、対応データソースの中にSpark dataset（Spark SQLで作ったData Frame）も含まれています。

https://docs.greatexpectations.io/en/latest/guides/how_to_guides/configuring_datasources/how_to_configure_a_self_managed_spark_datasource.html

## (4) Airflowなどワークフローツールと連携できる

データ品質の計測や検証を自動化したい場合、Airflowのようなワークフローツールでバッチジョブを作成し、バッチジョブからデータ品質計測のジョブを実行する必要があります。両ツールともワークフローから利用しやすくなっていると言えます。

* Deequ・・・Sparkを前提としています。AWSでSparkを手っ取り早く使う方法がGlueです。Deequでデータ品質計測を行うモジュールをGlueジョブとして実装・デプロイすれば、Boto3でジョブの実行を行うことができます。ここまでできるとあとは、Glue jobの起動を行うだけなので、Airflow以外を含むワークフローで簡単に利用できます。

* Great Expectations・・・Great Expectationsを[Airflowから利用するためのOperator](https://docs.greatexpectations.io/en/latest/guides/workflows_patterns/deployment_airflow.html)が提供されています。

# DeequとGreat Expectationsの違い

両者のツールがよく似ていることが分かったところで、両者の違いについても説明します。

## (1) Deequはすぐさま本番環境にデプロイ可能でテストのコーディングが不要なサンプルが提供されている

私のチームでは、最終的にDeequの方を選択しましたが、その決定的な理由の1つが、Deequの方がデータ品質テストのコーディングが不要で、本番環境へのデプロイができ、すぐに使えるコードサンプルが提供されていたことです。

https://github.com/aws-samples/amazon-deequ-glue

このコードサンプルをチェックアウトして、Admin権限のあるIAM Userを指定して以下のスクリプトを実行するとデータ品質の計測が必要な一式がAWS上にデプロイされます。

```
cd ./src
./deploy.sh -p <aws_profile> -r <aws_region>
```

デプロイされてできる環境の構成は以下の通りです。

![Deequコンポーネントの構成](https://storage.googleapis.com/zenn-user-upload/z58okv3vl8xa384urfy63430ba70)

[Deequコンポーネントの構成](https://github.com/aws-samples/amazon-deequ-glue) - AWSのGithunレポジトリより引用

* ジョブの起動はCloudWatchによって行います（図の①）。
* Deequを使ったデータ品質・メトリクス計測ジョブのワークフローはStep Functionsによって実装されています（図の②）。
* ワークフローが起動すると、まず Suggestions Job (図の③.a)が起動します。これは現状のコードを見て、データ品質の制約がDynamoDB上に展開されます。データ品質の制約は、前述の通り、カラムのデータ型やNULLを許容するかどうかといった対象データへの期待と言っても良いかもしれません。本来はテストコードとして記述する内容ですが、本サンプルではDynamoDB上の設定値として展開され、すでに実装済みのテストコードへの入力として処理されます。DynamoDB上の設定値は、Amplify上に構築されるWeb UIで変更・追加することが可能です。
* テストの入力ができたところで、Verification Job（図の③.b）が実行されます。これにより実際のデータが期待に沿っているのか検証が行われます。検証結果（NULLを許容しないカラムにNULL値があったなど）はS3バケットにpaquet形式で出力されます。
* 次にProfiler job（図の③）でメトリクスの計測が行われます。この結果も先ほどと同じくpaquet形式でS3バケットに出力されます。
* 計測・検証結果がS3に出力されたところで、Step Functionsの次のステップとしてLambda関数がGlue Crawlerを起動します（図の④）。Glue Crawlerは図③の出力結果をGlue Data Catalogに取り込みます。これでAthenaでクエリ可能になるので、同時にお使いのBIツールで分析することが可能になります。
* なお、Deequジョブが計測・検証する対象データは、事前にGlueテーブルとして登録しておく必要がある点に注意してください。

上記が、Deequのサンプルのデプロイや使い方の概要です。ささっとデプロイして始められる点はお分かりいただけたと思います。

一方で、Great Expectationsの方は、上記のようなサンプルが存在しないので、[チュートリアル](https://docs.greatexpectations.io/en/latest/guides/tutorials.html)を見ていただけばわかる通り、テストコードを自分で記述する必要があります。設定値だけ管理すれば良いDeequと比べてやや敷居が高いと言えます。

## (2) Great Expectationsはテスト結果可視化ダッシュボードが提供されている

Deequから見てGreat Expectationsの方が優れていると感じたところは、専用のBIツールが最初からついていることです。これは色んな人に使ってもらうには非常に便利です。

![Data Docの画面1](https://storage.googleapis.com/zenn-user-upload/bpisbxgfvsoh0h0enfnh135pnjq5)

![Data Docの画面2](https://storage.googleapis.com/zenn-user-upload/chkegg4ady7y9n2u30q566s3t5eq)

Data Docの画面例 - [GEのWebサイト](https://docs.greatexpectations.io/en/latest/reference/core_concepts/data_docs.html)より引用

# データ品質改善プロセスの回し方

OSS のデータ品質改善ツールやその機能が分かったところで、私のチームが実際に Deequ を使ってどう改善プロセスを回しているかご紹介します。

## 前提

* データ分析系のデータは、社内でデータレイクと呼んでいる中央ストレージ（実装はS3）に全て生データと加工済みのデータともに保管してあります。
* 社内の公式データウェアハウスは、Snowflake を使っていますが、ちょっとした用途で S3 の生データを調べたい要件があるので、データレイクに蓄積した生データは漏れなくGlue Data Catalogに登録して、Athenaで検索可能になっています。

## プロジェクトの当事者

* データエンジニア（私のことです）
  * データレイクとデータウェアハウスの整備を行いました。
  * 上記のDeequのサンプルを一部改変したものをAWS上にデプロイし、週一でデータ品質計測のジョブを実行するワークフローをAirflowで組みました。
* データステュワート
  * データ品質に限らず、組織内でデータ利活用を促進する役割です。
  * データ品質上に問題が見つかった場合は、関係者を招集して解決にあたります。
  * データ関係があまり成熟していない組織であるため、私がこの役割も兼務しています。
* データオーナ
  * 生データをデータレイクに提供しているシステムの担当者や、該当データが生成される背景となる業務に詳しい人です。
  * 対象データによって変わりす。

## データ品質計測サイクル

* データ品質を計測したい対象を選びます。全体のデータ量が限られている場合は、Glue Data Catalog に登録されている全てのデータを対象にしても良いですが、量が多い場合は、Deequジョブが現実的な時間で終わるように制限する必要があります。
  * 同じデータに対して何度も計測をかけてもしょうがないので、計測対象データのGlueテーブルに日次パーティションをもうけ、未計測のパーティションのみ計測するようにワークフローを組むと良いでしょう。
* 最初期は、データ制約（Deequの入力であり、対象データの特性に対する期待）は手元にないので、まずはDeeqジョブをかけて、Deequにデータ制約（Constraint Suggestions）とその検証結果を生成してもらいます。そうすると現状手元にあるデータ分から分かる制約と結果が出るので、まずはそこでおかしな点はないかを確認します。
  * 制約自体がおかしい場合は、DynamoDB上のプロパティで無効にします（レコードは削除せずに、計測や検証対象から外す）。
  * データ品質に問題がある場合は、データオーナに相談してデータ自体を直します。
* 私のチームでは、データ品質計測を週に1回やっており、データオーナ含む関係者にデータ品質状況の報告を月に1回やっています。
  * その際に関係者に提示するのは、簡単なメトリクス（レコード量の推移）、両制約違反の数の推移、具体的に違反になった制約の例など。

# 最後に

本記事では、データ分析や機械学習において重要となるデータ品質を計測する意義・ツール・プロセスなどを紹介しました。

私のチームでも最近始めたばかりなので、主にツールの使い方などしかノウハウがないので、プロセス・メトリクス・組織運営などでノウハウがたまり次第、また記事にしたいと思います。

本記事が皆様の改善活動の参考になりましたら幸いです。
