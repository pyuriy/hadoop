# Comprehensive Big Data Development Lab

## Overview

This lab is a hands-on, modular course that teaches core big-data development skills: ingestion, serialization, batch and stream processing, storage formats, query, orchestration, and monitoring. It uses a local Docker-based environment so you can run everything on a single workstation or VM.

## Intended audience

- Software/data engineers who want practical, end-to-end experience building big-data pipelines.
- Prerequisites: basic Linux command-line, Python, Docker & Docker Compose, Java (for Spark if running locally), familiarity with SQL and programming.

## Learning objectives

By the end of the lab you will be able to:

- Stand up a local reproducible big-data stack (Kafka, Schema Registry, MinIO, Postgres, Jupyter/PySpark).
- Produce/consume messages with Kafka and manage schema using Avro + Schema Registry.
- Implement Spark Structured Streaming jobs with exactly-once semantics.
- Build batch ETL pipelines in Spark, write optimal Parquet/partitioned datasets.
- Use Jupyter notebooks for exploratory analysis and validation.
- Connect streaming/batch results to downstream systems (Postgres/MinIO).
- Apply performance and operational best practices (partitioning, compaction, monitoring basics).

## Contents

- Quick start (10–20 minutes)
- Lab modules (8 modules, ~1–4 hours each)
- Datasets (download links and pre-canned samples)
- Verification & Solutions outline
- Infrastructure: docker-compose and how to extend
- Troubleshooting & tips
- Rubric & assessment tasks
- References

## Quick start (local)

1. Install Docker and Docker Compose.
2. Clone the lab repo or copy the docker-compose file (provided in this lab).
3. Run: docker compose up -d
4. Open Jupyter: http://localhost:8888 (token printed by container logs)

```bash
$docker logs lab-jupyter-1 |grep token
```

5. Start following Module 1 in the notebook or terminal.

## Provided components

- Zookeeper + Kafka (broker)
- Confluent Schema Registry (Avro schemas)
- MinIO (S3-compatible object store)
- Postgres (relational sink)
- Jupyter (PySpark-enabled notebook for development)
- Optional: tools and connectors you add (Kafka Connect, Trino, Prometheus)

## Datasets (suggested)

- NYC Taxi trip records (sample subset) — https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Airline on-time performance (sample) — Bureau of Transportation Statistics
- Web server logs / simulated clickstream (small generator included in labs)
- Synthetic user profile table for lookups

## Module breakdown (recommended pacing)

### Module 0 — Environment setup and intro (30–60 min)

- Start Docker Compose, open Jupyter, validate connectivity to Kafka and MinIO
- Exercises: list Kafka topics, upload file to MinIO via mc or UI

### Module 1 — Ingestion: Kafka fundamentals (1–2 hrs)

#### Goals:

- Create topics, produce messages, consume messages
- Observe partitions, replication, consumer groups

#### Tasks

- Create topic "events" with 6 partitions, RF=1 (dev)
- Start a console producer and send JSON messages
- Start a console consumer (from beginning)
- Observe partition assignment and offsets

#### Commands (examples)

- Create topic:

```bash
  kafka-topics --bootstrap-server localhost:9092 --create --topic events --partitions 6 --replication-factor 1
```

- Console producer:
  
```bash
  kafka-console-producer --broker-list localhost:9092 --topic events
```

- Console consumer:

```bash
  kafka-console-consumer --bootstrap-server localhost:9092 --topic events --from-beginning
```

#### Verification

- Produce 10 messages, consume 10 messages, confirm offsets increment.

### Module 2 — Schemas & Serialization: Avro + Schema Registry (1–2 hrs)

#### Goals

- Register an Avro schema in Schema Registry and produce Avro-encoded messages
- Understand schema compatibility settings

*Tasks*

- Register "user_event" Avro schema
- Produce Avro messages via a small Python script using confluent-kafka
- Change schema (add optional field) and test compatibility (BACKWARD, FORWARD, FULL)

Hints
- Use the Schema Registry REST API to POST schemas
- Use confluent_kafka.avro.AvroProducer in Python (or confluent-kafka + avro lib)

Verification
- Consumer can decode Avro messages using the same Schema Registry subject.

Module 3 — Streaming: Spark Structured Streaming (2–4 hrs)
Goals
- Build a Structured Streaming job that reads Kafka, parses Avro/JSON, enriches with lookup data, writes to Parquet (in MinIO) and Postgres (sink)
- Use checkpointing and idempotent writes

Tasks
- Create a PySpark Structured Streaming notebook:
  - Read from Kafka topic "events" (bootstrap-server localhost:9092)
  - Parse the value (Avro or JSON)
  - Join against a static dataset (user-profiles) loaded from MinIO or local
  - Aggregate with event-time windows + watermark
  - Write output to MinIO in Parquet (partitioned by dt) and to Postgres via JDBC (upserts)
  - Use checkpointLocation on MinIO for fault tolerance

Key code snippets (PySpark)
- Read from Kafka:
  df = spark.readStream.format("kafka") \
      .option("kafka.bootstrap.servers","kafka:9092") \
      .option("subscribe","events") \
      .option("startingOffsets","earliest") \
      .load()
- Parse JSON:
  from pyspark.sql.functions import from_json, col
  schema = "id STRING, user_id STRING, event_type STRING, event_time TIMESTAMP"
  df2 = df.select(from_json(col("value").cast("string"), schema).alias("data")).select("data.*")
- Watermark + window:
  df2.withWatermark("event_time", "10 minutes") \
     .groupBy(window("event_time","5 minutes"), "event_type").count()

Exactly-once considerations
- Use Kafka source + idempotent sink (e.g., use JDBC upserts, or write to a transactional sink)
- Use checkpointing and a stable checkpoint store (MinIO path)

Verification
- Start a producer, send events with event_time across windows, observe aggregated Parquet files being written partitioned by dt.

Module 4 — Batch ETL: Spark Batch and Parquet layout (2–4 hrs)
Goals
- Transform raw event parquet into analytical tables, partition, and optimize file sizes
- Implement compaction

Tasks
- Read raw events in MinIO (Parquet)
- Create fact and dimension tables
- Partition fact by year/month/day
- Repartition/coalesce to achieve 128MB-ish files
- Run ANALYZE TABLE (if using Hive metastore) or compute statistics for query engines

Best practices
- Choose partition keys used by filters
- Avoid high-cardinality partition columns
- Compact small files (coalesce) as a periodic job

Module 5 — Delta/ACID/Upserts (optional advanced, 2–4 hrs)
Goals
- Use Delta Lake or Hudi for ACID upserts over Parquet on MinIO

Tasks
- Set up delta-spark package in Spark (within notebook)
- Implement a streaming upsert pattern: read stream, merge into Delta table, validate idempotency

Module 6 — Sink connectors: Kafka Connect to Postgres (1–2 hrs)
Goals
- Use Kafka Connect to sink aggregated results to Postgres

Tasks
- Start Kafka Connect (standalone) or use the Debezium/Confluent images
- Configure a JDBC sink connector for the topic produced by Spark
- Validate data in Postgres

Module 7 — Observability & Testing (1–2 hrs)
Goals
- Instrument metrics and logs for Spark and Kafka
- Add unit tests and integration test strategy

Tasks
- Expose JMX metrics and read via Jupyter (or Prometheus if added)
- Implement pytest for transformation functions (pure functions)
- Use Testcontainers or Docker-based integration tests to run Kafka and Spark jobs in CI

Module 8 — Performance & Troubleshooting workshop (2–4 hrs)
Goals
- Diagnose skew, small files, OOM, consumer lag
- Apply tuning changes and measure improvement

Exercises
- Create a skewed dataset, run join, observe stragglers; fix with salting or broadcast.
- Simulate small-file problem, build compaction pipeline.
- Simulate late data and test watermark + late events handling.

Assessment tasks / Capstone (2–6 hrs)
Build an end-to-end pipeline:
- Ingest clickstream events to Kafka
- Enforce schema with Schema Registry
- Stream-process events with Spark to generate per-user daily summaries
- Write summaries to Parquet in MinIO (partitioned by date) and to Postgres for fast lookup
- Provide a Jupyter notebook that answers analytics questions (top users by activity, time-series charts)
- Submit a short README describing design choices, how you ensured correctness (exactly-once/idempotency), and how you would scale to production.

Rubric
- Correctness (40%): pipeline produces correct results, tests pass
- Resilience (20%): checkpointing and recoverability demonstrated
- Performance (20%): partitioning/compaction and reasonable file sizes
- Documentation & reproducibility (20%): clear instructions, Docker compose, notebooks

Verification & solutions outline
- Each module contains expected outputs (e.g., topic exists, messages consumed, Parquet files in path).
- Solutions include sample Jupyter notebooks and PySpark scripts with comments.
- For exercise verification, include small sample datasets and expected row counts and sample rows.

Extending the lab
- Add Trino/Presto for federated SQL
- Add Flink module for stream-first patterns
- Add Prometheus + Grafana for full observability
- Add Kubernetes manifests to run labs on k8s clusters
- Replace MinIO with real S3 for cloud labs

Troubleshooting tips (common issues)
- Kafka broker not reachable: check advertised listeners and Docker network
- Spark job OOM: reduce executor memory, increase partitions, use Kryo serializer
- Small files: coalesce/repartition before write; schedule compaction jobs
- Schema mismatch: check Schema Registry subject versions and compatibility settings

References & resources
- Spark docs: https://spark.apache.org/docs/latest/
- Kafka docs: https://kafka.apache.org/documentation/
- Confluent Schema Registry: https://docs.confluent.io/platform/current/schema-registry/index.html
- Delta Lake: https://delta.io/
- MinIO docs: https://docs.min.io/

What's next
- We can do the follwoing:
  - The [docker-compose.yml](./docker-compose.yml) to run the local lab environment,
  - A starter Jupyter [notebook](./starter_lab_modules_1-3_notebook.ipynb) (PySpark) for Modules 1–3 with runnable cells,
  - A sample PySpark Structured [streaming app](./streaming_app.py) ready to submit with spark-submit.

It's ready-to-run Jupyter [notebook](./starter_lab_modules_1-3_notebook.ipynb) that implements the starter lab for Modules 1–3 (Kafka basics, schema/serialization notes, and a Spark Structured Streaming example). The notebook includes cells to install needed packages, create a Kafka topic, produce/consume JSON test messages, and run a PySpark Structured Streaming job that reads from Kafka, aggregates with event-time windows + watermark, and writes Parquet output locally (with checkpoints). It also contains notes and optional snippets for Schema Registry/Avro and MinIO configuration.

You can run this notebook inside the jupyter/pyspark-notebook container from the lab docker-compose (open at http://localhost:8888). Run cells top-to-bottom. If you want Avro + Schema Registry or direct S3A/MinIO Parquet writes enabled in the notebook, I can add those cells and dependency instructions next.

A production-minded PySpark [streaming app](./streaming_app.py) that you can run with spark-submit. It reads JSON events from Kafka, performs event-time windowed aggregation with watermarking, and writes Parquet output with checkpointing; it also has optional S3A/MinIO configuration injectable via CLI flags or environment variables. Next, you can run this with spark-submit (I included a sample command in the file header), and if you'd like I can: provide a ready-made spark-submit invocation tailored for the Docker Compose lab (including --packages for hadoop-aws and aws SDK jars), add Avro + Schema Registry decoding support, or produce a companion Docker/Spark config with the jars preloaded. Which of those should I produce next?
