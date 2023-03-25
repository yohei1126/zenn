---
title: "クラウドデータウェアハウスの10年と自分キャリア史"
emoji: "❄️"
type: "tech"
topics: [datawarehouse,redshift,bigquery,snowflake]
published: false
---

#　記事の背景

日本の Snowflake ユーザコミュニティである SnowVillage で、以前、SQL に関する教養講座・実践講座のような動画コンテンツが公開されました。これは初心者でも現代における RDB や SQL の重要性が理解できる丁寧な解説で、分かりやすく、割と関係者の間では好評だったようです。

* 【みんなのSQL講座】黎明編～SQL誕生の熱い歴史～　https://www.youtube.com/watch?v=NFKjCWzlS7o
* 【みんなのSQL講座】復活編～DBの長い歴史とイマ～ https://www.youtube.com/watch?v=EYVE7yqp8qQ
* 【みんなのSQL講座】実践編～誰でも書ける！SQL～ https://www.youtube.com/watch?v=nqpyRqzR9N4

これを見た時、我々が日常に使っているデータウェアハウスに関しても、日常的な業務を行なっていく上で知っておくべき、 Snowflake の技術的な背景や基礎的な概念について紹介する講座があればと思い、コミュニティで提案し、準備を進めています。

言い出しっぺということで私自身もコンテンツ作成に関わっているわけですが、コミュニティのリーダーである Data Superhero 2022 に選ばれにもかかわらず、実は、元々はデータベースやデータウェアハウスの専門家というわけではなく、データエンジニアリングやデータウェアハウスに関わるようになったのがここ5年くらいです。しかも、オンプレミスを使った開発も経験したことがなく、キャリアの長さの割に、最初からクラウドを使ったデータエンジニアリングをやり始めたクラウドネイティブです。

データウェアハウス技術の進化を解説するほどの経験、特にデータウェアハウス業界を歴史的にも、様々な製品カテゴリを俯瞰的に見てきたわけではないので、せめてクラウドデータウェアハウスが登場した後から、私がデータエンジニアをやり始めたここ 5 年くらいの話題については議論について行こうと思い、特に業務で使ったことのある AWS、GCP、Snowflake の３つのクラウドサービスのデータウェアハウス製品についてリリースされたビジネス的な背景や技術的進化についてまとめようと考えました。

# なぜ技術の進化の歴史を学ぶか？

* 今使っている技術の特性や想定する前提をより深く理解し、適切に技術選定できるようになるため。
* 過去から現在に起きた技術の進化、それに伴うスキルのニーズの変化を理解することで、今後のキャリアの発展について考えやすくする。

# クラウドデータウェアハウス個人史

クラウドを業務で使うようになったのは、2013 年ごろ。それ以前は組み込みソフトウェア開発をやっていたので、そもそもクラウド、サーバ、業務システムには縁がなかった。

社内のグローバル人材育成プログラムで、会社が取り扱っている海外の製品ベンダーに 1 年間、研修ビザを取得して出向し、製品開発やQAをやれる機会があったので、サンフランシスコのBIベンダー

# Amazon Redshift

最初に紹介するクラウドデータウェアハウスは、Amazon Redshift です。AWS はクラウドの草分け的存在であり、そのAWS のデータウェアハウスが Redshift です。

## Redshift が登場した背景

AWS が Redshift をリリースしたビジネス的な背景については、前 AWS CEO である Andy Jassy の 2012 年の re:Invent Day 1 Keynote が詳しいです。

https://www.youtube.com/watch?v=8FJ5DBLSFe4&t=3171s

この当時は、データベース製品としては、RDS、Dynamo DB、ElasticCache はすでにリリースされており、AWS 流のクラウドデータベースサービスは確立された状態でした。

一方で、クラウド登場以前のデータウェアハウス製品は以下の課題を抱えていました。

* ハードウェアとソフトウェアが非常に高価
* チューニングと管理が非常に複雑である。企業はデータウェアハウスごとに平均で 3 - 4 人の DBA を雇用していた。
* 既存のソリューションに満足した顧客がいなかった。大企業にとっては高価でスケールしない。中小企業にとっては高すぎて買えない

このような既存のデータウェアハウスの課題をこれまでのデータベース製品と同様の AWS 流で解決しようとしてリリースした製品が Redshift でした。

* プロビジョンとスケールアップが容易
* 事前のコストが不要であり、使った分だけ費用を支払う
* 低価格で高パフォーマンス
* 人気のツールをサポートするオープンさ、柔軟さ

Amazon で実際に試験的に導入したプロジェクトでは、年間 PB あたりのコストが従来製品に対して 1/10〜1/20 程度まで下がったそうです。

ここで挙げられている手法は、クラウドが全盛になった今では当たり前に思えますが、Redshift が出た当時の状況からすれば革命的なソリューションだったと思います。

## Redshift の技術面の進化

Redshift の技術面での進化は AWS のソリューションアーキテクトの方の解説が非常に分かりやすいです。

* 進化するクラウドDWH Amazon Redshift 最新アップデート (Amazon Web Services Japan 公式) https://www.youtube.com/watch?v=bPndWpD3ZRI
* Amazon Redshift の 進化の歴史とこれから/redshift-evolution-2021 https://speakerdeck.com/jozono/redshift-evolution-2021
こ
ソリューションアーキテクトの方の資料によるとサービスローンチ時は、非常にシンプルです。

* シェアードナッシング型かつ MPP (massive parallel processing) に分類されるアーキテクチャ。
* リーダーエンドポイントがクライアントとの窓口になり、SQL 処理コードの生成と展開を行う。
* データと実際の処理はコンピュートノードに分散される。各ノードで並列処理することで、分析クエリに対する処理スループットを向上させる。

このシェアードナッシング型かつ MPP (massive parallel processing) アーキテクチャについては、Snowflake: The Definitive Guide の "Chapter 2. Creating and Managing the Snowflake Architecture" でも触れられています。

https://learning.oreilly.com/library/view/snowflake-the-definitive/9781098103811/

> Shared-Nothing (Scalable) Architecture
> The shared-nothing architecture, in which storage and compute are scaled together (as shown in Figure 2-2), was designed in response to the bottleneck created by the shared-disk architecture. This evolution in architecture was made possible because storage had become relatively inexpensive. However, distributed cluster nodes along with the associated disk storage, CPU, and memory requires data to be shuffled between nodes, which adds overhead. The way the data is distributed across the nodes will determine the extent of the additional overhead. Striking the right balance between storage and compute is especially difficult. Even when it is possible to resize a cluster, it takes time to do so. Thus, organizations often overprovision shared-nothing resources, which results in unused, unneeded resources. Examples of a shared-nothing architecture include IBM DB2, Vertica, and Pivotal Greenplum.

> （著者訳）シェアードナッシングアーキテクチャは、シェアードディスクアーキテクチャのボトルネックを解決するために設計されました。