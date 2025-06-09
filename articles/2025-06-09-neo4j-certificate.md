---
title: "Neo4j Certified Professional を取得した"
emoji: "🕸"
type: "tech"
topics: [neo4j]
published: true
---

# 本記事の概要

ここ数ヶ月ほど勉強した Neo4j について無事に Neo4j Certified Professional の認定を受けました。https://graphacademy.neo4j.com/c/dee1965c-5941-4319-9b13-ec15cdb6b81d/

本記事では、Neo4j の概要、および、どういう場面で Neo4j を活用すると良いか、データウェアハウスといった他のデータ基盤との関連性について紹介します。

![Neo4j Certified Professional](https://storage.googleapis.com/zenn-user-upload/2a8c8fa22585-20250609.png)

# Neo4j とは

Neo4j はグラフデータベースと呼ばれる種類のデータベース管理システムです。

リレーショナルデータベース（RDB）がデータを表形式（行と列）で管理するのに対し、Neo4j はデータを「ノード（点）」と「リレーションシップ（線）」というグラフ構造で管理する点に特徴があります。

![](https://storage.googleapis.com/zenn-user-upload/68a27f54454d-20250609.png)
https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/

グラフ構造においてデータ間の関連性を高速にたどることに特化して設計されており、数十億ものノードやリレーションシップを効率的に処理できる点に強みがあります。RDB では テーブルの JOIN 操作によって関係性を導き出しますが、JOIN 操作のホップ数が増えるとクエリパフォーマンスが劣化する問題があります。一方、Neo4j では、最初から関係性そのものがデータとして保存されているため、複雑な関係性の探索や分析に非常に優れています。

（参考）以下は Neo4j の Web に掲載されている Neo4j 上のグラフ DB の例です。Person と Movie というノードと ACTED_IN という関係で、映画の出演記録が表現されています。
https://neo4j.com/

![グラフDB](https://storage.googleapis.com/zenn-user-upload/99f4df118f5b-20250609.png)

大学でコンピュータサイエンスを専攻した方であれば、一度は、[ダイクストラ法](https://ja.wikipedia.org/wiki/ダイクストラ法)などグラフ構造を探索するようなプログラムを一から書いたことがあると思いますが、グラフ探索のプログラムは理解するのが困難な上、デバッグも大変です。Neo4j の場合、[Cypher](https://neo4j.com/docs/cypher-manual/current/introduction/cypher-overview/) と呼ばれる宣言型のクエリ言語とグラフアルゴリズムのライブラリを活用することで、大幅にグラフ探索のコードを書く労力を削減できます。

例えば、以下は簡単な Cypher の例です。 「Keanu Reeves」という名前の人物が「The Matrix」というタイトルの映画に出演している（ACTED_IN の関係）場合に、その人物名と映画のタイトルが結果として表示されます。

```cypher
MATCH (p:Person)-[:ACTED_IN]->(m:Movie)
WHERE p.name = 'Keanu Reeves' AND m.title = 'The Matrix'
RETURN p.name AS Actor, m.title AS Movie
```

この例だと RDB でも十分に処理できる内容ですが、例えば、ノードや関係の種類や数が爆発的に増え、JOINのホップ数が増えていくと、グラフ DB の優位性が発揮されます。

![](https://storage.googleapis.com/zenn-user-upload/b3533b3bb92f-20250609.png)
https://neo4j.com/blog/graph-database/graph-database-vs-relational-database/

# ところでなぜ Neo4j の認定を受けたの？

Neo4j の認定を受けようと思った背景は、実際に社内で Neo4j を使っているチームがあり、私の所属するデータプラットフォームチームが Neo4j の SaaS 版である Neo4j Aura のプラットフォーム管理者の立場になったためです。

Neo4j で業務データを分析する立場にありませんが、要望に応じてインスタンスを払い出したり、Web アプリケーションのバックエンド DB として Neo4j を使っているユースケースで SaaS や RBAC を実現する仕組みを検討したり、技術面で支援するようになりました。

データベースは管理するし、セキュリティ面の設計はするけど、データベースは使ったことがないという立場になっていたため、もう少し理解を深めようと思い、この度、認定を受けました。

# どんなユースケースで Neo4j を使うと良い？

Neo4j はグラフ DB であり、グラフ構造においてデータ間の関連性を高速にたどることに特化して設計されている点は先ほど述べました。よって分析対象の問題空間がグラフ構造になっており、グラフ構造を高速に探索する必要がある場合に有効です。

## （例1) ソーシャルグラフの分析 - コミュニティの自動検出、影響力のあるユーザーの特定

おそらく多くの人にとって最も身近なグラフ構造の例は、X、Instagram、Facebookといったソーシャルメディアでしょう。ソーシャルメディア上におけるオンラインコミュニティにおいて、ユーザー間のつながり（フォロー、友達、いいね！、コメントなど）をグラフとして表現し、その構造を分析することで、特定のコミュニティを自動的に検出したり、ネットワーク内で最も影響力のあるユーザーを特定したりすることができます。

例えば、以下は友人関係のコミュニティを検出する Cypher クエリの例です。（注） APOC ライブラリのプロシージャを使用しています。

```
CALL gds.louvain.stream('my_social_network')
YIELD nodeId, communityId
RETURN gds.util.asNode(nodeId).name AS Person, communityId
ORDER BY communityId
```

以下は最も多くの人からフォローされているユーザーを探す Cypher クエリの例です。

```cypher
MATCH (p:Person)<-[:FOLLOWS]-(follower:Person)
RETURN p.name AS Influencer, count(follower) AS FollowerCount
ORDER BY FollowerCount DESC
LIMIT 10
```

## （例2）製造業でのサプライチェーンの可視化とレジリエンス分析

私が所属する製造業でのユースケースとしては、サプライチェーンの分析や最適化があります。例えば、製品の原材料から最終製品が顧客に届くまでの複雑なサプライチェーンを Neo4j でモデル化し、その関係性を可視化・分析することで、供給リスクの特定、ボトルネックの解消、そしてサプライチェーン全体のレジリエンス（回復力）を高めることができます。

以下は、特定の部品が供給停止した場合に影響を受ける製品ラインと顧客を探索する Cypher クエリの例です。

```cypher
MATCH (faulty_component:Component {id: 'XYZ'})<-[:USES]-(product:Product)
MATCH (product)<-[:MANUFACTURES]-(factory:Factory)
MATCH (factory)-[:SHIPS_TO]->(customer:Customer)
RETURN faulty_component.id AS AffectedComponent, product.name AS AffectedProduct, customer.name AS AffectedCustomer
```

また、以下は、ある製品のサプライチェーン全体を可視化（例えば、ProductAに必要な部品、それらを供給するサプライヤー）する例です。

```cypher
MATCH p=(product:Product {name: 'ProductA'})<-[:USES*]-(component:Component)<-[:SUPPLIES]-(supplier:Supplier)
RETURN p
```
# Neo4j があれば RDB は不要なの？

Neo4j を社内に紹介したところ、Neo4j を使う場合、RDB は不要なのか？という質問を受けましたが、答えは明確に No です。Neo4j はグラフ構造においてデータ間の関連性を高速にたどるというニッチなユースケースに最適化して設計された DB であり、汎用性の高い RDB を置き換えるものではありません。

データ分析であれば、まず、 RDB のデータウェアハウスやレイクハウスなどをメインのデータストアとして置き、グラフ DB が有効なユースケースが見つかった場合に、RDB やオブジェクトストレージからデータを取り込んで、グラフ DB を構築し、分析に使うのが適切です。

実際に、先日参加した Neo4j のイベントでも、Neo4j の CPO が Neo4j は RDB を置き換えないし、ほとんどの Neo4j の顧客は RDB を主要なデータソースとして使っていると明言していました。ということで、これまで通りに RDB をメインの分析データベースとして使い、必要に応じて Neo4j のようなグラフ DB を使うと良いでしょう。　  

# Neo4j を勉強したい時にどうしたら良い？

実際に Neo4j を学んでみたいという方は、Graph Academy という無料の学習コンテンツがあるので、そちらを試してみると良いでしょう。

https://graphacademy.neo4j.com

Neo4j Certified Professional の認定を受ける際に必要な知識を学習できる Learning Path も整備されています。

https://graphacademy.neo4j.com/certifications/neo4j-certification/

実際に動かしながら学びたいという方には、特に Importing Data Fundamentals というチュートリアルがおすすめです。簡単なグラフモデルをステップごとに構築し、徐々に複雑なクエリを実行していくチュートリアルになっています。全てブラウザで完結しているため、実際に試して理解してみたいけど、環境構築は苦手という方に最適です。
https://graphacademy.neo4j.com/courses/importing-fundamentals/

# おわりに

本記事では、Neo4j の概要および有効なユースケースの紹介、学習する上で参考になるコンテンツを紹介しました。本記事を通じて、Neo4j に興味を持つ方がいらっしゃれば幸いです。
 