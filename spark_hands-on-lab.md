# Comprehensive Hands-On Lab: Apache Spark with Hadoop

This lab guide provides a structured, hands-on introduction to Apache Spark integrated with Hadoop. We'll cover setup on a single-node environment (suitable for local development), core concepts, and practical exercises using Scala (Spark's native language). By the end, you'll process data stored in Hadoop's HDFS, perform transformations, run SQL queries, and save results back to HDFS-compatible formats like Parquet.

The lab draws from established tutorials and guides for reliability and best practices. It's designed for beginners but includes advanced integration tips.

## Prerequisites
- **OS**: Linux (Ubuntu recommended) or macOS; Windows users can use WSL or a VM.
- **Hardware**: At least 8GB RAM (16GB+ ideal for Spark).
- **Software**:
  - Java JDK 8 or 11 (Spark runs on JVM).
  - Scala 2.12 (matches Spark 3.x).
  - Basic terminal/command-line knowledge.
- **Sample Data**: Download a CSV dataset (e.g., retail sales data) from Kaggle (e.g., "Online Retail Dataset"). Save it as `sales.csv` for use in exercises.

Verify prerequisites:
- Java: `java -version`
- Scala: `scala -version`

## Section 1: Environment Setup
We'll set up a single-node Hadoop cluster and integrate Spark with it using YARN as the cluster manager. This allows Spark to read/write from HDFS.

### Step 1.1: Install Hadoop (Single-Node)
1. Download Hadoop 3.x from [Apache Hadoop](https://hadoop.apache.org/releases.html) (e.g., `hadoop-3.3.6.tar.gz`).
2. Extract: `tar -xzf hadoop-3.3.6.tar.gz -C /opt/`
3. Set environment variables in `~/.bashrc`:
   ```
   export HADOOP_HOME=/opt/hadoop-3.3.6
   export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
   export JAVA_HOME=/usr/lib/jvm/default-java  # Adjust to your JDK path
   ```
4. Source: `source ~/.bashrc`
5. Configure Hadoop:
   - Edit `$HADOOP_HOME/etc/hadoop/core-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>fs.defaultFS</name>
             <value>hdfs://localhost:9000</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/hdfs-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>dfs.replication</name>
             <value>1</value>
         </property>
         <property>
             <name>dfs.namenode.name.dir</name>
             <value>file:///opt/hadoop-3.3.6/data/namenode</value>
         </property>
         <property>
             <name>dfs.datanode.data.dir</name>
             <value>file:///opt/hadoop-3.3.6/data/datanode</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/mapred-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>mapreduce.framework.name</name>
             <value>yarn</value>
         </property>
     </configuration>
     ```
   - Edit `$HADOOP_HOME/etc/hadoop/yarn-site.xml`:
     ```xml
     <configuration>
         <property>
             <name>yarn.nodemanager.aux-services</name>
             <value>mapreduce_shuffle</value>
         </property>
     </configuration>
     ```
6. Format HDFS: `hdfs namenode -format`
7. Start services: `start-dfs.sh && start-yarn.sh`
8. Verify: `jps` (should show NameNode, DataNode, ResourceManager, NodeManager).

### Step 1.2: Install Apache Spark with Hadoop Integration
1. Download Spark 3.x with Hadoop 3 support from [Apache Spark](https://spark.apache.org/downloads.html) (e.g., `spark-3.5.0-bin-hadoop3.tgz`).
2. Extract: `tar -xzf spark-3.5.0-bin-hadoop3.tgz -C /opt/`
3. Set environment variables in `~/.bashrc`:
   ```
   export SPARK_HOME=/opt/spark-3.5.0-bin-hadoop3
   export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
   ```
4. Source: `source ~/.bashrc`
5. Configure Spark for YARN (edit `$SPARK_HOME/conf/spark-defaults.conf`):
   ```
   spark.master yarn
   spark.submit.deployMode client
   ```
6. Verify: Run `spark-shell --master yarn` (starts Scala REPL with Spark on YARN).

**Tip**: For Windows, add `winutils.exe` to `$HADOOP_HOME/bin` for HDFS compatibility.

## Section 2: Core Concepts Quick Review
- **SparkSession**: Entry point for DataFrame/SQL APIs.
- **RDDs/DataFrames**: Distributed data structures; use DataFrames for structured data.
- **Transformations (Lazy)**: e.g., `filter`, `groupBy` – define operations but don't execute yet.
- **Actions**: e.g., `show`, `count` – trigger computation.
- **Hadoop Integration**: Spark reads from HDFS (`hdfs://...`), uses YARN for resource management.

## Section 3: Hands-On Exercises
Use `spark-shell --master yarn` for all exercises. Assume your `sales.csv` has columns: `InvoiceNo`, `StockCode`, `Description`, `Quantity`, `Amount`, `Country`.

### Exercise 3.1: Load Data from Local to HDFS and Read into Spark
1. Create HDFS directory: `hdfs dfs -mkdir /user/yourusername/data`
2. Upload data: `hdfs dfs -put sales.csv /user/yourusername/data/`
3. In spark-shell:
   ```scala
   import org.apache.spark.sql.SparkSession
   import org.apache.spark.sql.functions._

   val spark = SparkSession.builder()
     .appName("SalesLab")
     .master("yarn")  // Hadoop YARN integration
     .getOrCreate()

   val df = spark.read
     .option("header", "true")
     .csv("hdfs:///user/yourusername/data/sales.csv")  // Read from HDFS

   df.show(5)  // Action: Display first 5 rows
   ```
   **Expected Output**: Table of sales data. This demonstrates HDFS integration.

### Exercise 3.2: Data Exploration and Transformations
1. Explore schema: `df.printSchema()`
2. Filter high-value sales (Amount >= 1000):
   ```scala
   val filteredDF = df.filter($"Amount" >= 1000)
   filteredDF.show()
   ```
3. Add a derived column (e.g., Total Value = Quantity * Amount):
   ```scala
   val enrichedDF = filteredDF.withColumn("TotalValue", $"Quantity" * $"Amount")
   enrichedDF.show()
   ```
**Key Insight**: Transformations are lazy; computation happens on `show()`. Avoid common mistake: Forgetting actions leads to no output.

### Exercise 3.3: Aggregations and GroupBy
1. Group by Country and aggregate average Amount:
   ```scala
   val avgByCountry = enrichedDF.groupBy("Country")
     .agg(avg("Amount").as("AvgAmount"), sum("TotalValue").as("TotalSales"))
   avgByCountry.show()
   ```
2. Count rows: `enrichedDF.count()` (Action to trigger full computation).

| Operation | Purpose | Example Output Insight |
|-----------|---------|------------------------|
| groupBy("Country").agg(avg("Amount")) | Average sales per country | Identifies top markets (e.g., UK: 500.2) |
| sum("TotalValue") | Total revenue per group | Scales to billions in large HDFS datasets |

### Exercise 3.4: Spark SQL for Analysis
1. Register DataFrame as temp view:
   ```scala
   enrichedDF.createOrReplaceTempView("sales")
   ```
2. Run SQL query:
   ```scala
   val sqlResult = spark.sql("""
     SELECT Country, COUNT(*) AS TotalTransactions, SUM(Amount) AS TotalAmount
     FROM sales
     GROUP BY Country
     ORDER BY TotalAmount DESC
   """)
   sqlResult.show()
   ```
**Hadoop Tie-In**: This works seamlessly with Hive tables on HDFS for production warehousing.

### Exercise 3.5: Save Results to HDFS (Parquet Format)
1. Write aggregated results:
   ```scala
   avgByCountry.write
     .mode("overwrite")
     .parquet("hdfs:///user/yourusername/data/sales_summary.parquet")
   ```
2. Verify: `hdfs dfs -ls /user/yourusername/data/` (should show Parquet file).
3. Read back: 
   ```scala
   val loaded = spark.read.parquet("hdfs:///user/yourusername/data/sales_summary.parquet")
   loaded.show()
   ```
**Why Parquet?**: Columnar, compressed format optimized for Hadoop ecosystems.

### Exercise 3.6: Advanced Integration (Optional: Spark with Hive)
1. If Hive is installed (part of Hadoop), enable in `spark-defaults.conf`: `spark.sql.catalogImplementation=hive`
2. Create Hive table in spark-shell:
   ```scala
   spark.sql("""
     CREATE TABLE IF NOT EXISTS sales_hive (
       InvoiceNo STRING, StockCode STRING, Description STRING,
       Quantity INT, Amount DOUBLE, Country STRING
     ) USING hive
   """)
   ```
3. Insert and query: Load your DF into Hive and run SQL as in 3.4.

## Section 4: Troubleshooting and Best Practices
- **Errors**:
  - "No FileSystem for scheme: hdfs": Ensure `HADOOP_HOME` is set.
  - OutOfMemory: Increase YARN resources in `yarn-site.xml` (e.g., `yarn.nodemanager.resource.memory-mb 4096`).
- **Best Practices**:
  - Use `cache()` for reused DataFrames.
  - Monitor jobs via YARN UI: http://localhost:8088.
  - Scale to multi-node for real clusters.
- **Common Pitfalls**: Lazy evaluation – always pair transformations with actions.

## Conclusion and Next Steps
You've now set up Spark on Hadoop, loaded/processed HDFS data, and performed analytics. This foundation scales to production big data pipelines.

**Extensions**:
- Try PySpark (Python) for the same exercises.
- Explore HBase integration for NoSQL.
- Enroll in full courses for more labs (e.g., Coursera or Udemy).

GitHub Repo for Code: Fork [Spark Examples](https://github.com/spark-examples) and adapt.

Stop services: `stop-yarn.sh && stop-dfs.sh`. 
