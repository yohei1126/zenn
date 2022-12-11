---
title: "Scheduled dbt model deloyment for Snowflake using AWS ECS and Airflow"
emoji: "🚀"
type: "tech"
topics: [dbt,snowflake,dbt,airflow,aws]
published: true
---

In my project, I introduced Terraform for Snowflake configuration management and deployment 2 years ago. I initially tried to deploy almost everything, but I have decided to use popular data transformation tool called dbt core (OSS version of dbt) for data object deployment such as table and view due to the following reasons.

* Deployment time has been increased as a number of Terraform resources grows. Terraform requires larger amount of computing resources to update Terraform state.
* Terraform uses HCL to describe Terraform resources. SQL is much easier for most of our Snowflake users to understand than HCL.
* dbt is becoming de facto standard for data transformation layer.

In this article, I will explain how to schedule dbt model deployment for Snowflake using AWS ECS and Airflow.

# How to deploy dbt models

dbt supports not just simple table or view deployment. It also supports complex table update like incremental table update and Slowly Changing Dimension Type 1 or 2. So we have to support 2 different type of deployment for dbt models.

(1) One-time table or view deployment
(2) Scheduled table replacement or incremental table update

We only supported the approach (1) using existing CICD pipeline using Terraform. So we needed to support new approach (2).

# Requirements for scheduled dbt model deployment

We had to meet the following requirements to scheduled dbt model deployment.

* Git repository server and CICD pipeline managed in our private Gitlab server by CCOE (Cloud Center of Excellence) team
* We are using AWS MWAA (Managed Workflow for Apache Airflow) for centralized schedule job execution so dbt model deployment should be scheduled in Airflow.
* dbt command should be segregated from Airflow. If it depends on old Airflow library version, we might not be able to use newer version of dbt.

# CICD pipeline architecture

We have built a CICD pipeline architecture as follows.

***Note that our Gitlab server and ECR repositories are managed by CCOE (Cloud Center of Excellence) team. My Data Engineering Team only manages Airflow and ECS cluster in our separate AWS accounts.***

1. dbt model source code is managed in our Gitlab repository. New changes must be merged to our repository.
2. One-time model deployment is done by CICD pipeline when we merged new change to our repository.
3. CICD pipeline also build and push a container image for dbt model source code to ECR repository.
4. Airflow DAG trigger AWS ECS Fargate task for dbt model deployment. Note that ECS cluster and ECS task definition must be deployed in advance.
5. The container image will be loaded from ECR to ECS.
6. dbt command is executed in container, and it updates a table.

![dbt model deployment](https://storage.googleapis.com/zenn-user-upload/643606e124f0-20221211.png)

# Small tips to support 2 different type of deployment

To support 2 different type of deployment, dbt needs to be able to detect which model should be deployed in scheduled jobs. We are using a tag as below for this requirement.

https://docs.getdbt.com/reference/resource-configs/tags

```
{{
    config(
        tags="scheduled"
    )
}}
```

We exclude models with `tags:scheduled` when we do one-time deployment to avoid model deployment in unexpected timing.

```
dbt run --exclude tag:scheduled
```

On the other hand, we run specific model as below in a scheduled ECS container.

```
dbt run --select model_name
```

# Summary

In this article, I explained the approach we use to support one time and scheduled dbt model deployment in my projects.

I understand that many dbt users use dbt Cloud for dbt model deployment scheduling. By using external job scheduling like Airflow, we can implement more complex job scheduling such as coordinating job execution with other jobs.

Hope this article help my readers understand available dbt model deployment options.
