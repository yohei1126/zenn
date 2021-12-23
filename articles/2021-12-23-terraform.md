---
title: "Terraform で Snowflake の何を管理するべきか"
emoji: "❄️"
type: "tech"
topics: [snowflake,devops,terraform]
published: false
---

# この記事の背景

以前、Terraform（インフラの構成管理ツール）を使って Snowflake のリソースを管理し始めたことを書きました。

https://zenn.dev/yohei/articles/2020-12-28-snowflake-terraform

Snwoflake のユーザコミュニティである SnowVillage でも、Terraform について発表しました。

https://www.youtube.com/watch?v=XEv2mx_tZYg

Terraform はプラグインアーキテクチャを採用しており、 Snowflake プラグイン もコミュニティベースで開発されています。この Snowflake プラグインを使うと、Snowflake のリソースの構成を Terraform の設定ファイルとして記述し、デプロイを自動化することができます。

https://github.com/chanzuckerberg/c

https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs

記事やコミュニティでの発表をした後、SnowVillage 内のコメントを見ていると、コミュニティでも使っている方がいらっしゃるようで、皆さんどの範囲に適用するか関心を抱いていることが分かりました。私もほぼ1年ほど運用してきたので、私なりの所見を述べたいと思います。

# Terraform でデプロイできる範囲

まず最初に聞かれそうな質問は、Snowflake のどんなリソースをサポートしてますか？だと思います。

この Snowflake プラグインの内部実装は以下のようになっており、[Snowflake の SQL](https://docs.snowflake.com/en/sql-reference-commands.html) で作れるリソースは全て対応可能です。

* リソースの作成・更新・削除
  * Terraform の表記法を使って記述された Snowflake のリソースから SQL を生成する。
  * Snowflake に対して SQL を実行することで、リソースを作成・更新・削除する。
* リソースをインポート
  * 対象リソースに DESCRIBE コマンドを実行し、現状の構成を取得する。
  * 現状の構成をローカルの Terraform state ファイルに取り込む。

ただし、本ツールは、あくまでもコミュニティで OSS として開発されており、利用者が自分の欲しい機能を随時実装する運用を取っているため、Snowflake の機能を全て網羅的に対応しているわけではありません。あくまでも[現状でプラグインに実装されている範囲](https://registry.terraform.io/providers/chanzuckerberg/snowflake/latest/docs)のみデプロイ可能です。

# Terraform で何をデプロイするべきか

Terraform で事実上全てのリソースがデプロイ可能であっても、必ずしも全てデプロイするべきとは限りません。より適切なツールがある場合は、そちらを使う、または別ツールとの併用を検討するべきでしょう。

近年、クラウドデータウェアハウスのパフォーマンス向上を背景に、データ分析のためのデータ変換ロジックを SQL およびビューなどで実現し、end to endでフルマネージドでスケーラブルな技術スタック (The modern data stack) を構築する動きがあります。以下は Snowflake のリソース階層ですが、The modern data stack のトレンドの中では、テーブルやビューなどは dbt というツールが普及しつつあります。

実際の運用を考えても、テーブルやビューはデータアナリストやアナリティクスエンジニアが SQL を使って作ることが多いと思います。この領域は、Terraform の本来の管理対象ではありませんし、アナリスト系の人に SQL とは表記が全く異なる Terraform を覚えてもらうのも難しいと思います。SQL が使える dbt などがデータ領域のモデリング・デプロイに良いと思います。

![リソース階層](https://storage.googleapis.com/zenn-user-upload/0bb163817072-20211223.png)

（注）The modern data stack の詳細については、以下のドキュメントを参照ください。

* https://blog.getdbt.com/future-of-the-modern-data-stack/
* https://www.fivetran.com/blog/what-is-the-modern-data-stack
* https://www.thoughtworks.com/insights/blog/data-engineering/meet-the-modern-data-stack

それ以外の以下のリソースについては、Terraform で管理しても良いと思います。

* データベース
* スキーマ
* ウェアハウス
* ステージ
* ロール
* ユーザ
* など

# おわりに

今回は、SnowVillage でも話題になっていた Terraform で何を管理するべきかについて書簡を述べさせていただきました。
本記事がこれから Snowflake での DevOps に取り組む方の参考になれば幸いです。
