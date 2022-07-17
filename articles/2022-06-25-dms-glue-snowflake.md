---
title: "AWS DMS と Glue を利用したコスト最適なオンプレから Snowflake への DB マイグレーション"
emoji: "❄️"
type: "tech"
topics: [snowflake,aws,dms,glue,db]
published: false
---

# 本記事の概要

本記事では、AWS DMS と Snowpipe で RDB から Snowpipe のマイグレーションを行う場合、CDC を利用できないケースは、AWS Glue を使って定期

# 記事の背景

## AWS DMS と Snowpie でニアリアルタイムな RDB のデータマイグレーション用のパイプラインを構築した

以前、AWS RDS のデータベース上の変更をニアリアルタイムで Snowflake に反映させたいという社内からの依頼を受け、AWS DMS と Snowpipe を使ってデータパイプラインを構築しました。DMS は CDC (Change Data Capture) に対応し、データのマイグレーション先として S3 を指定できるため、データベース上の変更を一定時間以内に S3 バケット上に抽出することができます。また、Snowpipe を利用すると、Snowipe に登録した COPY コマンドで S3 バケットに配置したファイルをテーブルに自動ロードできます。

https://zenn.dev/yohei/articles/2021-04-24-snowflake-dms-rds

## View に CDC が利用できず、Full load task を検討 

上記の CDC パイプラインを導入後、その他のデータベースにも導入したいとの要望があり、オンプレのデータベースもマイグレ対象に拡大しました。この時、オンプレ DB 側を担当していた同僚から指摘されたのは、「Oracle のビュー経由でデータを移行したいが、DMS CDC task はビューをサポートしていない」というものでした。

(この時、私自身が CDC でサポートできない理由は調査していませんが、おそらく CDC は DB のトランザクションログを利用しており、トランザクションログはテーブルに対してのみ存在しているため、ビューに対しては CDC タスクを実行できないのだと解釈しました)

チームで議論した後、DMS でデータを抽出した後、Snowpipe でデータを Snowflake に吸い上げる手法は確立しているので、DMS のもう1つのタスク種別である Full load を定期実行する

## 