# Big Data developer cheat sheet

Below is a compact but comprehensive cheat sheet for a Big Data developer — covering core concepts, tools, commands, code snippets, architecture patterns, tuning tips, debugging steps, and useful references. Use it as a quick reference while designing, implementing, operating, and troubleshooting big data systems.

OVERVIEW — quick mental model
- Big data = large Volume, Velocity, Variety, Veracity, Variability.
- Two processing paradigms: Batch (high throughput, high latency) vs Streaming (low latency, event-driven).
- Lambda / Kappa patterns: Lambda = separate batch + streaming; Kappa = streaming-first, reprocess streams.
- Storage tiers: cold (S3/HDFS), warm (HBase, Cassandra), hot (Redis), analytic (Parquet/ORC on object store).

CORE COMPONENTS & ECOSYSTEM
- Storage: HDFS, S3, Azure Blob, GCS.
- Compute: Spark (batch/stream), Hadoop MapReduce (legacy), Flink (stream-first), Beam (unified API).
- Messaging: Kafka, Pulsar, Kinesis.
- Query engines: Hive, Presto/Trino, Impala, Spark SQL.
- NoSQL: HBase, Cassandra, MongoDB, DynamoDB.
- Schema/Serde: Avro, Parquet, ORC, JSON, Protobuf.
- Orchestration: Airflow, Oozie, Luigi, Dagster.
- Metadata/Governance: Hive Metastore, Glue Data Catalog, Atlas, Data Catalogs.
- CI/CD, container orchestration: Docker, Kubernetes.
- Observability: Prometheus, Grafana, Elastic Stack, Cloudera Manager.

STORAGE FORMATS (when to use)
- Parquet: columnar, best for analytics, compression, predicate pushdown.
- ORC: similar to Parquet, good in Hive ecosystems.
- Avro: row-based, schema evolution, ideal for Kafka payloads.
- JSON: flexible but large, use for semi-structured; not efficient for analytics.
- CSV: use only for small/simple cases.

SERIALIZATION & SCHEMA
- Avro: good for event messages + Schema Registry.
- Protobuf/Thrift: compact, typed, use when performance matters.
- Confluent Schema Registry: central schema control, compatibility (backward/forward).

HDFS & OBJECT STORE BASICS (common commands)
- List: hdfs dfs -ls /path
- Put local to HDFS: hdfs dfs -put localfile /dest
- Get: hdfs dfs -get /path localdir
- Remove: hdfs dfs -rm -r /path
- Disk usage: hdfs dfs -du -h /path
- Check file: hdfs fsck /path -files -blocks -locations

SPARK QUICK REF
- Modes: local, yarn, standalone, kubernetes
- Submit:
  spark-submit \
    --master yarn \
    --deploy-mode cluster \
    --driver-memory 4g \
    --executor-memory 8g \
    --executor-cores 4 \
    --num-executors 10 \
    --conf spark.sql.shuffle.partitions=200 \
    my_app.py

RDD vs DataFrame vs Dataset:
- RDD: low-level, no optimizations.
- DataFrame: optimized via Catalyst, good for SQL-like ops.
- Dataset (Scala/Java): typed API, combines RDD safety with Catalyst optimizations.

Common transformations (Spark)
- map, flatMap, filter, distinct, union, join, groupBy, reduceByKey, mapPartitions, coalesce, repartition
Common actions
- collect, take, count, saveAsTextFile, saveAsTable, foreachPartition

Spark SQL & DataFrame snippets (PySpark)
- Read parquet:
  df = spark.read.parquet("s3://bucket/path/")
- Write partitioned:
  df.write.mode("overwrite").partitionBy("year","month").parquet("s3://bucket/path/")
- Broadcast join:
  small_df = spark.read.parquet("s3://...").cache()
  df.join(broadcast(small_df), "id")
- UDF vs Pandas UDF: use vectorized (pandas_udf) for performance.

Structured Streaming (PySpark) minimal:
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.appName("ss").getOrCreate()
df = spark.readStream.format("kafka") \
   .option("kafka.bootstrap.servers","kafka:9092") \
   .option("subscribe","topic").load()
# parse and write to parquet
query = df.selectExpr("CAST(value AS STRING) as json") \
    .writeStream.format("parquet") \
    .option("path","s3://bucket/stream/") \
    .option("checkpointLocation","s3://bucket/checkpoints/") \
    .start()
query.awaitTermination()
```
- Exactly-once: use checkpointing + idempotent sinks or transactional sinks (Kafka 0.11+).
- Triggers: processingTime, once, continuous (experimental).
- Watermarks + Event-time windows:
  df.withWatermark("event_time", "10 minutes") \
    .groupBy(window("event_time","5 minutes"), "key").agg(...)

SPARK PERFORMANCE TUNING (cheat)
- Set shuffle partitions to match downstream parallelism: spark.sql.shuffle.partitions
- Use partition pruning (filter on partition columns).
- Avoid wide transformations unless necessary.
- Cache/persist judiciously (MEMORY_AND_DISK).
- Use broadcast join for small tables (spark.conf.set("spark.sql.autoBroadcastJoinThreshold", bytes)).
- Reduce GC pauses: tune executor memory and overhead; prefer G1 GC for large heaps.
- Avoid OOM: use dynamic allocation or tune executor memory and overhead; increase shuffle memory fraction if needed.
- Use parquet/ORC with predicate pushdown and column pruning.

KAFKA QUICK REF
- Start brokers, zookeeper (if old), topics:
  kafka-topics.sh --create --bootstrap-server broker:9092 --replication-factor 3 --partitions 12 --topic my-topic
- List topics:
  kafka-topics.sh --bootstrap-server broker:9092 --list
- Produce:
  kafka-console-producer.sh --broker-list broker:9092 --topic my-topic
- Consume:
  kafka-console-consumer.sh --bootstrap-server broker:9092 --topic my-topic --from-beginning
- Check consumer groups:
  kafka-consumer-groups.sh --bootstrap-server broker:9092 --describe --group my-group
- Key concepts: partition, offset, leader/follower, ISR, retention, acks (0/1/all), idempotent producers, transactions (exactly-once).

KAFKA CONFIGS & TIPS
- acks=all, min.insync.replicas=2 for durability.
- enable.idempotence=true for exactly-once writes from producers.
- Use compacted topics for changelogs.
- Use Schema Registry + Avro/Protobuf for typed messages.

FLINK BASICS
- True stream-first, lower latency, event-time semantics built-in.
- Checkpoints for fault tolerance, state backend (RocksDB) for large state.
- Process function, keyed stream, windowing, stateful operators.
- Savepoints for upgrades.

QUERY ENGINES
- Hive: batch SQL with Hive Metastore. Use for ETL + long-running SQL.
- Presto/Trino: interactive SQL across many data sources.
- Impala: low-latency SQL on HDFS.
- Use external Hive Metastore to share metadata across engines.

NO-SQL DBs
- HBase: wide-column store, strong consistency, good for random reads/writes; integrates with HDFS.
- Cassandra: distributed wide-column DB, eventual consistency, tunable consistency, multi-region.
- When to pick: HBase for HDFS locality and Hadoop integration; Cassandra for multi-datacenter write availability.

DATA MODELS & PARTITIONING
- Partition on high-cardinality? No — partition by columns used for filters (date, country).
- Avoid too many small files (small file problem). Use compaction / coalesce files.
- Bucketing: good for expensive joins when both sides are bucketed on join key.
- Time-partitioned layout for time series (year/month/day); ensure compaction for many small files.
- Use partition pruning and statistics (ANALYZE TABLE) to speed queries.

ETL & INGESTION PATTERNS
- Batch ingestion: Sqoop (RDBMS->HDFS), JDBC connectors.
- Streaming ingestion: Kafka Connect, Flume (older), custom producers.
- CDC (Change Data Capture): Debezium + Kafka for streaming DB changes.
- Idempotency: Design sinks to be idempotent; include unique keys, upserts, or changelog streams.

TRANSACTIONS & CONSISTENCY
- Kafka transactions: producer transactions for atomic writes to multiple partitions/topics.
- Exactly-once in Spark: Structured Streaming with Kafka sink + checkpointing (careful with third-party sinks).
- Use database-native transactions for critical OLTP consistency; analytics systems often settle for eventual consistency.

SECURITY & GOVERNANCE
- Encryption in transit: TLS for Kafka, HDFS, HTTP endpoints.
- Encryption at rest: HDFS encryption zones or object-store server-side encryption.
- AuthN/AuthZ: Kerberos for Hadoop ecosystems, RBAC for platforms, ACLs for Kafka topics.
- Data governance: tag sensitive columns, PII masking, audit logs, lineage (Atlas, OpenLineage).

OBSERVABILITY & MONITORING
- Metrics: Prometheus exporters, JMX, Ganglia, Ambari/Cloudera Manager.
- Logs: ELK/EFK stack (Elasticsearch + Fluentd/Logstash + Kibana).
- Tracing: OpenTelemetry for cross-service tracing.
- Alerts: monitor consumer lag, GC pauses, broker disk usage, job failures, restart rates.

CI/CD & DEPLOYMENT
- Use containerized images for reproducible environments.
- Build artifacts: assembly JARs for Spark, container images for Flink.
- Blue/green or canary for streaming upgrades (use partition reassignment and consumer group migration).
- Use feature flags / small-batch for schema changes.

COMMON COMMANDS & EXAMPLES

Spark submit example:
spark-submit --class com.example.Main \
  --master yarn --deploy-mode cluster \
  --conf spark.dynamicAllocation.enabled=true \
  --num-executors 20 --executor-memory 8G --executor-cores 4 \
  /path/app.jar arg1 arg2

HDFS example:
hdfs dfs -ls /data/events
hdfs dfs -du -h /data/events
hdfs dfs -rm -skipTrash /data/events/old/

Kafka topic create:
kafka-topics.sh --create --bootstrap-server kafka:9092 --replication-factor 3 --partitions 12 --topic events

Kafka consumer groups:
kafka-consumer-groups.sh --bootstrap-server kafka:9092 --describe --group analytics-group

Hive sample:
CREATE EXTERNAL TABLE events (
  id STRING, user_id STRING, event_time TIMESTAMP, properties MAP<STRING,STRING>
)
PARTITIONED BY (dt STRING)
STORED AS PARQUET
LOCATION 's3://bucket/hive/events/';

ANALYZE TABLE events PARTITION(dt) COMPUTE STATISTICS;

Spark SQL common functions:
- window, lead, lag, row_number, rank, dense_rank, collect_list, collect_set, explode, from_unixtime, unix_timestamp

KEY SPARK CONFIGS (frequently tuned)
- spark.executor.memory, spark.driver.memory
- spark.executor.cores
- spark.dynamicAllocation.enabled
- spark.sql.shuffle.partitions
- spark.memory.fraction, spark.memory.storageFraction
- spark.serializer = org.apache.spark.serializer.KryoSerializer
- spark.kryoserializer.buffer.max

COMMON PITFALLS & QUICK FIXES
- Too many small files —> compact, use coalesce/repartition before write.
- Skewed joins —> salting keys, broadcast smaller side, repartition by join key.
- OOM/GC —> reduce parallelism per executor, more smaller executors, tune memoryFraction, use off-heap storage.
- Late events in streaming —> set watermark and handle late data (side-output or append to late table).
- Consumer lag —> check offsets, scaling consumers, rebalance impacts; monitor consumer group lags.

DEBUGGING CHECKLIST
1. Check job logs (Spark driver/executor logs, Yarn logs).
2. Look at metrics: memory, GC, CPU, network, disk I/O.
3. Inspect data samples — schema mismatches, nulls, corrupt records.
4. Check shuffle / spill to disk.
5. Confirm partitioning and file sizes.
6. Reproduce locally with smaller dataset.
7. If streaming: check offsets, consumer group, checkpoint state, and Kafka retention.

TESTING STRATEGIES
- Unit test business logic (PyTest, ScalaTest).
- Integration tests against local Kafka (Testcontainers), HDFS/S3 mocks, embedded Hive or DuckDB for SQL.
- End-to-end with CI using smaller datasets.
- Use property-based testing for transformations (e.g., fast-check-like libs).

ARCHITECTURE PATTERNS
- Event sourcing with Kafka: use compacted topic for latest state, changelog streams.
- Lambda: batch + streaming store reconciled views and merge logic.
- Kappa: single stream pipeline + reprocessing for historical correction.
- CQRS: separate read/write patterns when write throughput and read queries differ.

RESOURCES & FURTHER READING
- Spark: "High Performance Spark" + Spark official docs
- Kafka: "Kafka: The Definitive Guide"
- Flink docs + "Streaming Systems" book
- Data engineering blogs: Confluent blog, Netflix tech, Uber engineering
- Apache projects docs: Hadoop, Hive, HBase, Presto/Trino, Cassandra

CHEAT SHEETS — quick pasteable snippets

Spark join strategy:
- If small table < broadcast threshold:
  df.join(broadcast(small_df), "id")
- For big joins:
  df.repartition("join_key").join(df2.repartition("join_key"), "join_key")

Detect small files and compact (spark):
```python
from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()
df = spark.read.parquet("s3://bucket/path/")
# coalesce to 1 file per partition (use with care)
df.repartition("year","month").write.mode("overwrite").partitionBy("year","month").parquet("s3://bucket/path_compacted/")
```

Kafka exactly-once producer (Java config):
- enable.idempotence=true
- acks=all
- transactional.id=my-transactional-id
- producer.initTransactions(), beginTransaction(), commitTransaction()

SAMPLE CHECKS (monitoring)
- Kafka: under-replicated partitions > 0? brokers disk usage > 80%? consumer lag trending upward?
- Spark: too many failed tasks? executor lost frequently? long GC times?

Wrap-up
- Automate small-file compaction and schema checks.
- Prefer Parquet/ORC for analytics, Avro for messaging with Schema Registry.
- Use streaming and event-time semantics carefully (watermarks and late arrivals).
- Measure and monitor everything (lag, retention, throughput, latencies).
- Keep security & governance baked in (encryption, RBAC, audit, lineage).

If you want, I can:
- Produce a printable 1–2 page PDF cheat-sheet for your team.
- Generate language-specific code snippets (Scala/Java/Python) for Spark and Flink.
- Create a starter repo with CI, sample Spark app, Dockerized Kafka + Schema Registry + example producer/consumer.

Which one would you like next?
