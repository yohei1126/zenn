---
title: "How to use an encrypted private key in Terraform plugin for Snowflake"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: true
---

# Background

[Snowflake official Terraform provider](https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs) is implemented in [Go Snowflake Driver](https://docs.snowflake.com/en/user-guide/go-driver.html), so it can support all the authentication methods supported in Go Driver.

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#authentication

> The Snowflake provider support multiple ways to authenticate:
> Password
> OAuth Access Token
> OAuth Refresh Token
> Browser Auth
> Private Key
> In all cases account, username, and region are required.

I have been using private key for Snowflake resource deployment using Terraform.
When I introduce Snowflake and Terraform provider in my projects in Feb 2021, it did not support encrypted private key for key pair authentication as discussed in the page. To use unencrypted private key for key pair authentication, I had to store the private key in AWS Secret Manager then retrieve the key during deployment, so we do not need to expose the private key in Git repo.

https://github.com/Snowflake-Labs/terraform-provider-snowflake/discussions/440

However, the driver currently support encrypted private key as of May 2022, so I will introduce about key pair authentication in Terraform driver for Snowflake.

# PoC environment

I have verified the feature using the following environment.

* MacOS 10.15.6
* openssl version LibreSSL 2.8.3
* Terraform v1.1.7 on darwin_amd64
* provider registry.terraform.io/snowflake-labs/snowflake v0.33.1

# Generate a key pair

The following URL explains how to generate a key pair for Snowflake clients.

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-1-generate-the-private-key

The document use this command for key pair generation.

```
$ openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8
```

However, Terraform will fail if you use a private key generated using the command above.

> could not build dsn for snowflake connection: Private Key could not be parsed: Could not parse encrypted private key with passphrase, only ciphers aes-128-cbc, aes-128-gcm, aes-192-cbc, aes-192-gcm, aes-256-cbc, aes-256-gcm, and des-ede3-cbc are supported: pkcs8: only PBES2 supported

The error message suggests us to use the following ciphers.

* `aes-128-cbc`
* `aes-128-gcm`
* `aes-192-cbc`
* `aes-192-gcm`
* `aes-256-cbc` 
* `aes-256-gcm`
* `des-ede3-cbc`

The following Terraform driver document also explains the same thing mentioned above.

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#keypair-authentication-passhrase

```
cd ~/.ssh
openssl genrsa -out snowflake_key 4096
openssl rsa -in snowflake_key -pubout -out snowflake_key.pub
openssl pkcs8 -topk8 -inform pem -in snowflake_key -outform PEM -v2 aes-256-cbc -out snowflake_key.p8
```

* The second command generates an RDS private key (unencrypted). https://www.openssl.org/docs/man1.1.1/man1/openssl-genrsa.html
* The third command generates a public key for the private key above.
* The fourth command generates an encrypted private key using a cipher `aes-256-cbc`. Please refer the following URL for more about AES 256 CBC.https://datatracker.ietf.org/doc/html/rfc3602

# Apply the public key for a Snowflake user for deployment

As mentioned in the document below, you need to apply the content of the public key to Snowflake user you use for deployment.

https://docs.snowflake.com/en/user-guide/key-pair-auth.html#step-4-assign-the-public-key-to-a-snowflake-user

```
ALTER USER terraform SET RSA_PUBLIC_KEY = """xxxxxx"""
```

# Set the encrypted private key in Terraform provider configuration

As mentioned in the document below, you need to set private key file path in Terraform provider configuration

https://registry.terraform.io/providers/Snowflake-Labs/snowflake/latest/docs#example-provider-configuration

```
provider "snowflake" {
  username = "terraform"
  account  = "xxx"
  private_key_path       = "./rsa_key.p8"
  role                   = "xxxx"
}
```

You can provide passphrase as an environment variable as below. Most of all major CICD service such as GitHub Actions, Gitlab CI/CD, AWS Code Build support secure way to store credential. You can use it to store passphrase securely in CICD pipeline.

```
SNOWFLAKE_PRIVATE_KEY_PASSPHRASE=xxxx terraform plan --out out.tfplan
```

# Summary

I explained how to use encrypted private key in key pair authentication for Terraform driver for Snowflake in this article.

* Security requirement for private key is becoming more strict. You should use security configuration recommended in Cloud Service or tool you are using.
* You need to provide passphrase to decrypt your encrypted private key
* You can provide passphrase as environment Variable.

I hope this article would help DevOps engineers who use Snowflake :)
