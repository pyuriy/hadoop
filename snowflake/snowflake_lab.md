# Comprehensive Hands-On Lab for Snowflake

This lab guide provides a structured, step-by-step hands-on experience with Snowflake, covering core concepts from setup to advanced features like data loading, querying, cloning, and secure sharing. It's designed for beginners to intermediate users, such as database administrators or data engineers, and can be completed in 2-3 hours using a free 30-day trial account. The lab uses sample data from the Snowflake Public Data Marketplace for a grocery retailer scenario analyzing consumer packaged goods (CPG) companies, including stock prices and SEC filings.

## Prerequisites
- Sign up for a free Snowflake trial at [https://trial.snowflake.com](https://trial.snowflake.com). Choose the Enterprise edition and your preferred cloud provider/region (e.g., AWS US West). You'll receive login credentials via email.
- Access the Snowflake web UI (Snowsight) at the provided URL.
- No prior Snowflake experience required, but basic SQL knowledge helps.
- Enable a worksheet in Snowsight for running queries (Projects > Worksheets > Create).

**Estimated Time:** 120-180 minutes  
**Resources:** Snowflake Quickstarts [Getting Started Guide](https://quickstarts.snowflake.com/guide/getting_started_with_snowflake/index.html) and official docs at [docs.snowflake.com](https://docs.snowflake.com).

## Lab Overview
You'll build a data pipeline for analyzing CPG company data:
1. Set up your environment (database, warehouse, roles).
2. Load structured (CSV) and semi-structured (JSON) data.
3. Query and analyze data, including joins and aggregations.
4. Use advanced features like cloning, Time Travel, and data sharing.
5. Explore the Data Marketplace and monitor performance.

Set your default context in every worksheet: Role = `SYSADMIN`, Warehouse = `COMPUTE_WH` (default), Database = your lab database, Schema = `PUBLIC`. Switch roles via the context dropdown if needed.

---

## Section 1: Environment Setup (15 minutes)
### Step 1.1: Log In and Navigate the UI
1. Log in to Snowsight using your trial credentials.
2. Explore key areas:
   - **Projects > Worksheets**: Create a new worksheet named "Snowflake_Lab".
   - **Catalog > Databases**: View existing databases (e.g., default `SNOWFLAKE`).
   - **Compute > Warehouses**: Note the default `COMPUTE_WH` (size: X-Small).
   - **Activity > Query History**: Monitor queries here later.
3. Run a test query: `SELECT CURRENT_VERSION();` to confirm connection. Expected output: Current Snowflake version (e.g., 8.x as of 2025).

### Step 1.2: Create a Database and Warehouse
1. In your worksheet, run:
   ```
   CREATE DATABASE LAB_DB;
   USE DATABASE LAB_DB;
   USE SCHEMA PUBLIC;
   ```
   Verify in Catalog > Databases > LAB_DB.

2. Create a custom warehouse for analytics:
   ```
   CREATE WAREHOUSE ANALYTICS_WH
   WAREHOUSE_SIZE = 'MEDIUM'
   AUTO_SUSPEND = 300
   AUTO_RESUME = TRUE
   MIN_CLUSTER_COUNT = 1
   MAX_CLUSTER_COUNT = 2;
   ```
   Use it: `USE WAREHOUSE ANALYTICS_WH;`. Edit via Compute > Warehouses for resizing.

### Step 1.3: Set Up Roles for Security
1. Switch to `ACCOUNTADMIN` role: Use the context dropdown.
2. Create a custom role:
   ```
   CREATE ROLE LAB_ANALYST;
   GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE LAB_ANALYST;
   GRANT USAGE ON DATABASE LAB_DB TO ROLE LAB_ANALYST;
   GRANT CREATE SCHEMA, CREATE TABLE, CREATE VIEW ON DATABASE LAB_DB TO ROLE LAB_ANALYST;
   GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA LAB_DB.PUBLIC TO ROLE LAB_ANALYST;
   ```
3. Create a test user (optional): 
   ```
   CREATE USER LAB_USER PASSWORD = 'SecurePass123!';
   GRANT ROLE LAB_ANALYST TO USER LAB_USER;
   ```
   Switch to `LAB_ANALYST` and test: `SELECT CURRENT_ROLE();`.

**Checkpoint:** Run `SHOW GRANTS TO ROLE LAB_ANALYST;`. You should see privileges on the warehouse and database.

---

## Section 2: Data Loading Basics (30 minutes)
### Step 2.1: Create Tables and File Format
We'll load company metadata (CSV) and SEC filings (JSON).

1. Create tables:
   ```
   CREATE OR REPLACE TABLE COMPANY_METADATA (
       CYBERSYN_COMPANY_ID STRING,
       COMPANY_NAME STRING,
       PERMID_SECURITY_ID STRING,
       PRIMARY_TICKER STRING,
       SECURITY_NAME STRING,
       ASSET_CLASS STRING,
       PRIMARY_EXCHANGE_CODE STRING,
       PRIMARY_EXCHANGE_NAME STRING,
       SECURITY_STATUS STRING,
       GLOBAL_TICKERS VARIANT,
       EXCHANGE_CODE VARIANT,
       PERMID_QUOTE_ID VARIANT
   );
   ```

2. Define a CSV file format:
   ```
   CREATE OR REPLACE FILE FORMAT CSV_FORMAT
   TYPE = 'CSV'
   FIELD_DELIMITER = ','
   SKIP_HEADER = 1
   FIELD_OPTIONALLY_ENCLOSED_BY = '"'
   NULL_IF = ('NULL', 'null', '')
   ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;
   ```
   Verify: `SHOW FILE FORMATS;`.

### Step 2.2: Create an External Stage and Load Structured Data
Snowflake stages point to cloud storage (e.g., S3).

1. Create stage:
   ```
   CREATE STAGE LAB_STAGE
   URL = 's3://sfquickstarts/zero_to_snowflake/cybersyn-consumer-company-metadata-csv/';
   ```
   List files: `LIST @LAB_STAGE;`. Expected: One CSV file.

2. Load data (resize warehouse to 'LARGE' for speed first):
   ```
   ALTER WAREHOUSE ANALYTICS_WH SET WAREHOUSE_SIZE = 'LARGE';
   COPY INTO COMPANY_METADATA
   FROM @LAB_STAGE
   FILE_FORMAT = CSV_FORMAT
   PATTERN = '.*csv.*'
   ON_ERROR = 'CONTINUE';
   ```
   Check load: `SELECT COUNT(*) FROM COMPANY_METADATA;`. Expected: ~100 rows.

3. View errors (if any): 
   ```
   COPY INTO COMPANY_METADATA
   FROM @LAB_STAGE
   FILE_FORMAT = CSV_FORMAT
   VALIDATION_MODE = 'RETURN_ERRORS';
   ```
   Truncate and reload if needed: `TRUNCATE TABLE COMPANY_METADATA;`.

**Performance Tip:** Monitor in Activity > Query History. Compare load times with 'MEDIUM' vs. 'LARGE' sizes.

### Step 2.3: Load Semi-Structured Data (JSON)
1. Create tables:
   ```
   CREATE OR REPLACE TABLE SEC_FILINGS_INDEX (V VARIANT);
   CREATE OR REPLACE TABLE SEC_FILINGS_ATTRIBUTES (V VARIANT);
   ```

2. Create stage:
   ```
   CREATE STAGE SEC_STAGE
   URL = 's3://sfquickstarts/zero_to_snowflake/cybersyn_cpg_sec_filings/';
   LIST @SEC_STAGE;
   ```

3. Load JSON:
   ```
   COPY INTO SEC_FILINGS_INDEX
   FROM @SEC_STAGE/cybersyn_sec_report_index.json.gz
   FILE_FORMAT = (TYPE = 'JSON' STRIP_OUTER_ARRAY = TRUE)
   ON_ERROR = 'SKIP_FILE';

   COPY INTO SEC_FILINGS_ATTRIBUTES
   FROM @SEC_STAGE/cybersyn_sec_report_attributes.json.gz
   FILE_FORMAT = (TYPE = 'JSON' STRIP_OUTER_ARRAY = TRUE)
   ON_ERROR = 'SKIP_FILE';
   ```
   Sample: `SELECT * FROM SEC_FILINGS_INDEX LIMIT 5;`. Data appears as JSON variants.

**Checkpoint:** Query JSON paths: `SELECT V:CIK::STRING AS CIK FROM SEC_FILINGS_INDEX LIMIT 5;`.

---

## Section 3: Querying and Analytics (30 minutes)
### Step 3.1: Create Views for Structured Queries
Flatten semi-structured data into views.

1. Index view:
   ```
   CREATE OR REPLACE VIEW SEC_INDEX_VIEW AS
   SELECT
       V:CIK::STRING AS CIK,
       V:COMPANY_NAME::STRING AS COMPANY_NAME,
       V:ADSH::STRING AS ADSH,
       V:TIMESTAMP_ACCEPTED::TIMESTAMP AS TIMESTAMP_ACCEPTED
   FROM SEC_FILINGS_INDEX;
   ```

2. Attributes view:
   ```
   CREATE OR REPLACE VIEW SEC_ATTRIBUTES_VIEW AS
   SELECT
       V:VALUE::DOUBLE AS VALUE,
       V:TAG::STRING AS TAG,
       V:PERIOD_END_DATE::DATE AS PERIOD_END_DATE
   FROM SEC_FILINGS_ATTRIBUTES;
   ```

3. Query: `SELECT * FROM SEC_INDEX_VIEW LIMIT 10;`.

### Step 3.2: Access Data Marketplace and Join Data
1. Switch to `ACCOUNTADMIN`. Go to Data Products > Marketplace, search "Snowflake Public Data (Free)", and click "Get" to consume stock price data. It appears in `SNOWFLAKE_PUBLIC_DATA_FREE` database.

2. Set context: Database = `SNOWFLAKE_PUBLIC_DATA_FREE`, Schema = `PUBLIC_DATA_FREE`.
3. Run a join query for stock analysis (Kraft Heinz example, CIK '0001637459'):
   ```
   WITH DATA_PREP AS (
       SELECT 
           IDX.CIK,
           IDX.COMPANY_NAME,
           ATT.VALUE,
           ATT.PERIOD_END_DATE
       FROM LAB_DB.PUBLIC.SEC_ATTRIBUTES_VIEW ATT
       JOIN LAB_DB.PUBLIC.SEC_INDEX_VIEW IDX ON IDX.CIK = ATT.CIK  -- Simplified join
       WHERE IDX.CIK = '0001637459' AND ATT.TAG = 'Revenues'
   )
   SELECT COMPANY_NAME, AVG(VALUE) AS AVG_REVENUE
   FROM DATA_PREP
   GROUP BY COMPANY_NAME;
   ```
   Expected: Aggregated revenue metrics.

4. Advanced analytics with window functions:
   ```
   SELECT
       PRIMARY_TICKER,
       COMPANY_NAME,
       DATE,
       VALUE AS CLOSE_PRICE,
       LAG(VALUE) OVER (PARTITION BY PRIMARY_TICKER ORDER BY DATE) AS PREV_CLOSE,
       (VALUE - LAG(VALUE) OVER (PARTITION BY PRIMARY_TICKER ORDER BY DATE)) / LAG(VALUE) OVER (PARTITION BY PRIMARY_TICKER ORDER BY DATE) AS DAILY_RETURN
   FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.STOCK_PRICE_TIMESERIES TS
   JOIN LAB_DB.PUBLIC.COMPANY_METADATA META ON TS.TICKER = META.PRIMARY_TICKER
   WHERE TS.VARIABLE_NAME = 'Post-Market Close' AND META.COMPANY_NAME LIKE '%Kraft%'
   ORDER BY PRIMARY_TICKER, DATE DESC
   LIMIT 20;
   ```

**Result Cache Demo:** Re-run the query—it should return instantly (no compute credits) if data unchanged.

**Checkpoint:** Export results to CSV via the download icon in the results pane.

---

## Section 4: Advanced Features (30 minutes)
### Step 4.1: Cloning and Time Travel
1. Clone table:
   ```
   CREATE TABLE COMPANY_METADATA_CLONE CLONE COMPANY_METADATA;
   INSERT INTO COMPANY_METADATA_CLONE VALUES ('TEST', 'Test Co', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
   SELECT COUNT(*) FROM COMPANY_METADATA_CLONE;  -- Original unchanged
   ```

2. Time Travel (undo insert):
   ```
   SELECT * FROM COMPANY_METADATA_CLONE AT (OFFSET => -1) LIMIT 5;  -- 1 tx back
   UNDROP TABLE COMPANY_METADATA_CLONE;  -- If dropped accidentally
   ```

### Step 4.2: Secure Data Sharing
1. Create a share:
   ```
   CREATE SHARE LAB_SHARE;
   GRANT USAGE ON DATABASE LAB_DB TO SHARE LAB_SHARE;
   GRANT SELECT ON ALL TABLES IN SCHEMA LAB_DB.PUBLIC TO SHARE LAB_SHARE;
   ```

2. Add consumer (in real scenario, share URL with another account):
   ```
   -- Simulate: GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO SHARE LAB_SHARE; (not needed for internal)
   SELECT * FROM COMPANY_METADATA;  -- Accessible via share
   ```

### Step 4.3: Streams for Change Data Capture (CDC)
1. Create stream:
   ```
   CREATE STREAM COMPANY_STREAM ON TABLE COMPANY_METADATA;
   ```

2. Insert/update: `UPDATE COMPANY_METADATA SET COMPANY_NAME = 'Updated' WHERE PRIMARY_TICKER = 'TEST';`
3. Consume changes: `SELECT * FROM COMPANY_STREAM;`. Clear: `SELECT STREAM_RESET();`.

---

## Section 5: Monitoring, Cleanup, and Best Practices (15 minutes)
### Step 5.1: Monitor Usage
- Query History: Filter by warehouse/date; view profiles for bottlenecks.
- Cost Management (Admin > Billing): Track credits used (expect <1 for this lab).
- Run: `SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY()) LIMIT 10;`.

### Step 5.2: Cleanup
```
DROP DATABASE LAB_DB CASCADE;
DROP WAREHOUSE ANALYTICS_WH;
DROP ROLE LAB_ANALYST;
DROP USER IF EXISTS LAB_USER;
```

### Best Practices
- Use separate warehouses for loading vs. querying to avoid contention.
- Enable auto-suspend (300s) to save costs.
- For big data: Cluster keys on large tables (`ALTER TABLE ... CLUSTER BY (COLUMN);`).
- Secure: Always use RBAC; mask sensitive columns.
- Scale: Auto-scale warehouses for variable loads.

## Next Steps
- Explore advanced quickstarts like [Cortex AI Sentiment Analysis](https://quickstarts.snowflake.com/guide/cortex_ai_sentiment_iceberg/index.html) or [Real-Time CDC](https://quickstarts.snowflake.com/guide/connectors_postgres_cdc/index.html).
- Join a Virtual Hands-on Lab: [snowflake.com/virtual-hands-on-lab](https://www.snowflake.com/virtual-hands-on-lab).
- Practice with Snowpark for Python ML workflows.

If you encounter errors, check Query History or docs.snowflake.com. Happy querying!
