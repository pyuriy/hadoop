# Comprehensive Hadoop and Spark Practice Lab with ClemLab OpenSource Data Platform (ODP)

This guide provides a hands-on, comprehensive practice lab for learning Apache Hadoop and Apache Spark using the ClemLab OpenSource Data Platform (ODP), an alternative 100% open-source Hadoop distribution managed by Apache Ambari. ODP simplifies cluster management, provisioning, and monitoring while supporting the latest stable versions of core components like Hadoop (3.2.2+), Spark, Hive, and more. It's ideal for labs as it uses a web-based UI for installations and differs from standard Apache distributions by providing pre-patched, interoperable packages via Ambari for easier setup and maintenance.

The lab is designed for beginners to intermediate users, focusing on practical exercises with real-world scenarios. We'll cover ODP setup, core concepts, and step-by-step labs, including code examples executable in the ODP environment. By the end, you'll have processed sample datasets, built ETL pipelines, and analyzed data using both tools.

The lab assumes basic knowledge of Linux commands, Java, and Python/Scala. Total estimated time: 8-10 hours (setup may take longer initially). We'll use a single-node setup for simplicity, but ODP scales to clusters via Ambari.

## Prerequisites and Setup

### Hardware/Software Requirements
- OS: Ubuntu 22.04 LTS (recommended for this guide; CentOS/RHEL 7+ also supported).
- RAM: At least 8GB (16GB+ ideal for Spark).
- Java: OpenJDK 8 (included in setup).
- Python: 3.8+ (for PySpark; ODP supports Python 3).
- Tools: SSH, curl, wget (standard on Ubuntu).

### Step 1: Prepare Ubuntu System
```bash
# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
sudo apt install curl unzip tar wget gcc python3 python3-dev openssl ntp openjdk-8-jre-headless -y

# Set ulimit (add to /etc/security/limits.conf for persistence)
ulimit -n 10000

# Configure NTP for time sync
sudo systemctl restart ntp
sudo systemctl enable ntp
```

### Step 2: Configure Network and SSH
1. Edit `/etc/hosts` (replace `<IP>` with localhost IP, e.g., 127.0.0.1, and `<HOSTNAME>` e.g., localhost):
```bash
sudo nano /etc/hosts
# Add: <IP> <HOSTNAME>
```
2. Set up passwordless SSH:
```bash
ssh-keygen -t rsa  # Press Enter for defaults
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Step 3: Add ODP and Ambari Repositories
```bash
cd /etc/apt/sources.list.d
wget https://clemlabs.s3.eu-west-3.amazonaws.com/ubuntu22/ambari-release/2.7.8.0.0-101/ambari.list
wget https://clemlabs.s3.eu-west-3.0.amazonaws.com/ubuntu22/odp-release/1.2.1.0-187/odp.list  # For ODP 1.2.1.0
sudo apt-get update --allow-insecure-repositories
```

### Step 4: Install and Configure Ambari
1. Install Ambari Server and Agent:
```bash
sudo apt install ambari-server ambari-agent -y
```
2. Verify:
```bash
apt-cache showpkg ambari-server
```
3. Set up PostgreSQL (Ambari's default DB):
```bash
sudo apt install postgresql postgresql-contrib -y
sudo postgresql-setup initdb  # Or systemctl start postgresql if already running
sudo systemctl start postgresql
sudo systemctl enable postgresql
```
4. Configure PostgreSQL (`/etc/postgresql/14/main/pg_hba.conf` and `postgresql.conf`):
   - Add to `pg_hba.conf`:
     ```
     local   all             ambari                                trust
     host    all             ambari        0.0.0.0/0               trust
     host    all             ambari        ::/0                    trust
     ```
   - In `postgresql.conf`: `listen_addresses = '*'` and `port = 5432`
   ```bash
   sudo systemctl restart postgresql
   ```
5. Create Ambari DB:
```bash
sudo -u postgres psql
```
In psql:
```
CREATE DATABASE ambari;
CREATE USER ambari WITH PASSWORD 'ambari';
GRANT ALL PRIVILEGES ON DATABASE ambari TO ambari;
\connect ambari;
CREATE SCHEMA ambari AUTHORIZATION ambari;
ALTER SCHEMA ambari OWNER TO ambari;
ALTER ROLE ambari SET search_path to 'ambari', 'public';
\q
```
Load schema:
```bash
sudo -u postgres psql -d ambari -f /var/lib/ambari-server/resources/Ambari-DDL-Postgres-CREATE.sql
```
6. Setup and start Ambari Server:
```bash
sudo ambari-server setup -s
# Follow prompts: Choose PostgreSQL, provide DB details (ambari/ambari)
sudo ambari-server start
```
Access Ambari UI: http://<HOSTNAME>:8080 (default admin/admin). Complete initial wizard if prompted.

### Step 5: Install ODP Stack via Ambari UI
1. In Ambari UI: Launch "Launch Install Wizard" > Select "ODP 1.2" stack.
2. Register hosts: Add your single node (localhost).
3. Select services: Choose HDP Services > Include HDFS, YARN, MapReduce2, Spark2, Hive (for Lab 4).
4. Assign masters/slaves to your node.
5. Configure databases (use embedded or PostgreSQL as above).
6. Review and install. Ambari will download and configure Hadoop (~3.3.x), Spark (~3.2.x based on ODP 1.2), etc.
7. Start services via Ambari.

### Step 6: Verify Setup
- In Ambari UI: Check service statuses (green for healthy).
- Test HDFS: `hdfs dfs -ls /`
- Test Spark: `spark-shell` (should launch).
- Environment vars: Add to `~/.bashrc`:
```bash
export HADOOP_HOME=/usr/hdp/current/hadoop-client  # ODP path
export SPARK_HOME=/usr/hdp/current/spark2-client
export PATH=$PATH:$HADOOP_HOME/bin:$SPARK_HOME/bin
source ~/.bashrc
```

### Optional: Docker/Ansible for Quick Setup
For faster testing, use ClemLab's GitHub Ansible playbook: Clone https://github.com/clemlabprojects/ansible-odp-cluster-installation and run for single-node. Or explore ARM support for lighter setups.

## Sample Dataset
Upload to HDFS via Ambari Files view or CLI:
```bash
wget https://raw.githubusercontent.com/databricks/learning-spark-v2/master/databricks-datasets/retail-org/sales.csv -P /tmp/
hdfs dfs -mkdir /user/input
hdfs dfs -put /tmp/sales.csv /user/input/
```
Dataset structure (CSV): `SalesID,TransactionDate,CustomerID,ProductID,Quantity,SalesAmount,StoreID`

## Lab 1: Hadoop Basics - HDFS and MapReduce
**Objective:** Store data in HDFS and run a simple MapReduce job to count total sales by product. Use Ambari for monitoring.

### Exercise 1.1: HDFS Operations
1. Upload data: Done above.
2. List files: `hdfs dfs -ls /user/input`
3. Read content: `hdfs dfs -cat /user/input/sales.csv | head -5`
4. Create output dir: `hdfs dfs -mkdir /user/output`
Monitor in Ambari > HDFS > Live Nodes.

### Exercise 1.2: MapReduce Job (Word Count Variant - Sales by Product)
Use Hadoop Streaming (same as before; ODP supports it).

**Python Mapper (mapper.py):** (Same code as original)
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

**Python Reducer (reducer.py):** (Same)
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

Run (use ODP's hadoop path):
```bash
chmod +x mapper.py reducer.py
$HADOOP_HOME/bin/hadoop jar $HADOOP_HOME/share/hadoop/tools/lib/hadoop-streaming-*.jar \
    -files mapper.py,reducer.py \
    -mapper mapper.py \
    -reducer reducer.py \
    -input /user/input/sales.csv \
    -output /user/output/sales_by_product
```
View: `hdfs dfs -cat /user/output/sales_by_product/part-00000`

**Expected Output:** ProductID\tTotalSales (e.g., 1\t199.98)  
Monitor job in Ambari > MapReduce2 > Jobs.

## Lab 2: Spark Basics - RDDs and DataFrames
**Objective:** Load data into Spark, perform transformations, and aggregate. ODP integrates Spark with YARN.

Start PySpark: `pyspark --master yarn` (or local[*] for single-node).

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
Monitor in Ambari > Spark2 > Spark History.

## Lab 3: Integrated Hadoop-Spark Workflow
**Objective:** Use Spark to process HDFS data and write back, simulating ETL. Leverage YARN for resource management.

### Exercise 3.1: PySpark with HDFS
```python
# In PySpark shell (yarn mode)
df = spark.read.csv("hdfs://localhost:9000/user/input/sales.csv", header=True, inferSchema=True)

# Filter high-value sales (>50) and add a column
from pyspark.sql.functions import lit
filtered_df = df.filter(col("SalesAmount") > 50).withColumn("HighValue", lit(True))

# Write to HDFS as Parquet
filtered_df.write.mode("overwrite").parquet("hdfs://localhost:9000/user/output/high_value_sales")

# Read back and join with original
original_df = spark.read.parquet("hdfs://localhost:9000/user/output/sales_parquet")
join_df = filtered_df.join(original_df, "SalesID").select("SalesID", "SalesAmount", "HighValue")
join_df.show()
```

### Exercise 3.2: Spark Submit Job
Save as `etl_job.py` and submit via YARN:
```bash
$SPARK_HOME/bin/spark-submit --master yarn etl_job.py
```

## Lab 4: Advanced Practice - Hive Integration and ML
**Objective:** Query with Hive on Spark and basic ML. ODP includes Hive 3.1.3 with Spark integration.

### Setup Hive (via Ambari)
In Ambari UI: Services > Hive > Enable, configure Metastore (PostgreSQL or embedded).

Start Hive CLI: `beeline -u jdbc:hive2://localhost:10000` (or hive shell).

Create table:
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
- **Monitoring:** Use Ambari UI (http://localhost:8080) for services, jobs, and configs. Spark UI via YARN.
- **Optimization:** Use Parquet/ORC; cache DataFrames (`df.cache()`). Tune YARN in Ambari.
- **Common Issues:**
  - Repo errors: Verify S3 URLs; use `--allow-insecure-repositories`.
  - DB connection: Check PostgreSQL logs.
  - OutOfMemory: Increase YARN containers in Ambari > YARN > Configs.
- **Scaling:** Add hosts in Ambari for multi-node.

## Additional Resources for Deeper Practice
| Resource | Description | Link |
|----------|-------------|------|
| ODP FAQ | Installation overviews, components like Spark/Hadoop. | [ODP FAQ](https://www.opensourcedataplatform.com/faq/) |
| ClemLab GitHub | Ansible scripts for ODP cluster install. | [GitHub](https://github.com/clemlabprojects/ansible-odp-cluster-installation) |
| LinkedIn Guide | Detailed Ubuntu setup for Ambari/ODP. | [LinkedIn](https://www.linkedin.com/pulse/ubuntu-2204-installation-clemlab-ambari-odp-stack-yevhenii-kotul-dlxbf) |
| Ambari Docs | General cluster management. | [Ambari](https://ambari.apache.org/) |
| ODP Blog | ARM support, releases (e.g., ODP 1.2.4.0). | [ODP Blog](https://www.opensourcedataplatform.com/blog/) |

Practice iteratively with larger datasets. For support, check ODP community or GitHub issues. Happy coding!
