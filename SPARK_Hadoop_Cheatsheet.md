# Comprehensive Apache Spark and Hadoop Cheatsheet

## **1. Introduction to Spark and Hadoop**
- **Apache Hadoop**: A framework for distributed storage (HDFS) and processing (MapReduce) of large datasets.
- **Apache Spark**: A fast, in-memory data processing engine with APIs for Scala, Java, Python (PySpark), and R.
  - **Key Features**: In-memory computation, fault tolerance, RDDs, DataFrames, Datasets, Spark SQL, MLlib, GraphX, and Streaming.
  - **Advantages over Hadoop MapReduce**: Faster (up to 100x in memory), easier APIs, and unified engine for batch/streaming.

## **2. Hadoop Core Components**
- **HDFS (Hadoop Distributed File System)**:
  - Stores large datasets across multiple nodes.
  - Commands:
    - List files: `hdfs dfs -ls /path`
    - Upload file: `hdfs dfs -put localfile /hdfs/path`
    - Download file: `hdfs dfs -get /hdfs/path localfile`
    - Remove file: `hdfs dfs -rm /hdfs/path/file`
    - View file: `hdfs dfs -cat /hdfs/path/file`
- **MapReduce**:
  - Programming model for processing large datasets.
  - Key phases: Map (transform), Shuffle (sort/group), Reduce (aggregate).
  - Example (WordCount in Java):
    ```java
    public class WordCount {
        public static class MapperClass extends Mapper<Object, Text, Text, IntWritable> {
            private final static IntWritable one = new IntWritable(1);
            private Text word = new Text();
            public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
                String[] words = value.toString().split("\\s+");
                for (String w : words) {
                    word.set(w);
                    context.write(word, one);
                }
            }
        }
        public static class ReducerClass extends Reducer<Text, IntWritable, Text, IntWritable> {
            public void reduce(Text key, Iterable<IntWritable> values, Context context) throws IOException, InterruptedException {
                int sum = 0;
                for (IntWritable val : values) {
                    sum += val.get();
                }
                context.write(key, new IntWritable(sum));
            }
        }
    }
    ```
- **YARN (Yet Another Resource Negotiator)**:
  - Manages cluster resources and schedules jobs.
  - Commands:
    - Check application status: `yarn application -list`
    - Kill application: `yarn application -kill <application_id>`

## **3. Spark Core Concepts**
- **RDD (Resilient Distributed Dataset)**:
  - Fault-tolerant collection of elements partitioned across nodes.
  - Operations:
    - Transformations: `map`, `filter`, `groupBy`, `join` (lazy evaluation).
    - Actions: `collect`, `count`, `saveAsTextFile`, `reduce` (trigger computation).
  - Example (PySpark):
    ```python
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.appName("example").getOrCreate()
    data = [1, 2, 3, 4, 5]
    rdd = spark.sparkContext.parallelize(data)
    squared = rdd.map(lambda x: x * x)
    print(squared.collect())  # Output: [1, 4, 9, 16, 25]
    ```
- **DataFrame**:
  - Distributed collection of data organized into named columns (like a table).
  - Example (PySpark):
    ```python
    df = spark.createDataFrame([(1, "Alice"), (2, "Bob")], ["id", "name"])
    df.show()
    # +---+-----+
    # | id| name|
    # +---+-----+
    # |  1|Alice|
    # |  2|  Bob|
    # +---+-----+
    ```
- **Dataset**:
  - Strongly-typed DataFrame API (Scala/Java only).
  - Example (Scala):
    ```scala
    case class Person(id: Int, name: String)
    val ds = Seq(Person(1, "Alice"), Person(2, "Bob")).toDS()
    ds.show()
    ```

## **4. Spark SQL**
- Run SQL queries on DataFrames.
- Commands:
  - Create temporary view: `df.createOrReplaceTempView("table_name")`
  - Run query: `spark.sql("SELECT * FROM table_name WHERE id > 1").show()`
- Example (PySpark):
  ```python
  df = spark.read.csv("data.csv", header=True, inferSchema=True)
  df.createOrReplaceTempView("people")
  result = spark.sql("SELECT name, COUNT(*) as count FROM people GROUP BY name")
  result.show()
  ```

## **5. Spark Streaming**
- Process real-time data streams.
- **DStream**: Sequence of RDDs.
- Example (PySpark Streaming):
  ```python
  from pyspark.streaming import StreamingContext
  ssc = StreamingContext(spark.sparkContext, 1)  # 1-second batch interval
  lines = ssc.socketTextStream("localhost", 9999)
  words = lines.flatMap(lambda line: line.split())
  word_counts = words.map(lambda word: (word, 1)).reduceByKey(lambda a, b: a + b)
  word_counts.pprint()
  ssc.start()
  ssc.awaitTermination()
  ```
- **Structured Streaming**:
  - Stream processing on DataFrames.
  - Example:
    ```python
    lines = spark.readStream.format("socket").option("host", "localhost").option("port", 9999).load()
    words = lines.selectExpr("explode(split(value, ' ')) as word")
    word_counts = words.groupBy("word").count()
    query = word_counts.writeStream.outputMode("complete").format("console").start()
    query.awaitTermination()
    ```

## **6. Spark MLlib**
- Machine learning library for scalable algorithms.
- Example (Linear Regression in PySpark):
  ```python
  from pyspark.ml.regression import LinearRegression
  from pyspark.ml.feature import VectorAssembler
  data = spark.read.csv("data.csv", header=True, inferSchema=True)
  assembler = VectorAssembler(inputCols=["feature1", "feature2"], outputCol="features")
  df = assembler.transform(data)
  lr = LinearRegression(featuresCol="features", labelCol="label")
  model = lr.fit(df)
  model.transform(df).show()
  ```

## **7. Spark Cluster Management**
- **Deployment Modes**:
  - **Standalone**: Spark’s built-in cluster manager.
  - **YARN**: `spark-submit --master yarn --deploy-mode client` or `cluster`.
  - **Mesos**: `spark-submit --master mesos://host:port`.
  - **Kubernetes**: `spark-submit --master k8s://https://host:port`.
- **Common spark-submit Options**:
  ```bash
  spark-submit \
    --master <master-url> \
    --deploy-mode <client|cluster> \
    --class <main-class> \
    --name <app-name> \
    --jars <additional-jars> \
    --conf <key=value> \
    <application-jar> [app-arguments]
  ```
- Monitor jobs: Access Spark UI at `http://<driver>:4040`.

## **8. Performance Tuning**
- **Spark**:
  - Increase parallelism: `spark.default.parallelism`, `spark.sql.shuffle.partitions`.
  - Cache/persist data: `df.cache()` or `rdd.persist(pyspark.StorageLevel.MEMORY_AND_DISK)`.
  - Use appropriate join strategies: Broadcast small tables with `broadcast(df_small)`.
  - Avoid UDFs; prefer built-in functions.
- **Hadoop**:
  - Tune mappers/reducers: `mapreduce.job.maps`, `mapreduce.job.reduces`.
  - Enable compression: `mapreduce.map.output.compress=true`.
  - Optimize HDFS block size: `dfs.blocksize`.

## **9. Common File Formats**
- **Read/Write in Spark**:
  - CSV: `spark.read.csv("path")`, `df.write.csv("path")`
  - Parquet: `spark.read.parquet("path")`, `df.write.parquet("path")`
  - JSON: `spark.read.json("path")`, `df.write.json("path")`
  - ORC: `spark.read.orc("path")`, `df.write.orc("path")`
- **HDFS Operations**:
  - Copy to HDFS: `hdfs dfs -put file.txt /path`
  - Read from HDFS: `hdfs dfs -cat /path/file.txt`

## **10. Troubleshooting**
- **Spark**:
  - OutOfMemoryError: Increase driver/executor memory (`spark.driver.memory`, `spark.executor.memory`).
  - Skewed data: Use `repartition` or `coalesce` to balance partitions.
  - Check logs: `spark.eventLog.enabled=true`, `spark.eventLog.dir=hdfs://path`.
- **Hadoop**:
  - NameNode failure: Check `hdfs-site.xml` for high availability settings.
  - Slow jobs: Monitor YARN ResourceManager UI (`http://<rm>:8088`).

## **11. Useful Commands**
- **Spark Shell**:
  - Start: `spark-shell` (Scala), `pyspark` (Python).
  - Submit job: `spark-submit --master <master> <script.py>`
- **Hadoop**:
  - Check HDFS status: `hdfs dfsadmin -report`
  - Start/stop services: `start-dfs.sh`, `stop-dfs.sh`, `start-yarn.sh`, `stop-yarn.sh`.

## **12. Integration with Other Tools**
- **Hive**: Use `SparkSession` with Hive support (`enableHiveSupport()`).
  - Example: `spark.sql("SELECT * FROM hive_table").show()`
- **Kafka**: Stream data with `spark.readStream.format("kafka")`.
  - Example:
    ```python
    df = spark.readStream.format("kafka") \
        .option("kafka.bootstrap.servers", "localhost:9092") \
        .option("subscribe", "topic") \
        .load()
    ```
- **HBase**: Use `spark-hbase-connector` for integration.

## **13. Best Practices**
- Use DataFrames/Datasets over RDDs for better optimization.
- Leverage Catalyst optimizer for Spark SQL queries.
- Monitor resource usage with Spark UI and YARN ResourceManager.
- Use Parquet/ORC for columnar storage to save space and improve performance.
- Avoid collecting large datasets to driver: `collect()` can cause OOM.
