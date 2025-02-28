---
title: "BigLake external tablesを使って GCS 上の Delta Lake のデータを参照する"
emoji: "🐕"
type: "tech"
topics: [databricks,deltalake,bigquery]
published: false
---

# Background

We are discussing an approach to retain the serving layer in BigQuery to avoid business impacts from migrating to Databricks and to propose immediate migration cost savings. As one means of implementing this approach, Google has suggested creating an external table in BigQuery that points to Delta Lake table data stored on GCS. This page summarizes the query performance and concerns related to the external table approach.
Since Databricks only supports Delta Lake as the table format on GCS, we will limit our discussion here exclusively to Delta Lake.

# Technical approach

Logical Delta Lake tables are managed in Unity Catalog for access control.
Actual physical Delta Lake table files are stored in GCS. We can find GCS storage location for each Delta Lake table in Databricks UI.
Create external tables in BigQuery and specify Delta Lake storage locations in the tables.
BigQuery automatically detects schema in Delta Lake metadata files on GCS bucket then update table schema in BigQuery.
When BigQuery clients such as Tableau queries the external tables in BigQuery, BigQuery will query Delata Lake data files (parquet) in GCS bucket.

# Available external table options in BigQuery

https://cloud.google.com/bigquery/docs/iceberg-external-tables

Only "BigLake external tables" can support delta lake https://cloud.google.com/bigquery/docs/create-delta-lake-table

BigQuery supports the following features with Delta Lake tables:
Access delegation: Query structured data in external data stores with access delegation. Access delegation decouples access to the Delta Lake table from access to the underlying datastore.
Fine-grained access control: Enforce fine-grained security at the table level, including https://cloud.google.com/bigquery/docs/row-level-security-intro and https://cloud.google.com/bigquery/docs/column-level-security-introsecurity. For Delta Lake tables based on Cloud Storage, you can also use https://cloud.google.com/bigquery/docs/column-data-masking.
Schema evolution: Schema changes in the Delta Lake tables are autodetected. Changes to the schema are reflected in the BigQuery table.
Delta Lake tables also support all BigLake features when you configure them as https://cloud.google.com/bigquery/docs/biglake-intro.

# How to create BigLake external table for Delta Lake
https://cloud.google.com/bigquery/docs/biglake-intro
https://cloud.google.com/bigquery/docs/create-cloud-storage-table-biglake

Check storage location of the source table in Databricks
Confirmed storage location of the table dde_mvp_d001_europe_west2_vpc.diamonds_dev.diamonds

gs://databricks-aaa-unitycatalog/bbb/__unitystorage/catalogs/ccc/tables/ddd

# Create an external table in BigQuery

```
CREATE EXTERNAL TABLE IF NOT EXISTS
  lakehouse_poc.diamonds OPTIONS ( format = "DELTA_LAKE",
    uris = ["gs://databricks-aaa-unitycatalog/bbb/__unitystorage/catalogs/ccc/tables/ddd"] );
```

```
Query the external table
SELECT
  SUM(carat) AS sum_carat,
  cut
FROM
  lakehouse_poc.diamonds
WHERE
  price > 300
GROUP BY
  cut;
```

Made backward compatible change such as adding a column on the delta table in Databricks
ALTER TABLE dde_mvp_d001_europe_west2_vpc.diamonds_dev.diamonds
ADD COLUMN test INT;

No impact to the query in BigQuery

```
SELECT
  SUM(carat) AS sum_carat,
  cut
FROM
  lakehouse_poc.diamonds
WHERE
  price > 300
GROUP BY
  cut;
```

# Query performance
TBD

# Potential risks

## (1) BigQuery external tables may not support the latest version of Delta Lake
Almost all platform vendors, except for Databricks and Microsoft Fabric, have shifted to Iceberg. Google Cloud is also focusing on Iceberg for most of its recent open table format updates. There is a risk that BigQuery's external tables eventually may not support the latest version of Delta Lake.
e.g. Microsoft Fabric https://learn.microsoft.com/en-us/fabric/fundamentals/delta-lake-interoperability
However, this is an inherent risk of adopting Delta Lake, and when deploying Databricks—which uses Delta Lake as its data storage format—it becomes unavoidable. This is not an issue specific to external tables. We must continuously monitor market trends in open table formats and Databricks’ support for Iceberg and take appropriate countermeasures if the risk of long-term disadvantages materializes.

Databricks announced support for iceberg during a webinar on 27 Feb 2025 Databricks webinar 27 Feb 2025.loop

## (2) External tables do not support optimizations such as pruning, so query performance may degrade
External tables do not support optimizations such as pruning, so query performance may degrade.
If external tables are used only for small serving layer tables, it is not a major issue.

## (3) Data type mismatch between Delta Lake and BigQuery
There are potential risks that BigQuery convert Delta Lake data to unexpected data type.
Delta Lake data type - https://docs.databricks.com/aws/en/sql/language-manual/sql-ref-datatypes

BigQuery data type - https://cloud.google.com/bigquery/docs/reference/standard-sql/data-types 

## (4) Clients may temporarily reference inconsistent data due to lack of multi table transaction support
Since Delta Lake itself does not support multi-table transactions, there is a possibility that clients may temporarily reference inconsistent data. However, this is a limitation of Delta Lake. Furthermore, at present, when executing dbt on BigQuery, multi-table transactions are not performed, so there has been no discussion on taking specific measures.
