---
title: "Terraform を使った Snowflake の構成管理"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [snowflake,terraform,infra,code,ioc]
published: false
---

![Snowflake](https://storage.googleapis.com/zenn-user-upload/uo9gtabf5bsfbcs5cievdqfjw0lh)

# 本記事の背景

筆者の会社では、先日、データウェアハウスとして [Snowflake](https://www.snowflake.com/) を導入することになりました。現在、パフォーマンス向上などを理由に、RDS や BI ツールなどで実現されている既存のアナリティクスワークロードを Snowflake に移行しています。

その際、Snowflake 上のオブジェクト（データベース、スキーマ、テーブル、ロールなど）をどうやって作成・管理していくか検討していた所、インフラ構成管理ツールである [Terraform](https://www.terraform.io/) の Snowflake プラグイン「[Terraform Provider: Snowflake](https://github.com/chanzuckerberg/terraform-provider-snowflake)」が OSS で公開されていることに気づき、簡単な PoC の後、現在、実際に本番運用に向けてリソースを作成しています。

本記事では、Snowflake のリソース管理に Terraform を導入することのメリットや、実際に CI/CD プロセスに導入する際の TIPS などをご紹介します。

なお、本記事では Snowflake や Terraform そのものは深く説明しません。興味を持っていただけたら各公式ドキュメントを参照いただけると助かります。

# Snowflake のリソース構成管理に Terraform を導入するメリット

皆さんは、Snowflake 上でデータベース、スキーマ、テーブル、ロールなどを作成する際にどういう手順を取っているでしょうか？公式に提供されている手段としては以下があります。

* (1) Web 画面を操作する
* (2) Web コンソールで SQL クエリを実行する
* (3) CLI で SQL クエリを実行する

これらのうち、(3) のみ以下の理由で自動化やチームでの構成管理と相性が良く、ソフトウェアエンジニアとしては管理しやすく、小規模なチーム開発には導入しやすいと言えるでしょう。

* コードとして記述されるので、現状の構成が分かりやすい。
* シェルや環境変数などと組み合わせると、同じコードを流用しつつ、異なる環境に対応できる。

一方で、以下のような理由により、スマートなやり方ではないので、開発に参加する人数が増えた場合に混乱をきたす可能性があります。

* 状態ロックの仕組みがないので、CIや複数人での作業が競合した場合、意図していない結果になる可能性がある。
* CLI や SQL そのものが複数環境をサポートするものではないので、自作のシェルスクリプトが読みづらくなる。

そこで、上記に挙げた問題を一通り解決する手法として、私のチームでは、Terraform の Snowflake プラグインを導入しました。

* コードによるリソース記述
* 複数人による作業競合を防ぐ状態ロックの仕組み
* 同じコードを流用した複数環境へのデプロイ

# Terraform および Snowflake プラグインの導入

ここからは実際にツールを導入する方法を紹介していきます。前述の通り、Snowflake および Terraform そのものは深く紹介しません。深く知りたい方は、別途、各公式ドキュメントを参照ください。

## Terraform のインストール

CLI のインストール手順は以下を参照ください。

https://learn.hashicorp.com/tutorials/terraform/install-cli

MacOS で brew が使える環境の場合は、インストールが簡単です。

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

もし OS のパッケージマネジャーを使えない理由がある場合は、ビルド済みバイナリをダウンロードして、PATH を通すだけでも利用できます。

https://www.terraform.io/downloads.html

## Snowflake プラグインのインストール

以下のコマンドで最新版をインスチールできます。

https://github.com/chanzuckerberg/terraform-provider-snowflake

```
curl https://raw.githubusercontent.com/chanzuckerberg/terraform-provider-snowflake/main/download.sh | bash -s -- -b $HOME/.terraform.d/plugins
```

# キーペア認証方式の導入

ここからはTerraformでリソースを作成するユーザを作成します。認証方式としてはキーペアを利用します。

人が Web ブラウザでログインする場合、SSO や MFA を利用する方式が便利ですが、CI と組み合わせて利用する場合、自動化と相性が良い方式にする必要があります。自動化できる方式の中では、パスワード認証よりもキーペア認証方式の方がセキュアです。認証方式全般は以下を参照ください。

https://docs.snowflake.com/en/user-guide/admin-security.html

キーペアの作成方法は以下の通りです。詳細はドキュメントを参照ください。

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-1-generate-the-private-key

```
# 秘密鍵（暗号化された PEM フォーマット）を生成する
$ openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8

# 公開鍵（平文の PEM フォーマット）を生成する
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

次に公開鍵をユーザに設定します。以下は `terraform` というユーザを新規作成し、に公開鍵を設定する場合のクエリ例です。この例は簡単のため `SYSADMIN` ロールを設定しますが、チームの方針に合わせて適切なロールを設定してください。

（注）公開鍵の文字列には改行を入れないようにしてください。

```
CREATE USER "terraform" \
  DEFAULT_ROLE = SYSADMIN \
  SET RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...';
```
