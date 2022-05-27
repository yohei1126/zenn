---
title: "Snowflake の Terraform プラグインでデプロイする際の認証に暗号化済みキーペア認証を使う"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: true
---

# 背景

[Snowflake 社公式の Terraform プラグイン](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs)は [Go Snowflake Driver](https://docs.snowflake.com/en/user-guide/go-driver.html) で実装されており、Terraform コマンドの認証にはドライバでサポートしている認証方式は全てサポートしています。

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#authentication

> The Snowflake provider support multiple ways to authenticate:
> Password
> OAuth Access Token
> OAuth Refresh Token
> Browser Auth
> Private Key
> In all cases account, username, and region are required.

このうち筆者の所属では、Terraform を使ったデプロイ自動化には、セキュアな秘密鍵を利用しています。
筆者が Snowflake と本 Terraform プラグインを自社に導入し始めた 2021 年 2 月時点では、以下の Q&A の通り、まだ暗号化済みで複合にパスフレーズが必要な秘密鍵はサポートされていませんでした。暗号化していない秘密鍵を認証に使うにあたって、秘密鍵を直接 Git リポジトリに格納すると悪用される恐れがあるため、AWS Secret Manager に保管し、デプロイの際に Secret から取得するなどの対応をしていました。

https://github.com/Snowflake-Labs/terraform-provider-snowflake/discussions/440

しかし、2022 年 5 月時点ではすでに暗号化済みの秘密鍵にも対応しています。本記事では、Terraform プラグインの認証に暗号化済みの秘密鍵を使う場合の手順について紹介します。

# 動作検証環境

本記事の手順は以下の環境で検証を行いました。

* MacOS 10.15.6
* openssl version LibreSSL 2.8.3
* Terraform v1.1.7 on darwin_amd64
* provider registry.terraform.io/snowflake-labs/snowflake v0.33.1

# キーペアを生成する

Snowflake クライアントの認証にキーペアを使う際の手順は以下の URL が参考になります。

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-1-generate-the-private-key

ここで秘密鍵の生成について以下のようなコマンドが例示されています。

```
$ openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8
```

しかし、このコマンドで生成した秘密鍵を利用すると Terraform コマンドを実行する際に以下のようなエラーが出てしまいます。

> could not build dsn for snowflake connection: Private Key could not be parsed: Could not parse encrypted private key with passphrase, only ciphers aes-128-cbc, aes-128-gcm, aes-192-cbc, aes-192-gcm, aes-256-cbc, aes-256-gcm, and des-ede3-cbc are supported: pkcs8: only PBES2 supported

サポート対象の暗号を使って秘密鍵を生成するように推奨しています。

* `aes-128-cbc`
* `aes-128-gcm`
* `aes-192-cbc`
* `aes-192-gcm`
* `aes-256-cbc` 
* `aes-256-gcm`
* `des-ede3-cbc`

この点は、Terraform プラグインのドキュメントでも指摘されており、以下のコマンドが推奨されています。

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#keypair-authentication-passhrase

```
cd ~/.ssh
openssl genrsa -out snowflake_key 4096
openssl rsa -in snowflake_key -pubout -out snowflake_key.pub
openssl pkcs8 -topk8 -inform pem -in snowflake_key -outform PEM -v2 aes-256-cbc -out snowflake_key.p8
```

* 2 つ目のコマンドは RSA 方式の秘密鍵を生成しています。この鍵は暗号化されていません。https://www.openssl.org/docs/man1.1.1/man1/openssl-genrsa.html
* 3 つ目のコマンドは、生成した秘密鍵に対する公開鍵を生成しています。
* 4 つ目のコマンドは、 `aes-256-cbc` という暗号を使って秘密鍵を暗号化しています。暗号化する際にパスフレーズを聞かれます。これは後で使うので保管しておいてください。
  * AES 256 CBC については RFC が公開されていますので、詳しい情報を知りたい方は以下を参照ください。https://datatracker.ietf.org/doc/html/rfc3602

# デプロイ用のユーザに公開鍵を設定する

以下のドキュメントの通り、デプロイの際に利用する Snowflake ユーザに対して、先ほど生成した公開鍵 `snowflake_key.pub` の内容を設定します。

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-4-assign-the-public-key-to-a-snowflake-user

```
ALTER USER terraform SET RSA_PUBLIC_KEY = """xxxxxx"""
```

# Terraform ファイルの provider 設定に秘密鍵を設定する

Terraform プラグインのドキュメントにある通り、Provider 設定の箇所に秘密鍵のパスを指定する必要があります。

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#example-provider-configuration

```
provider "snowflake" {
  username = "terraform"
  account  = "xxx"
  private_key_path       = "./rsa_key.p8"
  role                   = "xxxx"
}
```

本記事では秘密鍵はパスフレーズを使って暗号化されているため、認証の際にはパスフレーズを指定する必要があります。以下のようにドキュメントに記載の通り、パスフレーズは環境変数で指定できます。これは SnowSQL やその他の Snowflake クライアントと同じです。

> If your private key requires a passphrase, then this can be supplied via the environment variable SNOWFLAKE_PRIVATE_KEY_PASSPHRASE.

Terraform コマンドを実行する際は、以下のように環境変数としてパスフレーズを指定してください。

```
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=xxxx terraform plan --out out.tfplan
```

なお、パスフレーズは秘密情報ですので、CICD サービスでデプロイを自動化する際は秘密情報を安全に保管できるサービスを利用しましょう。

# まとめ

本記事では、Snowflake の Terraform プラグインを利用する際に暗号化済みキーペア認証を利用する手順について紹介しましt。

* 秘密鍵の暗号化の要件が厳しくなっています。ドキュメントで解説されている通り、ツールで推奨されている暗号を使いましょう。
* 秘密鍵を暗号化した場合は、Terraform を実行する際にパスフレーズを渡す必要があります。
* パスフレーズは Terraform の環境変数 として実行時に渡すことができます。

本件が Snowflake を利用されている DevOps エンジニアの方の参考になれば幸いです。
