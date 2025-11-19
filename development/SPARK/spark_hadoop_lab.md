# Comprehensive Hadoop and Spark Practice Lab

This guide provides a hands-on, comprehensive practice lab for learning Apache Hadoop and Apache Spark. It's designed for beginners to intermediate users, focusing on practical exercises using real-world scenarios. We'll cover setup, core concepts, and step-by-step labs, including code examples that you can execute in a local environment. By the end, you'll have processed sample datasets, built ETL pipelines, and analyzed data using both tools.

The lab assumes basic knowledge of Linux commands, Java, and Python/Scala. Total estimated time: 8-10 hours. We'll use a single-node setup for simplicity, but concepts scale to clusters.

## Prerequisites and Setup

### Hardware/Software Requirements
- OS: Linux (Ubuntu recommended) or macOS; Windows users can use WSL2.
- RAM: At least 8GB (16GB+ ideal for Spark).
- Java: JDK 8 or 11 (Spark 4.0+ supports up to JDK 17).
- Python: 3.8+ (for PySpark).
- Tools: Docker (for easy cluster simulation), Git.

### Step 1: Install Java
```bash
# Download and install OpenJDK 11
sudo apt update
sudo apt install openjdk-11-jdk
java -version  # Verify: openjdk version "11.x"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
```

### Step 2: Install Hadoop (Version 3.3.6)
1. Download from [Apache Hadoop](https://hadoop.apache.org/releases.html).
```bash
wget https://downloads.apache.org/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
tar -xzf hadoop-3.3.6.tar.gz
sudo mv hadoop-3.3.6 /opt/hadoop
export HADOOP_HOME=/opt/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```
2. Configure `core-site.xml` (`$HADOOP_HOME/etc/hadoop/core-site.xml`):
```xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
```
3. Configure `hdfs-site.xml` (`$HADOOP_HOME/etc/hadoop/hdfs-site.xml`):
```xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///opt/hadoop/hdfs/namenode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///opt/hadoop/hdfs/datanode</value>
    </property>
</configuration>
```
4. Format HDFS and start:
```bash
hdfs namenode -format
start-dfs.sh
jps  # Verify: NameNode, DataNode
```
Test: `hdfs dfs -ls /` (should work).

### Step 3: Install Spark (Version 4.0.0 with Hadoop 3)
1. Download from [Apache Spark](https://spark.apache.org/downloads.html) (pre-built for Hadoop 3.x).
```bash
wget https://downloads.apache.org/spark/spark-4.0.0/spark-4.0.0-bin-hadoop3.tgz
tar -xzf spark-4.0.0-bin-hadoop3.tgz
sudo mv spark-4.0.0-bin-hadoop3 /opt/spark
export SPARK_HOME=/opt/spark
export PATH=$PATH:$SPARK_HOME/bin
```
2. Set environment variables in `~/.bashrc`:
```bash
echo 'export HADOOP_HOME=/opt/hadoop' >> ~/.bashrc
echo 'export SPARK_HOME=/opt/spark' >> ~/.bashrc
echo 'export PATH=$PATH:$HADOOP_HOME/bin:$SPARK_HOME/bin' >> ~/.bashrc
source ~/.bashrc
```
3. Test Spark Shell: `spark-shell` (Scala) or `pyspark` (Python). Exit with `:quit`.

### Optional: Docker for Quick Cluster
For a pre-configured setup, use Docker Compose from the GitHub repo [Big-Data-Hadoop-Spark-lab](https://github.com/Kmohamedalie/Big-Data-Hadoop-Spark-lab). Clone and run:
```bash
git clone https://github.com/Kmohamedalie/Big-Data-Hadoop-Spark-lab.git
cd Big-Data-Hadoop-Spark-lab
docker-compose up -d
```
Access via `docker exec -it <container> bash`.

## Sample Dataset
We'll use a retail sales dataset (e.g., customer transactions). Download a sample CSV:
```bash
wget https://raw.githubusercontent.com/databricks/learning-spark-v2/master/databricks-datasets/retail-org/sales.csv -P /tmp/
hdfs dfs -mkdir /user/input
hdfs dfs -put /tmp/sales.csv /user/input/
```
Dataset structure (CSV): `SalesID,TransactionDate,CustomerID,ProductID,Quantity,SalesAmount,StoreID`
- Example rows: 1,2025-01-01,101,1,2,99.99,1

## Lab 1: Hadoop Basics - HDFS and MapReduce
**Objective:** Store data in HDFS and run a simple MapReduce job to count total sales by product.

### Exercise 1.1: HDFS Operations
1. Upload data: Already done above.
2. List files: `hdfs dfs -ls /user/input`
3. Read content: `hdfs dfs -cat /user/input/sales.csv | head -5`
4. Create output dir: `hdfs dfs -mkdir /user/output`

### Exercise 1.2: MapReduce Job (Word Count Variant - Sales by Product)
Create a Java MapReduce job (or use Python with Hadoop Streaming for simplicity).

**Python Mapper (mapper.py):**
```python
#!/usr/bin/env python
import sys
for line in sys.stdin:
    line = line.strip()
    if line:
        parts = line.split(',')
        if len(parts) >= 6:
            product_id = parts[3]
            sales = float(parts[5])
            print(f"{product_id}\t{sales}")
```

**Python Reducer (reducer.py):**
```python
#!/usr/bin/env python
import sys
sales_dict = {}
for line in sys.stdin:
    line = line.strip()
    if line:
        product_id, sales = line.split('\t', 1)
        sales = float(sales)
        if product_id in sales_dict:
            sales_dict[product_id] += sales
        else:
            sales_dict[product_id] = sales
for product, total in sales_dict.items():
    print(f"{product}\t{total}")
```

Run:
```bash
chmod +x mapper.py reducer.py
hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -files mapper.py,reducer.py \
    -mapper mapper.py \
    -reducer reducer.py \
    -input /user/input/sales.csv \
    -output /user/output/sales_by_product
```
View output: `hdfs dfs -cat /user/output/sales_by_product/part-00000`

**Expected Output:** ProductID\tTotalSales (e.g., 1\t199.98)

## Lab 2: Spark Basics - RDDs and DataFrames
**Objective:** Load data into Spark, perform transformations, and aggregate.

Start PySpark: `pyspark --master local[*]`

### Exercise 2.1: RDD Operations
```python
# Load CSV as RDD
rdd = sc.textFile("hdfs://localhost:9000/user/input/sales.csv")

# Parse and map to (product_id, sales)
def parse_line(line):
    parts = line.split(',')
    return (parts[3], float(parts[5])) if len(parts) >= 6 else None

sales_rdd = rdd.map(parse_line).filter(lambda x: x is not None)

# Reduce by key (total sales per product)
total_sales_rdd = sales_rdd.reduceByKey(lambda a, b: a + b)

# Collect and print
print(total_sales_rdd.collect())  # [(product1, total1), ...]
```

### Exercise 2.2: DataFrames and Spark SQL
```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, sum as spark_sum

spark = SparkSession.builder.appName("RetailAnalysis").getOrCreate()

# Read CSV into DataFrame
df = spark.read.csv("hdfs://localhost:9000/user/input/sales.csv", header=True, inferSchema=True)

# Show schema and sample
df.printSchema()
df.show(5)

# Aggregate sales by product
df.groupBy("ProductID").agg(spark_sum("SalesAmount").alias("TotalSales")).show()

# SQL Query
df.createOrReplaceTempView("sales")
spark.sql("SELECT ProductID, SUM(SalesAmount) as TotalSales FROM sales GROUP BY ProductID").show()

# Save output
df.write.mode("overwrite").parquet("hdfs://localhost:9000/user/output/sales_parquet")
```

**Expected Output:** DataFrame with ProductID and TotalSales columns.

## Lab 3: Integrated Hadoop-Spark Workflow
**Objective:** Use Spark to process HDFS data and write back, simulating ETL.

### Exercise 3.1: PySpark with HDFS
```python
# In PySpark shell
df = spark.read.csv("hdfs://localhost:9000/user/input/sales.csv", header=True, inferSchema=True)

# Filter high-value sales (>50) and add a column
from pyspark.sql.functions import lit
filtered_df = df.filter(col("SalesAmount") > 50).withColumn("HighValue", lit(True))

# Write to HDFS as Parquet (efficient format)
filtered_df.write.mode("overwrite").parquet("hdfs://localhost:9000/user/output/high_value_sales")

# Read back and join with original (simulate analytics)
original_df = spark.read.parquet("hdfs://localhost:9000/user/input/sales.parquet")  # Assume converted earlier
join_df = filtered_df.join(original_df, "SalesID").select("SalesID", "TotalSales", "HighValue")
join_df.show()
```

### Exercise 3.2: Spark Submit Job
Save the above as `etl_job.py` and submit:
```bash
spark-submit --master local[*] etl_job.py
```

## Lab 4: Advanced Practice - Hive Integration and ML
**Objective:** Query with Hive on Spark and basic ML.

### Setup Hive (Optional Extension)
Download Hive 3.1.3, configure with Hadoop, and enable Spark as execution engine in `hive-site.xml`:
```xml
<property>
    <name>spark.sql.catalogImplementation</name>
    <value>hive</value>
</property>
```
Start Hive: `hive`, create table:
```sql
CREATE TABLE sales (SalesID INT, TransactionDate STRING, CustomerID INT, ProductID INT, Quantity INT, SalesAmount DOUBLE, StoreID INT)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' STORED AS TEXTFILE
LOCATION '/user/input/sales.csv';
```
Query: `SELECT ProductID, SUM(SalesAmount) FROM sales GROUP BY ProductID;`

### Exercise 4.1: Simple ML with Spark MLlib
```python
from pyspark.ml.feature import VectorAssembler
from pyspark.ml.regression import LinearRegression

# Assume df from Lab 2
assembler = VectorAssembler(inputCols=["Quantity", "StoreID"], outputCol="features")
df_assembled = assembler.transform(df)

# Train model to predict SalesAmount
lr = LinearRegression(featuresCol="features", labelCol="SalesAmount")
lr_model = lr.fit(df_assembled)

# Predictions
predictions = lr_model.transform(df_assembled)
predictions.select("SalesAmount", "prediction").show()
```

## Best Practices and Troubleshooting
- **Monitoring:** Use Spark UI (`http://localhost:4040`) and Hadoop UI (`http://localhost:9870`).
- **Optimization:** Use Parquet/ORC for storage; cache DataFrames for reuse (`df.cache()`).
- **Common Issues:**
  - Permission errors: `hdfs dfs -chmod -R 777 /user`
  - OutOfMemory: Increase executor memory in `spark-submit --executor-memory 4g`.
- **Scaling:** For clusters, use YARN: `--master yarn`.

## Additional Resources for Deeper Practice
| Resource | Description | Link |
|----------|-------------|------|
| Coursera: Introduction to Big Data with Spark and Hadoop | Hands-on labs with Docker/K8s, MapReduce, Spark SQL. | [Coursera](https://www.coursera.org/learn/introduction-to-big-data-with-spark-hadoop) |
| Udemy: The Ultimate Hands-On Hadoop | 20+ examples, MapReduce to Spark, real projects. | [Udemy](https://www.udemy.com/course/the-ultimate-hands-on-hadoop-tame-your-big-data/) |
| GitHub: Big Data Hadoop Spark Lab | Docker-based labs for HDFS, MapReduce, Hive, Spark submit. | [GitHub](https://github.com/Kmohamedalie/Big-Data-Hadoop-Spark-lab) |
| CloudxLab: Big Data with Hadoop and Spark | Interactive cluster with Kafka, Hive, MLlib. | [CloudxLab](https://cloudxlab.com/course/1/big-data-with-hadoop-and-spark) |
| Databricks: Getting Started with Spark | Free community edition for notebooks and ML. | [Databricks](https://www.databricks.com/spark/getting-started-with-apache-spark) |
| ProjectPro: Top Hadoop Projects | 20+ source code projects for portfolios. | [ProjectPro](https://www.projectpro.io/article/learn-to-build-big-data-apps-by-working-on-hadoop-projects/344) |

Practice these labs iteratively, experiment with larger datasets (e.g., from Kaggle), and track your progress. For certifications, try Spark MCQ tests. If stuck, check Stack Overflow or Reddit's r/dataengineering.
