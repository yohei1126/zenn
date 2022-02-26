---
title: "AWS PrivateLink を使った AWS と Snowflake 間のプライベート接続環境の構築"
emoji: "❄️"
type: "tech"
topics: [snowflake,aws,privatelink,network,security]
published: true
---

# 記事の背景

Snowflake でアカウントを作ると、デフォルトではインターネットに公開されたパブリックな Web UI や API のエンドポイントに接続して利用することになります。しかし、金融業界などセキュリティ要件の厳しい業界では、外部から直接サイバー攻撃を行える境界を減らすため、システムへの接続方法としてプライベート接続を求められることが多くあります。

この時、Snowflake アカウントのデプロイ先および自社の利用クラウドサービスの両方が AWS の場合、プライベート接続を実現する手段として利用できるのが [AWS PrivateLink](https://aws.amazon.com/privatelink/) です。Private Link を使うと、自社 AWS アカウントと Snowflake の AWS アカウントの VPC （プライベートネットワーク）通しをプライベート接続できます。これにより、デフォルトのパブリックエンドポイントへの接続は Snowflake の[ネットワークポリシー](https://docs.snowflake.com/en/user-guide/network-policies.html)で接続不可にした上で、プライベートネットワークに接続できる環境にいる人のみ Snowflake に接続できるようになります。

この時、PrivateLink が支援してくれるのは、あくまで両 AWS アカウントの VPC をプライベート接続する箇所だけであり、自社ネットワークから、あるいはAWS VPC の中から PriavteLink が適用された VPC のエンドポイントに接続する部分は、自社あるいは AWS のネットワークサービスを利用して実現する必要があります（後述のネットワーク構成例を参照）。実現の方法は、以下の URL を参照いただくと、詳細が書いてありますので、興味ある方はご参照ください。

AWS PrivateLink & Snowflake https://docs.snowflake.com/en/user-guide/admin-security-privatelink.html

プライベート接続の手順そのものはドキュメントにある内容を順に沿ってやれば実現できます。しかし、AWS や自社のネットワーク知識が浅い状態で取り組むと、非常に難しく、理解が困難です。筆者が自社にプライベート接続を導入した際は、筆者の前提知識が乏しいため理解に苦しみ、インフラエンジニアや Snowflake 社のテクニカルサポートの方に支援いただいて、なんとかやり切りました。一方で、全体としてどういう仕組みでプライベートを接続しているのかを理解した上で実現に取り組むと、もう少し環境構築がスムーズにできるのではないかと思い、事前に知っておくべきコアの部分を記事にしようと考えました。

# 前提となるネットワーク構成例

プライベート接続する環境のネットワーク構成を以下とします。本来のネットワーク構成ではもっと細かく書くと思いますが、私自身がネットワークを専門としていないし、ここでは概念レベルで説明したいと考えているため、詳細は省略してあります。

![Snowflake PrivateLink](https://storage.googleapis.com/zenn-user-upload/ed2a7f819fee-20220213.png)

ネットワーク構成は以下の通り（図の左から）

* 社外から社内ネットワークに接続する場合は、VPNを利用する。
* 社内ネットワークには専用の DNS サーバがあり、社内外のシステムに対して新規に DNS 名を設定したい場合は、ここで名前解決を行う。
* 社内ネットワークと自社の AWS アカウントは [Direct Connect](https://docs.aws.amazon.com/directconnect/latest/UserGuide/Welcome.html) で接続する。
* 自社の AWS アカウントの VPC 内で名前解決を行う場合は、Route 53 の Private Hosted Zone にドメインを作り、DNS 名などを作る。
* 自社の AWS アカウントと Snowflake の AWS アカウント間は PrivateLink で接続する。
  * 自社の AWS アカウントの VPC から Snowflake のエントポイント（API、ステージなど）にアクセスする際は、自社 AWS アカウントの VPC 側にある [VPC エンドポイント](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html) を通じて接続する。

# Snowflake プライベート接続の仕組み

ここで Snowflake のプライベートエンドポイントは当然、Snowflakeのアカウント単位で異なり、パブリックな DNS には登録されていません。よって、Snowflake のプライベートエンドポイントを VPC エンドポイントの URL に名前解決することでトラフィックを転送し、アクセス可能にする必要があります。その際、社内ネットワークからは自社の DNS サーバ、AWS VPC からの接続は AWS Route 53 に CNAME レコードを登録することで、上記の名前解決を行うことができます。

実際のネットワーク設定手順は以下を参照ください。

https://docs.snowflake.com/en/user-guide/admin-security-privatelink.html

# Snowflake へ接続する VPC Endpoint を作成する

VPC エンドポイントを作成する手順は以下を参照。事前に Snowflake のサポートへ AWS アカウントと VPC ID を連絡し、先方の AWS アカウントで接続を許可してもらう必要があります。

https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html

Snowflake の内部ステージ (S3) にアクセスする際は VPC Gateway Endpointを、それ以外のエンドポイントは Interface Endpoint を使います。

* https://docs.aws.amazon.com/vpc/latest/privatelink/vpce-interface.html
* https://docs.aws.amazon.com/vpc/latest/privatelink/vpce-gateway.html

# 自社ネットワークから Snowflake へプライベート接続する

Snowflake にプライベート接続できるのは、AWS VPC エンドポイントからのため、Snowflake のプライベートエンドポイント全てへのアクセスを AWS VPC エンドポイントに転送する必要があります。そのため、以下を設定する必要があります。

* 自社ネットワークから VPC エンドポイントのある VPC へ Direct Connect 経由で接続できるようにする。
* 自社の DNS サーバに Snowflake のプライベートエンドポイントを AWS VPC エンドポイントに名前解決できるように DNS CNAME を設定する。

なお、VPC エンドポイントを通じて接続する必要があるエンドポイントは、`SELECT SYSTEM$GET_PRIVATELINK_CONFIG()` を使って取得できます。https://docs.snowflake.com/en/sql-reference/functions/system_get_privatelink_config.html
また、VPC エンドポイントの URL は AWS コンソールで確認できます。 https://docs.aws.amazon.com/vpc/latest/privatelink/vpce-interface.html

もし、社内ネットワークでファイアウォールがある場合は、VPCの CIDR をホワイトリストに加えておく必要があります。

# AWS VPC から Snowflake へプライベート接続する

AWS VPC から Snowflake へプライベート接続する際も社内ネットワークと同様に Snowflake のプライベートエンドポイント全てへのアクセスを AWS VPC エンドポイントに転送する必要があります。そのため、以下を設定する必要があります。

* プライベートエンドポイントのドメインが `snowflakecomputing.com` のため、Route 53 に `snowflakecomputing.com` の Private Hosted Zone を作成します。Private Hosted Zone は AWS VPC で有効なドメインです。 https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/hosted-zones-private.html
* `SELECT SYSTEM$GET_PRIVATELINK_CONFIG()` を使って取得できたエンドポイントをキーとして全て CNAME として Private Hosted Zone に登録します。レコードの値は、VPC エンドポイントの URL です。

# おわりに

以上、社内ネットワークから、あるいは AWS からプライベート接続で Snowflake へアクセスする際の仕組みや手順を紹介しました。

特に AWS のネットワーク関係のサービスや、プライベートアクセスの仕組みに対する理解が浅い段階で Snowflake の 公式手順書だけを読むと、非常に内容が難しくなります。まずはネットワーク構成図を書いたり、AWS のネットワークサービスを理解した上で、Snowflake 社のサポートや自社のネットワーク担当者の支援を受けて設定すると良いでしょう。

本記事が読者の理解の助けになれば幸いです。
