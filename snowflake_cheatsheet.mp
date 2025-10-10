# Comprehensive Cheatsheet for Big Data with Snowflake

Snowflake is a cloud-based data warehousing platform designed for big data analytics, enabling scalable storage, processing, and analysis of massive datasets without managing infrastructure. It supports structured, semi-structured, and unstructured data, making it ideal for ETL pipelines, real-time analytics, and machine learning workflows in big data environments. Founded in 2012, Snowflake operates on AWS, Azure, or GCP and serves over 3,000 customers, processing billions of queries monthly.

## Architecture
Snowflake's hybrid architecture separates storage, compute, and services for independent scaling:

| Layer              | Description                                                                 | Key Benefits |
|--------------------|-----------------------------------------------------------------------------|--------------|
| **Storage**       | Centralized, immutable cloud storage for data files (micro-partitions). Automatic compression, replication, and backups. | Cost-effective; scales independently of queries. |
| **Compute**       | Virtual Warehouses (clusters of servers) for query processing using MPP (Massively Parallel Processing). | Concurrency without interference; auto-scale/suspend. |
| **Services**      | Metadata management, authentication, optimization, and security.            | Zero-maintenance; handles query parsing and access control. |

This shared-disk (central repo) + shared-nothing (MPP clusters) model supports big data loads from S3, Blob, or GCS without impacting queries.

## Key Concepts
- **Virtual Warehouse**: Scalable compute cluster (XS to 6XL sizes). Auto-resume/suspend to save credits.
- **Database/Schema**: Logical containers for tables/views. Public schema is default.
- **Micro-partitions**: Automatic data clustering (50-500MB uncompressed) for pruning and efficiency.
- **Time Travel**: Query data from up to 90 days ago (or 1-0 days based on retention).
- **Data Sharing**: Secure, zero-copy sharing across accounts.
- **Roles & RBAC**: Hierarchical roles (ACCOUNTADMIN, SYSADMIN, etc.) for access control.
- **Credits**: Pay-per-use billing unit; only charged for active compute.
- **Stages**: Internal/external locations for data loading (e.g., from cloud storage).
- **Variants**: Flexible data type for semi-structured data (JSON, Avro).
- **Zero-Copy Cloning**: Instant, metadata-only clones for dev/test environments.

## Account Setup & Configuration
1. Sign up at snowflake.com (30-day free trial with $400 credits).
2. Choose edition (Standard), cloud provider (AWS/Azure/GCP), and region.
3. Log into Snowsight UI.
4. Create Warehouse: `CREATE WAREHOUSE LEARN_WH WITH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE;`
5. Create Database: `CREATE DATABASE PRACTICE;`
6. Set Context: `USE WAREHOUSE LEARN_WH; USE DATABASE PRACTICE; USE SCHEMA PUBLIC;`

Monitor costs in Admin > Cost Management.

## SQL Basics: DDL & DML Commands
### Data Definition (DDL)
| Command | Example | Description |
|---------|---------|-------------|
| CREATE TABLE | `CREATE TABLE books (id INT, title STRING, price DECIMAL(10,2));` | Define table with columns and types. |
| CREATE VIEW | `CREATE VIEW book_view AS SELECT * FROM books WHERE price > 10;` | Virtual table from query. |
| ALTER TABLE | `ALTER TABLE books ADD COLUMN author STRING;` | Modify table structure. |
| DROP TABLE | `DROP TABLE IF EXISTS books;` | Remove table. |
| SHOW TABLES | `SHOW TABLES;` | List tables in schema. |
| DESCRIBE TABLE | `DESC TABLE books;` | Show column details. |

### Data Manipulation (DML)
| Command | Example | Description |
|---------|---------|-------------|
| SELECT | `SELECT * FROM books LIMIT 10;` | Query with limit. |
| INSERT | `INSERT INTO books VALUES (1, 'SQL Guide', 29.99);` | Add rows. |
| UPDATE | `UPDATE books SET price = 34.99 WHERE id = 1;` | Modify rows. |
| DELETE | `DELETE FROM books WHERE id = 1;` | Remove rows (use TRUNCATE for all). |
| MERGE | `MERGE INTO target USING source ON target.id = source.id WHEN MATCHED THEN UPDATE ...;` | Upsert operation. |

Common Functions:
- Aggregates: `COUNT(*), SUM(price), AVG(price)`
- Filtering: `WHERE price > 10 GROUP BY author HAVING COUNT(*) > 5`
- Window: `ROW_NUMBER() OVER (PARTITION BY author ORDER BY price DESC)`

## Data Loading & Stages
Load big data from files (CSV, JSON, Parquet) via stages for efficiency.

### Create Stage
```
CREATE OR REPLACE STAGE my_stage
  URL = 's3://my-bucket/'
  CREDENTIALS = (AWS_KEY_ID = 'key' AWS_SECRET_KEY = 'secret');
```
- Internal: `@my_internal_stage`
- External: Cloud storage integration.

### List & Copy
- List files: `LIST @my_stage;`
- Copy to Table:
```
COPY INTO practice.public.orders
FROM @my_stage
FILE_FORMAT = (TYPE = CSV FIELD_DELIMITER = ',' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE'  -- Or 'ABORT_STATEMENT', 'SKIP_FILE'
PATTERN = '.*orders.*\.csv'
VALIDATION_MODE = 'RETURN_ERRORS';  -- Dry-run for errors
```
For JSON: Use `TYPE = JSON` and `VARIANT` column type. Query as `SELECT raw_file:city FROM json_table;`

Tips: Use separate warehouse for loads; validate with `SIZE_LIMIT` or `RETURN_N_ROWS`.

## Warehouse Management
| Command | Example | Description |
|---------|---------|-------------|
| CREATE WAREHOUSE | `CREATE WAREHOUSE big_wh WAREHOUSE_SIZE = 'LARGE' AUTO_SCALE = TRUE;` | New compute cluster. |
| ALTER WAREHOUSE | `ALTER WAREHOUSE big_wh SET WAREHOUSE_SIZE = 'XL';` | Resize or suspend. |
| SHOW WAREHOUSES | `SHOW WAREHOUSES;` | List warehouses. |
| USE WAREHOUSE | `USE WAREHOUSE big_wh;` | Switch context. |

Auto-scale for big data bursts; suspend idle ones to save credits.

## Roles, Grants & Security
- Current: `SELECT CURRENT_ROLE(); SELECT CURRENT_USER();`
- Create Role: `CREATE ROLE analyst_role;`
- Grant: 
  ```
  GRANT USAGE ON WAREHOUSE compute_wh TO ROLE analyst_role;
  GRANT USAGE ON DATABASE practice TO ROLE analyst_role;
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO ROLE analyst_role;
  ```
- Show Grants: `SHOW GRANTS TO ROLE analyst_role;`

Use least-privilege RBAC for big data teams.

## Advanced Features
### Streams & Tasks (CDC & Automation)
- Create Stream: `CREATE STREAM order_stream ON TABLE orders;`
- Task: `CREATE TASK daily_load WAREHOUSE = compute_wh SCHEDULE = 'USING CRON 0 9 * * * UTC' AS COPY INTO orders FROM @stage;`

### Time Travel & Cloning
- Query Past: `SELECT * FROM orders AT (OFFSET => -3600);`  -- 1 hour ago
- Clone: `CREATE TABLE orders_clone CLONE orders;`

### Snowpark (Python/Scala/Java for Big Data)
Integrate UDFs or stored procs for ML/ETL: Use Snowpark APIs for DataFrames.

## AI/ML with Cortex
Snowflake Cortex enables in-platform AI via SQL. Grant via ACCOUNTADMIN.

| Function | Example | Use Case |
|----------|---------|----------|
| CORTEX_COMPLETE | `SELECT CORTEX_COMPLETE('Summarize big data trends', 'MODEL' => 'snowflake-arctic');` | Text generation. |
| CORTEX_SUMMARIZE | `SELECT CORTEX_SUMMARIZE(long_text_column) FROM docs;` | Summarize datasets. |
| CORTEX_SENTIMENT | `SELECT CORTEX_SENTIMENT(feedback) FROM reviews;` | Analyze sentiment at scale. |
| CORTEX_TRANSLATE | `SELECT CORTEX_TRANSLATE(text, 'TARGET_LANGUAGE' => 'es') FROM global_data;` | Multi-language big data. |
| CORTEX_CLASSIFY | `SELECT CORTEX_CLASSIFY(logs, 'CATEGORIES' => 'Error,Warning,Info');` | Categorize logs. |

Models: Llama-3.1-405B (complex tasks), Mistral-7B (summarization). Costs per token; secure in-place processing.

## Best Practices for Big Data
- **Performance**: Use clustering keys on large tables; query with LIMIT initially.
- **Cost Control**: Monitor Query History; right-size warehouses; use multi-cluster for concurrency.
- **Data Quality**: Validate loads; handle errors with ON_ERROR options.
- **Security**: Encrypt at rest/transit; use dynamic masking policies.
- **Scalability**: Partition large loads; leverage external tables for S3 queries without ingestion.
- **Monitoring**: `SHOW PIPES; SHOW STREAMS;` for pipelines; use Streams for CDC in big data flows.

For official docs, visit docs.snowflake.com. Pricing: Starts at $2/credit (varies by region/edition); free trial available.
