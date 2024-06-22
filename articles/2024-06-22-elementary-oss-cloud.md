---
title: "Data Observerbility Tool Elementary OSS と　Cloud の比較"
emoji: "🦁"
type: "tech"
topics: [dbt,elementary,snowlfake]
published: false
publication_name: "dataheroes"
---

# 本記事の背景

https://zenn.dev/yohei/articles/2024-04-15-data-observability

# Elementary overview

* https://www.elementary-data.com/
* https://docs.elementary-data.com/introduction
* OSS vs Cloud https://docs.elementary-data.com/overview/cloud-vs-oss

# Key advantages

Key advantage of Elementary over other data observability tools is simplicity and cost efficiency. 

Elementary focus on dbt on multiple warehouses only. They do not need to support metadata ingestion from multiple tools. So they can keep the tool simple.
All information for lineage and metadata are built in client side (In our case, GKE pod) and stored in our database when dbt command is executed. both Elementary OSS and Cloud simply access metadata in the database so Elementar does not consume much computing resources. so their infra cost is much cheaper then other data observability tool like Monte Carlo.
Elementary with Snowflake - Fetching freshness, volume and schema information from Snowflake is quite fast and cheap as Snowflake can provide those data from its metadata layer.

# Key challenges

They focus on dbt on data warehouses only. It may not support some of our use cases.
(To be confirmed) Fetching freshness, volume and schema information from BigQuery might be slow and expensive if BigQuery does not have metadata layer like Snowflake.
Elementary is still a startup. There is a risk that they shutdown their service. https://www.crunchbase.com/organization/elementary-data

# Useful features in Cloud version

https://docs.elementary-data.com/overview/cloud-vs-oss

* Automated freshness, volume and schema monitors - in OSS version, we have to specify those tests in dbt configs manually. It is time consuming process. 
* Monitored data sets – all tables (not only for dbt) - need to check what does this mean.
* Column-level lineage
* Lineage to BI tools
* Multiple environments and data warehouses - this can support multiple dbt projects even in different data warehouses
* CI - This is to find dbt model errors in CI. still in beta https://docs.elementary-data.com/features/ci
