---
title: "Snowflake Cloud World Tour Singapore　に参加した"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: true
---

2023 年 8 月 3 日にシンガポールで開催された Snowflake Cloud World Tour Singapore に参加しましたので、その際に見聞きしたことについて特に自分が気になった点について紹介します。

# Snowflake Cloud World Tour イベント概要について 

Snowflake Cloud World Tour は、年に 1 回開催される Snowflake Summit の後に世界各地で開催されるローカルイベントであり、 US 本社の Product Manager がサミットで発表された内容を紹介したり、ローカルのユーザの取り組みを紹介したり、 Data Hero アワードの表彰を行ったりする目的で開催されるイベントです。

https://www.snowflake.com/events/data-cloud-world-tour-singapore/
https://www.snowflake.com/summit/save-the-date/

Snowflake Cloud World Tour はコロナ期間中は開催されていなかったようです。昨年は自分の記憶が正しければ開催されておらず、 Data Hero Award の授賞式も比較的小規模に開催されましたが、今年は Snowflake Cloud World Tour が大々的に開催され、アワード授賞式もキーノート後に盛大に開催され、イベントも正常化されて良かったなと思います。

また、以前から開催されている Data for Breakfast イベントに比べて、広いコンベンションセンターを利用しており、以前のイベントより多くのパートナーがブースを設置しており、各種ソリューションの説明を受けることができました。

# DevOps 関係 - Git 統合、 Snowpark Container Services 

ここからはイベント最中に紹介されていた内容について紹介していきます。

今回のサミットでは、 Git 統合、 Snowpark Container Services など、自分がよく仕事上担当している DevOps 関係に影響がある発表が多かったと思います。

https://www.snowflake.com/blog/snowflake-expands-developer-programmability-snowpark-container-services/
https://www.snowflake.com/blog/snowpark-container-services-deploy-genai-full-stack-apps/

現状だと、自社で dbt モデルをデプロイする際、 Snowflake と連携する Python アプリケーションを稼働させる場合、 Airflow など特定のツールとの蜜結合を防ぐため、またポータブルなアプリケーション実行の仕組みを担保するため、一度、 Snowflake の外 (AWS 側) でコンテナイメージをビルドし、 ECS などコンテナサービス上で実行する仕組みを採用しています。

もし、将来的に　Git 統合と Snowpark Container Services が GA となると、以下のような開発スタイルが一般的になる可能性があり、開発生産性向上に大きな影響があるのでは？と予想し、大変続報を楽しみにしています。

* Snowflake のワークシートで git clone して、ソースコーとを取得する。
* そのままワークシート上で開発して、 git push し、変更を Merge/Pull Request でデプロイ用のブランチにマージする。
* ブランチの変更を Snowflake が自動的に検知し、イメージをビルドし、 Snowflake 上のコンテナレジストリにイメージを push する。
* タスクなどの仕組みを使い、コンテナのスケジューリング・デプロイも Snowflake 上でできるようになる。
* よって開発、 CICD 、コンテナのデプロイ、スケジューリングなどで外部のサービスが不要になる。

# ML 関係

Snowpark 登場以前は、 Snowflake 事体に ML 関係のワークロードをサポートする機能がなかったので、外部のソリューション (SageMaker や DataRobot など）にデータを移動させ、 ML 関係のワークロードを走らせることが多かった Snowflake ユーザも多かったと思いますし、自社も実際  SageMaker を使っています。

このスタイルは、それぞれ得意分野が違うサービスを組み合わせることで、開発速度を上げる恩恵はありましたが、せっかく Snowflake 上でデータガバナンスのモデルを構築しても、 Snowflake の外にデータを出すことで、 Snowflake 上のデータガバナンスモデルを適用できない、あるいはデータを出した場所でもガバナンスモデルを構築する必要がある問題がありました。

一方で、 Snowflake 上で ML 関係の機能がを拡充されていくことで、データを外部に出す必要性がなくなり、常に同じデータガバナンスモデルの中でデータ管理できるメリットが実現でき始めているのではと感じました。

また、イベントではユーザのペルソナを特定し、ペルソナごとに必要な機能を提供すると紹介がありました。

例えば、データアナリスト向けには、 ML Powered Functions と呼ばれる ML ベースの関数（予測、異常検知、など）を SQL の中で利用できるようにしたそうです。新規に ML モデルを構築する必要もなく、すぐに SQL 中で利用できるため、非常に簡単です。

https://www.snowflake.com/blog/ml-powered-functions-improve-speed-quality/

一方、 ML エンジニアやデータサイエンティストなど、特定用途向けの ML モデルを構築したい人向けには、 ML Modeling 用の Snowpark API が提供され、さらに人気のある ML Framework をサポートされています。各種ライブラリは Snowflake 組み込みの Anaconda リポジトリで整備しているので、パッケージ依存関係解決に悩む必要がない点も開発生産性の点で非常に嬉しい点です。将来的には構築した ML モデルのワークロードをコンテナサービス上で動かせるようになります。

https://docs.snowflake.com/en/developer-guide/snowpark-ml/index

# LLM / Gen AI

従来の LLM 関係の課題として、以下のようなものがあるそうです。

* OSS の LLM モデルを自前でホスティングすると、オペレーションコストが高い。
* 外部 LLM サービス (Open AI など)を利用する場合、機密データを外部に晒すリスクがある。

そういった状況に対して、3種類の LLM Snowpark Container Services にデプロイできるオプションを用意しているそうです。

* OSS LLM
* 商用 LLM
* Snowflake　特有な LLM

ここで、商用 LLM は、外部のベンダーが Native App Framework を用いて構築した LLM であり、ユーザは Marketplace で購入し、自社のアカウントにデプロイできます。プロダクトマネジャーによると、制限された環境内でアプリを動かせるため、
* 自社のデータへのアクセスを制限できるため、機密データに不正アクセスされるリスクがない。
* LLM ベンダー側も知的財産への不正アクセスを防止できるので、知的財産の流出を防ぐことができる。
といったメリットがあります。

Snowflake　特有な LLM については、Snowflake 社で構築された LLM が Snowflake 上にデプロイされており、 Document AI といった形で、ユーザはモデルを構築せず、 ML Powered Functions　として即座に利用できます。

https://www.snowflake.com/blog/generative-ai-llms-summit-2023/

この Snowpark Container Services と Native App Framework を組み合わせた構成は非常に汎用性が高く、　LLM といった文脈以外にも適用できる非常に優れた構造のソリューションだと思いました。今後も違った分野で同様の構造で新しいソリューションが展開されそうな予感がしており、非常に楽しみです。

# ストリーミング

従来の Snowpipe はマイクロバッチとして動いており、外部ストレージにファイルとして書き込まれたイベントで駆動して稼働するスタイルでした。 COPY コマンドによるバルクロードよりはレイテンシが小さいものの、リアルタイム処理に比べるとレイテンシが大きい課題がありました。

一方で、 Snowpip Steaming は Kafka Connect として稼働し、レコード単位で連携できるため、より小さいレイテンシでデータを投入できるメリットがあります。

https://www.snowflake.com/blog/snowpipe-streaming-public-preview/?lang=ja

Snowflake のユーザコミュニティでもコスト面や内部実装について議論があり、

* ストリーミング、リアルタイムシステムは、バッチのバルクロードに比べて、高額になりやすいので、どの程度のコストになるのか事前に見積りが重要。
* Snowpipe Streaming の内部実装はアナリティクス向けのウェアハウスに対するデータ処理と全く違う仕組みでできているとのコメントがありました。
  * 具体的には、 SDK が直に内部ステージに　Arrow　形式でデータを置き、メタデータを更新するだけ。
  * 参照側は Mixed Table としてマイクロパーティションと Arrow のデータを両方を読みに行くことになる。
  * 適切なサイズまでデータがたまったらバックエンドで非同期にマイクロパーティションにマージされる。

この議論を通して、あまりに内部実装が違いすぎる上に、列指向と行指向を併せ持った構造になっているため、実は内部では Unistore は完成しているのではないかとの噂も飛び交いました。

なお、別の勉強会でこの仕組みを紹介したところ、一時場所にデータを書き込み、参照側には両方参照させ、データが貯まると本来の場所に非同期で書き込むやり方は Hadoop コミュニティでも過去に見られた手法らしく、 OLAP 系システムでレコード単位でデータを取り込むストリーミングに対応する際の定番テクニックだったのかもしれません。ご存知の方いらっしゃれば教えてください。

# 終わりに

今回は、イベントで発表された内容に対して、個人の意見やコミュニティの意見を交えて紹介してみました。
自社の仕事では、 DevOps 関係に関わることが多いので、アプリケーションのデプロイの観点で開発生産性の向上が想定できる新機能については今後試して、 zenn でも紹介していきます。お楽しみに。
