# Hadoop & Spark Cheat Sheet

## Hadoop Overview
- **Hadoop**: Open-source framework for distributed storage and processing of big data.
- **Core Components**:
  - **HDFS**: Hadoop Distributed File System for storage.
  - **MapReduce**: Programming model for data processing.
  - **YARN**: Resource management and job scheduling.
  - **Hadoop Common**: Utilities and libraries.

### HDFS Commands
- **Basic Operations**:
  - List files: `hdfs dfs -ls /path`
  - Create directory: `hdfs dfs -mkdir /path`
  - Upload file: `hdfs dfs -put localfile /hdfs/path`
  - Download file: `hdfs dfs -get /hdfs/path localfile`
  - Remove file/directory: `hdfs dfs -rm -r /path`
  - View file: `hdfs dfs -cat /path/file`
- **File Management**:
  - Copy: `hdfs dfs -cp /source /destination`
  - Move: `hdfs dfs -mv /source /destination`
  - Check disk usage: `hdfs dfs -du -h /path`
  - Change permissions: `hdfs dfs -chmod 755 /path`
- **Administration**:
  - Check HDFS status: `hdfs dfsadmin -report`
  - Safe mode: `hdfs dfsadmin -safemode enter|leave`
  - Balance data: `hdfs balancer`

### MapReduce
- **Key Concepts**:
  - **Mapper**: Processes input data, emits key-value pairs.
  - **Reducer**: Aggregates mapper output, produces final results.
  - **Job**: Unit of work with input, output, and processing logic.
- **Running a Job**:
  ```bash
  hadoop jar <jar-file> <main-class> <input-path> <output-path>
  ```
- **Common Classes**:
  - Mapper: `org.apache.hadoop.mapreduce.Mapper`
  - Reducer: `org.apache.hadoop.mapreduce.Reducer`
  - Job: `org.apache.hadoop.mapreduce.Job`

### YARN Commands
- **Job Management**:
  - Submit job: `yarn jar <jar-file> <main-class> <args>`
  - List jobs: `yarn application -list`
  - Kill job: `yarn application -kill <application-id>`
- **Cluster Info**:
  - Node status: `yarn node -list`
  - Queue status: `yarn queue -status <queue-name>`

## Spark Overview
- **Apache Spark**: Fast, in-memory data processing engine.
- **Core Components**:
  - **Spark Core**: General execution engine.
  - **Spark SQL**: SQL queries on structured data.
  - **Spark Streaming**: Real-time data processing.
  - **MLlib**: Machine learning library.
  - **GraphX**: Graph processing.
- **Deployment Modes**:
  - Local: `spark://local`
  - Standalone: `spark://<master>:7077`
  - YARN: `yarn-client` or `yarn-cluster`
  - Mesos: `mesos://<master>`

### Spark Shell
- **Start Shell**:
  - Scala: `spark-shell --master <master>`
  - Python (PySpark): `pyspark --master <master>`
- **Basic Commands**:
  - Load data: `spark.read.csv("/path")`
  - Show DataFrame: `df.show()`
  - SQL query: `spark.sql("SELECT * FROM table").show()`

### Spark RDD Operations
- **Transformations** (lazy):
  - `map(func)`: Apply function to each element.
  - `filter(func)`: Select elements based on condition.
  - `flatMap(func)`: Map and flatten results.
  - `groupByKey()`: Group by key.
  - `reduceByKey(func)`: Aggregate by key.
  - `join(otherRDD)`: Join two RDDs.
- **Actions** (trigger computation):
  - `collect()`: Return all elements to driver.
  - `count()`: Count elements.
  - `take(n)`: Return first n elements.
  - `saveAsTextFile(path)`: Save RDD to file.
  - `reduce(func)`: Aggregate elements.

### Spark DataFrame Operations
- **Creating DataFrames**:
  ```python
  df = spark.read.csv("/path", header=True, inferSchema=True)
  ```
- **Common Operations**:
  - Select columns: `df.select("column1", "column2")`
  - Filter rows: `df.filter(df.column > value)`
  - Group by: `df.groupBy("column").agg({"column2": "sum"})`
  - Join: `df1.join(df2, "key_column", "inner")`
  - Sort: `df.orderBy("column", ascending=False)`
  - Drop duplicates: `df.dropDuplicates(["column"])`
- **SQL Queries**:
  ```python
  df.createOrReplaceTempView("table")
  result = spark.sql("SELECT column FROM table WHERE condition")
  ```

### Spark SQL
- **Register Table**:
  ```python
  df.createOrReplaceTempView("table_name")
  ```
- **Run Query**:
  ```python
  spark.sql("SELECT * FROM table_name WHERE column > value").show()
  ```
- **Catalog Operations**:
  - List tables: `spark.catalog.listTables()`
  - Drop table: `spark.catalog.dropTempView("table_name")`

### Spark Streaming
- **StreamingContext**:
  ```python
  from pyspark.streaming import StreamingContext
  ssc = StreamingContext(sparkContext, batchDuration=1)
  ```
- **DStream Operations**:
  - Create from source: `ssc.textFileStream("/path")`
  - Transform: `dstream.map(func)`
  - Window: `dstream.window(windowDuration, slideDuration)`
  - Save: `dstream.saveAsTextFiles("prefix")`
- **Start/Stop**:
  ```python
  ssc.start()
  ssc.awaitTermination()
  ```

### Spark Submit
- **Run Application**:
  ```bash
  spark-submit --master <master> --deploy-mode <mode> app.py
  ```
- **Common Options**:
  - `--num-executors <n>`: Number of executors.
  - `--executor-memory <size>`: Memory per executor (e.g., 4g).
  - `--executor-cores <n>`: Cores per executor.
  - `--conf <key>=<value>`: Custom configuration.

### MLlib
- **Classification**:
  ```python
  from pyspark.ml.classification import LogisticRegression
  lr = LogisticRegression(featuresCol="features", labelCol="label")
  model = lr.fit(training_df)
  predictions = model.transform(test_df)
  ```
- **Regression**:
  ```python
  from pyspark.ml.regression import LinearRegression
  lr = LinearRegression(featuresCol="features", labelCol="label")
  model = lr.fit(training_df)
  ```
- **Clustering**:
  ```python
  from pyspark.ml.clustering import KMeans
  kmeans = KMeans(k=3, seed=1)
  model = kmeans.fit(df)
  ```

### Performance Tuning
- **Caching**:
  - Cache DataFrame: `df.cache()`
  - Persist with storage level: `df.persist(StorageLevel.MEMORY_AND_DISK)`
- **Partitioning**:
  - Repartition: `df.repartition(n)`
  - Coalesce: `df.coalesce(n)`
- **Broadcast Variables**:
  ```python
  broadcast_var = sc.broadcast(value)
  ```
- **Configuration**:
  - Set shuffle partitions: `spark.conf.set("spark.sql.shuffle.partitions", 200)`
  - Enable adaptive query execution: `spark.conf.set("spark.sql.adaptive.enabled", "true")`

### Common File Formats
- **Read**:
  ```python
  df = spark.read.format("parquet").load("/path")
  df = spark.read.json("/path")
  df = spark.read.orc("/path")
  ```
- **Write**:
  ```python
  df.write.mode("overwrite").parquet("/path")
  df.write.mode("append").json("/path")
  ```

### Monitoring
- **Spark UI**: Access at `http://<driver>:4040`
- **Logs**:
  - Check logs: `yarn logs -applicationId <app-id>`
- **Metrics**:
  - Executor metrics: Memory, CPU usage.
  - Job metrics: Stages, tasks, shuffle read/write.

### Troubleshooting
- **Common Issues**:
  - OutOfMemoryError: Increase executor memory or reduce shuffle partitions.
  - Skewed data: Use `repartition` or `salting` for skewed keys.
  - Slow jobs: Check for data skew, enable AQE, or cache intermediate results.
- **Debugging**:
  - View plan: `df.explain()`
  - Check logs: `spark.eventLog.enabled=true`
