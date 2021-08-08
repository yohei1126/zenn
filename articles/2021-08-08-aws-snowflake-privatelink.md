---
title: "AWS Private Link を使って AWS と Snowflake 間のデータ転送コストを削減する"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [aws,network,vpn,snowflake]
published: true
---

# 本記事の背景 - 「AWS から Snowflake にデータを転送すると高額だと聞いたけど本当？」と言われた

著者の所属では、2020年末頃にデータウェアハウスとして Snowflake を導入しました。

Snowflake 導入にあたって、顧客データ管理に厳格な業種のため、自社の Snowflake アカウントを外部インターネットごしに利用せず、自社の AWS アカウントと AWS Private Link を使ってプライベートネットワーク越しに使うことを決断しました。

AWS Private Link は外部の AWS アカウントと VPC 同士で接続できるサービスであり、以下の記事にあるとおり、インターネットを経由せずに自社の AWS アカウントと Snowflake の間でデータのやりとりができます。

（注）自社のネットワークと自社の AWS アカウントの間は、以前から AWS Direct Connect で接続していますので、社員は会社の VPN に接続すると追加のソフトウェアや設定なく Snowflake の Web UI に接続できます。

![AWS Private Link](https://storage.googleapis.com/zenn-user-upload/4c969ae042ba10df5f917943.png)

（参考）Snowflake での AWS Private Link 利用について https://www.snowflake.com/blog/privatelink-for-snowflake-no-internet-required/

ここまでできた後、英系の企業との合併が決まり、合併先企業のオンプレの DB からデータを Snowflake に移動させることになりました。この時、合併先の企業の人は AWS と Snowflake の両方に詳しい人がいないので、私がクラウドマイグレーションをリードしていました。その際に聞かれた質問の 1 つが、「AWS から Snowflake にデータを転送すると高額だと聞いたけど本当？」でした。

おそらく AWS からインターネットに出て行くルートでデータを転送する際の話をしているんだと理解しました。すでに Private Link を導入しており、インターネットを通さずに Snowflake へデータを転送するようになっているので、そのケースには当たらないと思いましたが、念の為、改めてコストを確認しました。

そこで、本記事は、調査の結果をもとに以下を比較した結果を紹介します。

* インターネットを経由して外部にデータを転送する場合
* Private Link を通じて外部 AWS アカウントの VPC にデータを転送する場合 ← 筆者のケース

また Private Link を利用できるようにする場合、Snowflake の Business Critical エディションを利用する必要がある点について紹介します。

# 外部インターネットとデータ転送した場合のコスト

まずは自社の AWS アカウントから外部インターネットへデータを転送する場合のコストについて紹介します。

Snowflake を利用する場合、通常、自社の S3 バケット上にデータを上げ、そこから Snowflake へバルクロードする、もしくは Snowpipe でロードするので、S3 のデータ転送コストについて紹介します。

以下はシンガポールリージョンの S3 のデータ転送コストです。https://aws.amazon.com/s3/pricing/

* インターネットから S3 に入る場合は無料
* S3からインターネットに出て行く場合
  * 1GB / 月まで無料
  * 次の 9.99 TB / 月まで $0.12 / GB = $120 / TB
  * 次の 40 TB / 月まで $0.085 / GB = $85 / TB
  * 次の 100 TB / 月まで $0.082 / GB = $82 / TB
  * 150 TB / 月から $0.08 / GB = $80 / TB  

![S3 とインターネットとのデータ転送コスト](https://storage.googleapis.com/zenn-user-upload/6f32eb43d76d60634b672b5f.png)

# Private Link 経由でデータ転送した場合のコスト

Private Link を利用する場合、自分の VPC に VPC エンドポイントを作成し、Private Link が接続された先の Snowflake の VPC に対してプライベートネットワーク経由でデータを転送できます。

その際のデータ転送コストは以下を参照ください。 https://aws.amazon.com/privatelink/pricing/

* まず固定費として VPC エンドポイントの必要がかかります。
  * AZ ごとに $0.013/hour
  * 筆者の場合、Snowflake 社のドキュメントを参考にエンドポイントを2個作り、3 AZに配備しているため、2 * 3 * 24 (hour) * 31 (days) = $58.032 / month   
* 次にデータ転送量に応じたコストについて
  * 最初の 1PB / 月について $0.01 / GB = $10 / TB
  * 次の 4PB / 月まで $0.006 / GB = $6 / TB
  * 5PB 以上 $0.004 / GB = $4 / TB 

![Private Link](https://storage.googleapis.com/zenn-user-upload/25ff1a28546914da649bc903.png)

# 比較結果

以上、比較した結果、　Private Link を使った方がデータ転送コストを 1/10 - 1/20 に抑えることがわかりました。

# Private Link を使うための Snowflake 側の追加コスト

以上まで比較したのは、Private Link を使う場合と使わない場合の AWS 側のデータ転送コストでしたが、Private Link を使う場合は、Snowflake 側のインフラコストが変わりますので、注意が必要です。

https://www.snowflake.com/pricing/pricing-guide/

こちらの価格ガイドを見ると、Private Link が利用できるのは、Business Critical エディションからです。
エディションによって　Virtual Warehouse の credit 単価が変わり、Private Link を使うためには1つ下のエディションより 35% 高く高額になります。

* Enterprise = $3.70
* Business Critial = $5.00

# 結論

今回は、社内からの質問をもとに AWS と Snowflake の間のデータ転送コストについて、インターネット越しの場合、Private Link を使う場合の 2 つについて比較した結果をまとめました。

また、Private Link を使う場合、Snowflake を Business Critical エディションにする必要があり、1 個下のエディションから Virtual Warehouse のコストが上がる旨も紹介しました。

実際に Snowflake を利用する際は、まずインターネット越しに使うべきか考えましょう。インターネット越しに DWH を使う場合、外部からの攻撃を受けるリスクが高まります。通常は、それを防ぐ目的で DB や DWH をプライベートネットワーク内で使うべきだと判断します。
Private Link を使った際のデータ転送コストの割引は副次的なメリットだと考えた方が良いと思います。

以上、本記事が皆様の検討の参考になれば幸いです。
