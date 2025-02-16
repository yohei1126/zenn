---
title: "Snowflakeでのshowback modelの導入"
emoji: "❄️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [snowflake,dbt]
published: false
---

# 概要

本記事では、Snowflake におけるショーバック（Showback）モデルの実現について議論する。

# 議論の背景

TBD あとで追記

# ショーバックモデルの定義

IT やその他のサービス組織におけるコスト割り当てモデルの代表例としてにチャージバック（Chargeback）モデルとショーバック（Showback）モデルの 2 つがある。本記事で議論するのはショーバックモデルの方。

チャージバックモデル（Chargeback model）
定義: ITサービスやリソースのコストが、それらを利用する各ビジネス部門や部署に直接請求される。
仕組み:　使用状況を測定・計算し、そのコストを責任を持つ特定のグループに割り当てる。
目的:　コストに対する責任感と意識を促進し、各部署がリソースの使用を最適化することを促す。

ショーバックモデル（Showback model）
定義:　実際の請求は行わず、各部署やユニットが使用した場合のコストがどの程度になるかを詳細なレポートで示す。
仕組み:　使用データを収集し、実際の金銭のやり取りを伴わずにレポートとして公開することで、コスト配分の透明性を提供する。
目的:　直接の請求による管理の手間や摩擦を避けつつ、コスト意識を高め、効率性を向上させるための情報を提供する.

補足
* このページでは、Snowflake などプラットフォームサービスを前提に議論するが、データパイプラインの開発や運用をビジネス部署から請け負った場合に、それに係るコスト（人件費、業務委託費）を利用部門に請求し直す（チャージバック）することで、IT 組織の人員を維持する予算を確保するとともに、それを人員確保の正当性とするケースもある。
* 2 つのモデルともに利用部門にコストのオーナシップを持ってもらう上で非常に有効。ただし、ショーバックモデルは、利用部門がコストを支払う義務がないため、強制力がチャージバックモデルに比べて弱い。ショーバックモデルは利用部門の自発的なコスト最適化を期待したり、将来的なシステム企画に影響を与える目的で行うことが多い。

# チャージバックモデルとショーバックモデルの採用を検討するタイミング

## ショーバックモデルを検討する場合

* 請求なしでの透明性の確保: 実際の請求処理の手間をかけずに、各部署にリソース利用状況や関連コストを知らせることが目的の場合。
* 将来的なチャージバックへのパイロット: 将来的にチャージバックモデルに移行することを検討している場合、まずはショーバックで意識を高め、データを収集するステップとして有効。
* 部署間の摩擦回避: 直接請求が部署間の対立を引き起こす可能性がある場合や、文化的に受け入れられにくい場合、ショーバックで情報を提供する方法が適している。
* 初期のコスト意識の醸成: 請求プロセスを正式に導入する前に、段階的にコスト意識を高め、効率的な使用を促す。

## チャージバックモデルを検討する場合

* 直接的なコスト責任: 各ビジネスユニットや部署がITサービスや利用リソースの費用に直接責任を持つ必要がある場合。
* 予算管理と財務コントロール: 使用状況と予算配分を厳密に連動させ、各部署が実際の費用に基づいてリソース消費を調整する必要がある場合。
* 成熟した財務システム: 内部請求、照合、財務報告を管理するためのインフラが整っている場合。
* 最適化の促進: 直接請求することで、各部署がリソース使用の最適化と無駄の削減に積極的になる場合。

補足
* すでに運用されてしばらく経過したサービスにチャージバックモデルを導入するのは、利用部門との摩擦を生む恐れや、コスト内訳の自動計算や社内請求の仕組みが整っていないと実施が困難になるため、あまり行われない。将来的にチャージバックを行う可能性がある場合は、最初からそれを前提とした運用や利用部門とのコミュニケーションを行うべき。
* ショーバックモデルの場合、コストを提示する頻度や粒度によっては自動化の必要性がなかったりもする。

# Snowflakeのコスト管理

ここからはSnowflakeで主にショーバックモデルを実現する上で必要な知識についてまず整理する。

Snowflakeのコストは主にコンピュート、ストレージ、データ転送に分類される。主なコストはコンピュートコストのため、以下はコンピュートコストでいかにショーバックモデルを実現するかを検討する。

Managing cost in Snowflake
https://docs.snowflake.com/en/user-guide/cost-management-overview
Understanding overall cost
https://docs.snowflake.com/en/user-guide/cost-understanding-overall

コンピュートコストの内訳は以下の通り。

* Virtual Warehouse compute - Virtual warehouseを利用した際の計算資源分のコストが計上される。Snowflake の serverless warehouse は用途が限定されているため、多くのコンピュートコストはこちらに該当する。
* Serverless compute - サーバレス機能を利用した際の計算資源分のコストが計上される。例としては、自動クラスタリング、Snowpipe、など。
* Compute pools — Snowpark Container Services を利用した際にそのジョブやサービスを走らせた場合の計算資源分のコストが計上される。
* Cloud Services compute - Snowflakeのクラウドサービスレイヤーの利用計算資源分のコストが計上される。例としては、認証、メタデータ管理など。https://docs.snowflake.com/en/user-guide/intro-key-concepts

# コスト分類ごとのコスト配分（Cost attribution）方法

コスト配分（Cost attribution）は、発生したコストに対して、そのコストの責任を負う部門やプロジェクトなどを特定し、コストを割り当てるプロセスのこと。

https://docs.snowflake.com/en/user-guide/cost-attributing

## Virtual Warehouse compute のコスト配分

* リソースそのものに（Warehouseなど）にタグをつけるアプローチ・・・・コスト配分単位でリソースが分かれている場合に有効。
* クエリにタグをつけるアプローチ・・・Warehouse などリソースがコスト配分単位の複数チームで共有されている場合、さらに細かい単位としてクエリにコスト配分を区別する情報を埋め込む方法。

### リソースそのものに（Warehouseなど）にタグをつけるアプローチ

https://docs.snowflake.com/en/user-guide/cost-attributing#attribute-cost-of-individual-resources

コスト配分の単位でウェアハウスが分かれている場合、ウェアハウスにタグをつけることで、そのウェアハウス全体のコストセンターが分類できる。
ただし、ウェアハウスがコスト配分したい複数チームで流用されている場合、どのチームにどの程度、ウェアハウスのコストを配分するか計算が困難になる。

```
USE ROLE tag_admin;
ALTER WAREHOUSE warehouse1 SET TAG cost_center='SALES';
ALTER WAREHOUSE warehouse2 SET TAG cost_center='SALES';
ALTER WAREHOUSE warehouse3 SET TAG cost_center='FINANCE';
```

以下はタグとタグ値で全てのウェアハウスのコスト配分を集計するクエリ。

```
SELECT tag_references.tag_name,
     COALESCE(tag_references.tag_value, 'untagged') AS tag_value,
     SUM(warehouse_metering_history.credits_used_compute) AS total_credits
FROM snowflake.account_usage.warehouse_metering_history
LEFT JOIN snowflake.account_usage.tag_references
ON warehouse_metering_history.warehouse_id = tag_references.object_id
WHERE warehouse_metering_history.start_time >= DATE_TRUNC('MONTH', DATEADD(MONTH, -1, CURRENT_DATE))
  AND warehouse_metering_history.start_time < DATE_TRUNC('MONTH',  CURRENT_DATE)
GROUP BY tag_references.tag_name, COALESCE(tag_references.tag_value, 'untagged')
ORDER BY total_credits DESC;
```

### クエリにタグをつけるアプローチ

Attribute cost for queries
https://docs.snowflake.com/en/user-guide/cost-attributing#attribute-cost-for-queries

セッション単位でクエリにタグを設定できるため、コスト配分が識別できる情報をクエリタグに設定できる。

```
ALTER SESSION SET query_tag = finance;
```

以下はタグごとのクレジットを集計する方法。

```
WITH wh_bill AS (
   SELECT SUM(credits_used_compute) AS compute_credits
     FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
     WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
     AND start_time < CURRENT_DATE
),
tag_credits AS (
   SELECT COALESCE(NULLIF(query_tag, ''), 'untagged') AS tag,
          SUM(credits_attributed_compute) AS credits
     FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
     WHERE start_time >= DATE_TRUNC('MONTH', CURRENT_DATE)
     AND start_time < CURRENT_DATE
     GROUP BY tag
),
total_credit AS (
   SELECT SUM(credits) AS sum_all_credits
     FROM tag_credits
)
SELECT tc.tag,
       tc.credits / t.sum_all_credits * w.compute_credits AS attributed_credits
  FROM tag_credits tc, total_credit t, wh_bill w;
```

なお、クエリタグは、上限2000文字のただの文字列。Key Value方式ではない。あとで集計しやすいようにJSON文字列でタグを設定すると良い。
https://docs.snowflake.com/en/sql-reference/parameters#query-tag

```
set query_tag = '{"team": "engineering", "user": "shauna"}';
```

以下の記事では、ユーザごとにデフォルトにクエリタグが設定できる点を紹介している。コスト配分したい単位をユーザごとに別にして、デフォルトのクエリタグを設定すれば、そのユーザのクエリには同じクエリタグが設定されるため、集計がしやすい。
自動化したパイプラインの場合はそのまま適用しやすい。
複数のプロジェクトに参画する人間ユーザの場合、セッション単位で適切なタグを指定するのは困難なため、適用が難しい可能性がある。

Snowflake query tags for enhanced monitoring
https://select.dev/posts/snowflake-query-tags

```
alter user shauna set query_tag = '{"team": "engineering", "user": "shauna"}';
```

さらに上記記事では、dbt Snowflake でクエリにタグをつけるアプローチを紹介している。

1. profiles.yml でクエリタグを設定する。その dbt project のクエリは全て同じクエリタグをつける。https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup#authentication-methods
2. 特定の resource_path 配下の全てのモデルにタグを設定する場合、dbt_project.yml に `+query_tag` を設定する。
3. 個別のモデルにタグをつける場合、モデル設定ファイルに `{{ config(query_tag = 'XXX') }}` を設定する。. 3. If a default query tag has been set in profiles.yml, it will be overridden by any of these more precise tags.
4. `set_query_tag` というマクロを作り、プロジェクトの中の全てのモデルに自動的にクエリタグをつけることもできる。

彼らがリリースしたクエリタグ用の dbt パッケージは以下の通り。
https://github.com/get-select/dbt-snowflake-query-tags

このパッケージの優位性は要調査。

## Serverless compute のコスト配分

TBD

## Compute pools のコスト配分

TBD

## Cloud Services compute のコスト配分

TBD
