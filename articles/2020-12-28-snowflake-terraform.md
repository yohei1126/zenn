---
title: "Terraform を使った Snowflake の構成管理"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [snowflake,terraform,infra,code,ioc]
published: true
publication_name: "dataheroes"
---

![Snowflake](https://storage.googleapis.com/zenn-user-upload/uo9gtabf5bsfbcs5cievdqfjw0lh)

(画像は [Snowflake 公式 Web サイト](https://www.snowflake.com/)のものを流用)

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
* 実際に変更をデプロイする前の差分確認

なお、調査した範囲では、サードパーティのツールで構成管理に利用できるものは他になく、筆者は以前の職場で AWS・GCP などパブリッククラウドの構成管理に Terraform を用いていたので、Terraform を導入することを決意しました。

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

以下のコマンドで最新版をインストールできます。

https://github.com/chanzuckerberg/terraform-provider-snowflake

```
curl https://raw.githubusercontent.com/chanzuckerberg/terraform-provider-snowflake/main/download.sh | bash -s -- -b $HOME/.terraform.d/plugins
```

# キーペア認証方式の導入

ここからはTerraformでリソースを作成するユーザを作成します。認証方式としてはキーペアを利用します。

人が Web ブラウザでログインして Snowflake を利用する場合、SSO やパスワードおよび MFA を利用する方式が便利ですが、CI と組み合わせて利用する場合、自動化と相性が良い方式にする必要があります。自動化できる方式の中では、パスワード認証よりもキーペア認証方式の方がセキュアです。認証方式全般は以下を参照ください。

https://docs.snowflake.com/en/user-guide/admin-security.html

キーペアの作成方法は以下の通りです。詳細はドキュメントを参照ください。

（注）プラグインが暗号化済みの秘密鍵をサポートしていないので、ここでは平文の秘密鍵を生成しています。秘密鍵を平文のまま扱うのは安全ではありません。Git リポジトリで安全に秘密鍵を共有するには、平文の秘密鍵を AWS KMS などで暗号化した上で共有すると良いでしょう。この場合、デプロイしたい人は暗号化された秘密鍵を復号化する必要があります。

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-1-generate-the-private-key

```
# 秘密鍵（平文の PEM フォーマット）を生成する
$ openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt

# 公開鍵（平文の PEM フォーマット）を生成する
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub
```

次に公開鍵をユーザに設定します。以下は `terraform` というユーザを新規作成し、に公開鍵を設定する場合のクエリ例です。この例は簡単のため `SYSADMIN` ロールを設定しますが、チームの方針に合わせて適切なロールを設定してください。

（注）公開鍵の文字列には改行を入れないようにしてください。

```
CREATE USER "terraform"
  DEFAULT_ROLE = SYSADMIN
  SET RSA_PUBLIC_KEY = 'xxxx';
```

#  ローカル環境の構築

ようやくここから Terraform のコードを書いていきます。まずはローカルの環境を設定します。

以下のようなファイルを作成し、初期化コマンドを実行してください。各種ファイルがダウンロードされ、ローカルの環境構築が行われます。

この provider.tf というファイルでは、今回使うプラグインの名前およびバージョンを指定しています。本記事を執筆段階での最新バージョンは `0.20.0`  です。

詳しい設定内容は以下を参照ください。

https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs

```
$ cat provider.tf
terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.20.0"
    }
  }
}
$ terraform init
```

# S3 バックエンドおよび DynamoDB を使った状態ロックの導入

現在の状態では、terraform の設定ファイルがローカルディレクトリにしか生成されておらず、複数人で作業することができません。複数人で成果物を利用できるようにするには、AWS S3 をバックエンドとして設定し、設定ファイルを S3 に出力されるようにします。

また、複数人が同時に作業しようとすると作業が競合し、不正な状態に上書きされるリスクがあるため、AWS DynamoDB テーブルに作業状態を書き込みできるようにします。これにより作業中の人がいた場合は、Snowflake への変更を防止できます。

* https://www.terraform.io/docs/configuration/blocks/backends/index.html
* https://www.terraform.io/docs/backends/types/s3.html

なお、S3 と DynamoDB を利用するためには、以下のような権限を付与した IAM User Credential をローカルで設定しておく必要があります。

（注）筆者は主にシンガポールリージョンを使っていますが、お好きなリージョンを利用ください。また、AWS リソース名は適切な物に変更ください。

* `s3:ListBucket` on `arn:aws:s3:::your-terraform-backend-bucket` 
* `s3:GetObject` on `arn:aws:s3:::your-terraform-backend-bucket/*`
* `s3:PutObject` on `arn:aws:s3:::your-terraform-backend-bucket/*`
* `dynamodb:GetItem` on `arn:aws:dynamodb:ap-southeast-1:*:table/your-terraform-backend-lock`
* `dynamodb:PutItem` on `arn:aws:dynamodb:ap-southeast-1:*:table/your-terraform-backend-lock`
* `dynamodb:DeleteItem` on `arn:aws:dynamodb:ap-southeast-1:*:table/your-terraform-backend-lock`

S3 と DynamoDB に対応した `provider.tf` が以下の通りです。

```
$ cat provider.tf
terraform {
  required_providers {
    snowflake = {
      source  = "chanzuckerberg/snowflake"
      version = "0.20.0"
    }
  }
  backend "s3" {
    bucket         = "your-terraform-backend-bucket"
    key            = "backend/your-sample-project"
    region         = "ap-southeast-1"
    dynamodb_table = "your-terraform-backend-lock"
  }
}

provider "snowflake" {
  username         = "terraform"
  account          = "your_account_${terraform.workspace}"
  region           = "ap-southeast-1"
  # snowflake plugin does not support encrypt version
  private_key_path = "path/to/xx/rsa_key.p8"
  role             = "SYSADMIN"
}
```

なお、ここで `provider "snowflake"` の箇所で、今回のリソース作成に使う Snowflake 側の環境や認証方式について設定しています。

詳しい設定内容は以下を参照ください。

https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs

# workspace を使った環境ごとの可変値の管理

Terraform では、コードを変更せずに複数環境へデプロイするための機能として、workspace という機能が用意されています。

https://www.terraform.io/docs/state/workspaces.html

workspace を利用するには、まず workspace を作成する必要があります。ここでは名前を dev としておきます。

```
$ terraform workspace new dev
$ terraform workspace show
dev
```

先ほどの provider においては　Snowflake アカウント名として
`"your_account_${terraform.workspace}"`と記述しました。これが実際のworkspaceの値を入れた形へ展開されます。例えば、workspace が `dev` の場合は、アカウント名は `your_account_dev` になります。

```
provider "snowflake" {
  username         = "terraform"
  account          = "your_account_${terraform.workspace}"
  region           = "ap-southeast-1"
  # snowflake plugin does not support encrypt version
  private_key_path = "path/to/xx/rsa_key.p8"
  role             = "SYSADMIN"
}
```

また、より高度な使い方としては以下のように環境によって異なる値を一箇所に集約させることが可能です。

例えば、環境ごとに異なるS3バケットやオブジェクトキーからファイルをロードする `stage` を作成したいとします。その場合、環境ごとに可変の設定まとめたファイルとして `locals.tf` を作っておきます。

```
locals {
  env = {
    dev = {
      s3_landing_bucket     = "your-landing-bucket-dev"
      s3_landing_key_prefix = "data/inputs"
      aws_account_id        = "xxx"
    }
    stg = {
      s3_landing_bucket     = "your-landing-bucket-stg"
      s3_landing_key_prefix = "data/inputs"
      aws_account_id        = "xxx"
    }
    prd = {
      s3_landing_bucket     = "your-landing-bucket-prd"
      s3_landing_key_prefix = "data/inputs"
      aws_account_id        = "xxx"
    }
  }
  environment_vars = contains(keys(local.env), terraform.workspace) ? terraform.workspace : "dev"
  workspace        = merge(local.env["dev"], local.env[local.environment_vars])
}
```

`locals.tf` で定義した変数を参照する形で、リソース定義を作成することで、コードを変更することなく環境ごとに設定を変更できます。

例えば、以下は環境ごとに異なる設定を持った `stage` の定義例です。 `stage` の設定については以下のドキュメントを参照ください。https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs/resources/stage

```
resource "snowflake_stage" "your_stage" {
  name                = "your_stage"
  url                 = "s3://${local.workspace["s3_landing_bucket"]}/${local.workspace["s3_landing_key_prefix"]}/your/stage/"
  database            = snowflake_database.your_db.name
  schema              = snowflake_schema.your_schema.name
  storage_integration = snowflake_storage_integration.your_integration.name
```

# その他のリソース作成

データベース、スキーマ、テーブル、ロールなど主要な Snowflake のリソースは、Terraform を使って作成できます。各リソースの定義方法は以下を参照ください。

https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs/resources/table

なお、テーブルの場合は以下のように記述します。

```
resource snowflake_table table {
  database = "database"
  schema   = "schmea"
  name     = "table"
  comment  = "A table."
  owner    = "me"

  column {
    name = "id"
    type = "int"
  }

  column {
    name = "data"
    type = "text"
  }
}
```

# 差分確認およびデプロイ

各種リソースが定義できたところで、実際にデプロイしましょう。一般的な手順は、　`plan` で差分を確認し、 `apply` で実際に変更を反映します。

なお、S3 バックエンドを使った場合は、`plan` の段階でバックエンド上の状態をロックします。タイムアウトするまでは他の人が状態を変更できなくなります。

```
# workspace を選択する
$ terraform workspace select dev
$ terraform init
# 実行計画を作成し、現状との差分を取る
$ terraform plan --out "out.tfplan"
# 問題なければデプロイする
$ terraform apply "out.tfplan"
```

一般的なワークフローとコマンドについては以下を参照ください。

https://www.terraform.io/docs/cli/run/index.html

# Terraform を導入する際の注意事項

今回紹介した Terraform プラグインは、あくまでもサードパーティのツールが OSS として開発されている点を理解する必要があります。

Snowflake 社の公式ツールではないため、Snowflake 社が公式に品質保証をしてるわけではありません。一部機能が Snowlake の機能と適応しておらず、意図しない動作をする場合があります。また、プラグインが最新機能に適用していない場合があります。そういう状況を理解した上で、自分のプロジェクトに合う場合に自己責任で利用するのが OSS の流儀です。

OSS のツールですので、もし意図していない振る舞いを見つけた場合、欲しい機能に対応していない場合は、[Github リポジトリ](https://github.com/chanzuckerberg/terraform-provider-snowflake)でコミュニティに対応状況や今後の予定を質問してみたり、自分で Pull Request を送ったりしましょう。

Terraform プラグインは、言語仕様がシンプルな Go 言語で実装されており、プラグイン自身も構造がシンプルなため、コードを理解するのも簡単ですし、OSS の中では比較的に貢献しやすいプロジェクトと言えます。

# 終わりに

本記事では、Terraform を使って Snowflake のリソースに対して Infrastructure as Code と同じワークフローを適用する方法を紹介してきました。本記事で紹介したアプローチは、複数人でも共同開発や、CI/CD ワークフローでのレビュー・デプロイとの相性も良いと思います。

もし、プラグインを利用していて不明な点あれば連絡ください。
もし、欲しい機能が見つからなかった場合は、ぜひプロジェクトに貢献してください！

https://github.com/chanzuckerberg/terraform-provider-snowflake
