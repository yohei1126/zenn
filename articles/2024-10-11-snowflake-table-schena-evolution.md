---
title: "Table schema evolutionを使ったテーブルへのカラムの自動追加"
emoji: "❄️"
type: "tech"
topics: [snowflake]
published: false
publication_name: "dataheroes"
---
あ

```
-- https://docs.snowflake.com/en/user-guide/data-load-schema-evolution

use schema test.test;
CREATE STAGE IF NOT EXISTS my_int_stage
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

CREATE FILE FORMAT IF NOT EXISTS my_json_format
  TYPE = json;

-- check file schema
SELECT *
FROM TABLE(
  INFER_SCHEMA(
    LOCATION=>'@my_int_stage/input1.json',
    FILE_FORMAT=>'my_json_format'
  )
);

-- check records from @my_int_stage/input1.json
-- 2 records
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input1[.]json'
) t;

-- create a table from existing JSON file
CREATE OR REPLACE TABLE fruits
USING TEMPLATE (
  SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
  FROM TABLE(
    INFER_SCHEMA(
      LOCATION =>'@my_int_stage/input1.json',
      FILE_FORMAT=>'my_json_format'
    )
  )
);

describe table fruits;
-- ALTER TABLE fruits modify COLUMN name set NOT NULL;

-- https://docs.snowflake.com/en/sql-reference/sql/alter-table
-- ENABLE_SCHEMA_EVOLUTION = { TRUE | FALSE }
-- Enables or disables automatic changes to the table schema from data loaded into the table from source files, including:
-- Added columns.
-- By default, schema evolution is limited to a maximum of 10 added columns per load operation. To request more than 10 added columns per load operation, contact Snowflake Support.
-- The NOT NULL constraint can be dropped from any number of columns missing in new data files.
-- Setting it to TRUE enables automatic table schema evolution. The default FALSE disables automatic table schema evolution.

ALTER TABLE fruits SET ENABLE_SCHEMA_EVOLUTION = TRUE;
COPY INTO fruits
  FROM @my_int_stage/input1.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- 2 records are loaded
select * from fruits;

-- new file
-- new column weight
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input2[.]json'
) t;

COPY INTO fruits
  FROM @my_int_stage/input2.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

-- new column weight is added
select * from fruits;

-- column weight was removed
SELECT
  *
FROM @my_int_stage (
  file_format => 'my_json_format',
  pattern=>'.*input3[.]json'
) t;

-- weight is nullable so no error
COPY INTO fruits
  FROM @my_int_stage/input3.json
  FILE_FORMAT = (type=json)
  MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE;

select * from fruits;
```