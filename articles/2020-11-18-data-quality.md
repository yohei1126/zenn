---
title: "Amazon Deequを活用したデータ品質の継続"
emoji: "✨"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [deequ,data,quality,measurement,ci/cd]
published: false
---
# Amazon Deequを用いたデータ品質の計測について

筆者は、普段、データエンジニアとしてデータパイプラインの構築やデータ管理を担当しています。最近は、チームからデータ品質の問題（データ不整合など）が発生していると相談を受け、データガバナンス・データ管理の活動の1つとして、データ品質の計測と改善について、ここ1ヶ月ほど調査をしてきました。

その中で使い勝手の良さそうなOSSを2つほど見つけましたが、本記事では特にAWSを使っている人には始めやすいAmazon Deequを中心に計測のアプローチと本番環境の構築について紹介します。

https://github.com/awslabs/deequ

# そもそも品質とは何か？データ品質がなぜ重要か？

Deequの詳細に入る前に、本調査のモチベーションとしてデータ品質の重要さについて説明します。

日本科学技練（品質管理の推進団体）のWebサイトによると品質の定義についてこう言及されています。

> たとえばISO9000では「本来備わっている特性の集まりが要求事項を満たす程度」と表現されています。

https://www.juse.or.jp/tqm/quality/

この表現では、少し分かりづらいですね。今回取り上げるDeequについて紹介した以下のAWS blogの記事では「本来備わっている特性」や「要求事項を満たす程度」の例について以下のように書かれています。
https://aws.amazon.com/jp/blogs/news/test-data-quality-at-scale-with-deequ/

> 不正確または不正なデータは、本番システムに大きな影響を与える可能性があります。データ品質問題の例は次のとおりです。
>* 値がない場合は、本番システムで null 以外の値を必要とするエラー (NullPointerException) が発生する可能性があります。
>* データ分布が変化すると、機械学習モデルで予期しない出力につながることがあります。
>* データの集計を誤ると、ビジネスでの判断を下す際に誤った意思決定につながる可能性があります。

ここで言う「本来備わっている特性」とは、データ利用者がデータに対して抱く期待のことです。その期待に反する状況のことを品質が低い、不正確・不正なデータとなるわけです。

1つ目の例では、データ利用者の期待はデータ項目にNULL値がないことです。一方で実データにNULL値が混在している場合、期待に反しているため、システムの不具合の原因になりうると言うことです。データの質や不具合の内容や会社やプロジェクトによって異なると思いますが、私のチームでデータ品質改善に取り組もうと思った理由もこれに当たります（私のチームの場合はシステム間連携でのデータ不整合）。

2つ目の例は、データ利用者の期待は機械学習モデルのトレーニングに利用している入力データが一定の分布に収まると言う状況です。機械学習モデルはコードだけでなく、入力データも影響を受けるため、入力データの分布の変化によって出力が変わってしまう可能性があります。この出力の変化が機械学習モデルの予測精度の低下として現れるとそれは機械学習システムの品質上の問題になります。

３つ目の例は、データそのものと言うよりデータの加工に問題があった場合だと思います。BIなどのツールを使ってKPIをモニタすることで経営やプロダクトマネジメントなどの意思決定を行っている企業は多くあると思います。その際、データ集計に問題があり、不正確なKPIを参照していた場合、間違った意思決定を行う可能性があります。

以上のようにデータ品質に問題があることが分かった場合、システムの不具合や間違った意思決定といった一次な被害が発生するだけでなく、機械学習モデルやBIの前処理で問題を解決する必要性が発生することで、作業コストの増大や生産性の低下に繋がる二次被害の問題が出てきます。問題が表面化する前から自分たちが活用しているデータの品質を把握し、改善の手を打っておくことが重要だと言えます。

# データ品質計測のOSS

さあ、データ品質を改善したいと思った際にまず取り組むべきは計測です。改善対象の現状を把握し、どこにどういう問題が発生しているかを理解できれば、取りうる改善のアプローチも自ずから見つかってきます。

データ品質を計測する際に使うのが、Data Qualoty Profilingと呼ばれるツール群です。最近では、高価な商用ツールでなくても以下のようにOSSで便利なものが出ています。まずは小さく始めてみたい場合にはOSSを活用すると良いと思います。

* Amazon Deequ https://github.com/awslabs/deequ
* Great Expectations https://greatexpectations.io/

Deequの内部的な仕組みの図です。

* Deequへの入力は計測対象のData（図の左）と利用者が定義したデータ品質の特性（Data Quality Constraints図の上）です。
* これら入力を元に品質特性の検証(Constraints Verification; 図の中央左上)を行ったり、メトリクスを計測（Metrics Computation; 図の中央下）します。
* 出力はデータの

![Deequ Architecture](./deequ.png)

# DeequとGEの共通点

これらのツールは、基本的なアプローチとしては非常に似ています。

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

# DeequとGEの違い

## Deequはすぐさま本番環境にデプロイ可能なサンプルが提供されている

## GEはテスト結果可視化ダッシュボードが提供されている

