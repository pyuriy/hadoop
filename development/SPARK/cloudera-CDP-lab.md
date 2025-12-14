# Comprehensive Hadoop and Spark Practice Lab with Cloudera CDP

This practice lab guide provides hands-on exercises for learning Hadoop fundamentals (HDFS and MapReduce) and Apache Spark using Cloudera Data Platform (CDP). CDP is Cloudera's cloud-native data platform, which simplifies cluster management and integrates Hadoop ecosystem tools with Spark for scalable data processing. The lab assumes access to a CDP environment (free trial available via Cloudera). We'll use the web-based Hue interface for HDFS/MapReduce and Cloudera Data Engineering (CDE) for Spark jobs.

Exercises build progressively: start with setup, explore storage/processing basics, then dive into Spark ETL workflows. Estimated time: 4-6 hours. All commands are run via CDP's terminal or Hue unless noted.

## Prerequisites
- **CDP Account**: Sign up for a free Cloudera CDP trial (Public Cloud edition on AWS/GCP/Azure).
- **Tools**: AWS CLI (for S3 uploads if on AWS); basic Python knowledge for Spark.
- **Access Roles**: DEAdmin for cluster setup; DEUser for job execution.
- **Sample Data**: Download `access.log.txt` (web server logs, ~1MB) from a public source like [Apache logs sample](https://github.com/logstash/logstash-contrib/raw/master/examples/apache-logs/access.log) or use the tutorial assets.

**Key Concepts**:
- **Hadoop**: Distributed storage (HDFS) and batch processing (MapReduce).
- **Spark**: In-memory processing engine for faster ETL, ML, and streaming; integrates natively with HDFS in CDP.
- **CDP Components**: Data Lake for storage; CDE for Spark jobs on virtual clusters.

## Section 1: Setting Up Your CDP Environment
CDP automates cluster provisioning. We'll enable services and create a virtual cluster for Spark.

### Step 1.1: Install Cloudera Manager (On-Prem/CDH Simulation; Skip for Pure CDP Cloud)
For local testing (optional, emulates CDH in CDP):
1. Download Cloudera Manager installer from [Cloudera Downloads](https://www.cloudera.com/downloads/manager5/).
2. Run: `chmod u+x cloudera-manager-installer.bin && sudo ./cloudera-manager-installer.bin`.
3. Access console: `http://localhost:7180` (admin/admin).
4. Follow wizard: Select CDH parcels, add hosts, install JDK/agents.

In CDP Cloud: Log in to [console.cloudera.com](https://console.cloudera.com) and create an environment.

### Step 1.2: Enable Cloudera Data Engineering (CDE)
1. From CDP Home > Data Engineering > Enable Service.
2. Name: `my-cde-cluster`.
3. Workload: General - Small.
4. Auto-Scale: Min 1, Max 20.
5. Create a Virtual Cluster:
   - Name: `spark-lab-cluster`.
   - Auto-Scale: CPU Max 4, Memory Max 4 GB.
   - Click Create (takes ~10-15 mins).

**Exercise 1**: Verify setup. In CDE > Overview, check cluster status (Healthy). Run `hdfs dfs -ls /` in the attached terminal to list root HDFS.

## Section 2: Hands-On with HDFS (Hadoop Distributed File System)
HDFS stores large files across nodes with replication (default 3x). Use Hue (File Browser) or CLI.

### HDFS Basics
- NameNode: Metadata manager.
- DataNodes: Store blocks.
- Fault-tolerant: Auto-replicates data.

### Exercise 2.1: Upload and Manage Files
1. In Hue (or CDP terminal): Navigate to HDFS > /user/<your-username>.
2. Upload `access.log.txt`:
   ```
   hdfs dfs -mkdir /user/<username>/data
   hdfs dfs -put access.log.txt /user/<username>/data/
   ```
3. List and view:
   ```
   hdfs dfs -ls /user/<username>/data/
   hdfs dfs -cat /user/<username>/data/access.log.txt | head -5
   ```
   Expected: Shows log lines like `127.0.0.1 - - [10/Oct/2000:13:55:36 -0700] "GET /apache_pb.gif HTTP/1.0" 200 2326`.

**Exercise 2.2: Replication and Permissions**
1. Check replication: `hdfs dfs -ls -R /user/<username>/data/` (look for `rep=3`).
2. Create a read-only dir: `hdfs dfs -mkdir /user/<username>/readonly && hdfs dfs -chmod 444 /user/<username>/readonly`.
3. Attempt write: `hdfs dfs -put test.txt /user/<username>/readonly/` (should fail).

**Validation**: Run `hdfs dfs -du -h /user/<username>/data/` to see size (~1MB).

## Section 3: Introduction to MapReduce
MapReduce processes data in parallel: Map (split/emit key-value pairs), Reduce (aggregate).

### Exercise 3.1: Word Count Job
Use Hue > MapReduce > Examples > WordCount.jar (pre-installed in CDP).

1. Input: `/user/<username>/data/access.log.txt`.
2. Output: `/user/<username>/output/wordcount`.
3. In Hue: Submit job with params `-input <input> -output <output>`.
   - Or CLI: 
     ```
     hadoop jar /opt/cloudera/parcels/CDH/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar wordcount /user/<username>/data/access.log.txt /user/<username>/output/wordcount
     ```
4. View output: `hdfs dfs -cat /user/<username>/output/wordcount/part-r-00000 | head -10`.
   Expected: Counts like `GET	1500` (top HTTP methods).

**Exercise 3.2: Custom Mapper (Optional)**
Write a simple Java mapper to count unique IPs (use IDE, compile JAR, submit via Hue). Focus: Key=IP, Value=1; Reduce sums.

**Key Insight**: MapReduce is disk-based; slow for iterations (leads to Spark).

## Section 4: Apache Spark with PySpark
Spark runs on YARN in CDP, supports Python (PySpark) for ETL. Faster than MapReduce via in-memory caching.

### Exercise 4.1: Run a Basic Spark ETL Job
Process web logs: Parse, filter errors (status >=400), count by IP, save to HDFS/Parquet.

1. Create `web_etl.py` (upload to CDE > Jobs):
   ```python
   from pyspark.sql import SparkSession
   from pyspark.sql.functions import split, regexp_extract, count, col

   spark = SparkSession.builder.appName("WebETL").getOrCreate()

   # Load data from HDFS
   df = spark.read.text("/user/<username>/data/access.log.txt")

   # Parse logs: Extract IP, status (regex for common log format)
   parsed_df = df.select(
       regexp_extract(col("value"), r'^(\S+)', 1).alias("ip"),
       regexp_extract(col("value"), r'" \d{3} ', 0).alias("status").cast("int")
   ).filter(col("status") >= 400)  # Errors only

   # Aggregate: Errors per IP
   result = parsed_df.groupBy("ip").agg(count("*").alias("error_count"))

   # Save as Parquet
   result.write.mode("overwrite").parquet("/user/<username>/output/errors_by_ip")

   # Show top 5
   result.orderBy(col("error_count").desc()).show(5)

   spark.stop()
   ```
2. In CDE > Jobs > Create Job:
   - Name: `web-etl-job`.
   - Upload `web_etl.py`.
   - Runtime: Python 3.
   - Arguments: None.
   - Click Create & Run.
3. Monitor: Jobs > Runs > [Run ID] > Logs/stdout (see output) > Analysis (stages, CPU usage).

**Expected Output**:
```
+------------+------------+
|          ip|error_count |
+------------+------------+
|  127.0.0.1 |          5|
| ...        | ...        |
+------------+------------+
```

**Exercise 4.2: Scheduled ETL and Caching**
1. Edit job: Add Schedule (Every 2 hours).
2. Modify script: Add `parsed_df.cache()` before filter; run and compare times in Analysis tab.
3. Integrate Hive: Register table `CREATE TABLE errors_by_ip USING PARQUET LOCATION '/user/<username>/output/errors_by_ip';` in Hue > Hive.

**Exercise 4.3: Spark SQL Query**
In Hue > Spark > Editor (PySpark shell):
```python
spark.sql("SELECT ip, error_count FROM parquet.`/user/<username>/output/errors_by_ip` WHERE error_count > 1").show()
```

## Section 5: Advanced Exercises and Best Practices
### Exercise 5.1: Data Ingestion with Sqoop (Hadoop to RDBMS)
1. Assume a MySQL DB with sample table. Use Hue > Sqoop:
   - Import: `mysql://host/db.table` to HDFS `/user/<username>/sqoop_data`.
2. Process with Spark: Load as DF, join with logs.

### Exercise 5.2: Spark MLlib (Simple Classification)
Use logs to predict "error-prone IP" (binary: errors > avg).
```python
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.classification import LogisticRegression

# Assume df with features (e.g., request count, status)
assembler = VectorAssembler(inputCols=["req_count"], outputCol="features")
# Train/test split, fit model...
```

### Best Practices
- **Scalability**: Use auto-scaling in CDE; monitor via Cloudera Manager.
- **Security**: Enable Ranger for access control.
- **Optimization**: Cache intermediates; use broadcast joins for small tables.
- **Troubleshooting**: Check YARN logs for OOM; tune executor memory.

## Next Steps and Resources
- Practice CCA175 certification questions for deeper drills.
- Explore Cloudera OnDemand labs (100+ hours, video + environments).
- Watch: [Intro to PySpark on CDP](https://www.youtube.com/watch?v=KQF40G5ZRKo).

Run these exercises iteratively. If stuck, query CDP docs or community. Happy processing!
