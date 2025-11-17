#!/usr/bin/env python3
"""
streaming_app.py

A sample PySpark Structured Streaming application that:
- Reads JSON messages from Kafka
- Parses event payloads and casts event_time to timestamp
- Performs event-time windowed aggregation with watermarking
- Writes aggregated results to Parquet (local path or S3/MinIO via s3a)
- Uses checkpointing for fault tolerance
- Exposes simple graceful shutdown and configurable parameters via env/args

Usage (example):
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --packages org.apache.hadoop:hadoop-aws:3.3.4,org.apache.hadoop:hadoop-common:3.3.4 \
  streaming_app.py \
  --kafka-bootstrap kafka:9092 \
  --topic events \
  --output-path s3a://my-bucket/stream_output/ \
  --checkpoint-path s3a://my-bucket/checkpoints/events/ \
  --window-duration 5 minutes \
  --watermark 10 minutes

Notes:
- To write to S3/MinIO, ensure hadoop-aws and required AWS SDK jars are on Spark classpath (use --packages or add jars).
- For MinIO, set environment variables or pass --s3-endpoint, --s3-access-key, --s3-secret-key and enable path style access.
"""

import argparse
import os
import signal
import sys
import logging
from pyspark.sql import SparkSession
from pyspark.sql.functions import from_json, col, window, to_timestamp
from pyspark.sql.types import StructType, StringType, DoubleType

# Setup logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("streaming_app")

def build_spark(app_name="streaming_app", s3_conf=None, extra_conf=None):
    builder = SparkSession.builder.appName(app_name)
    # Recommended: set serializer and other common confs
    builder = builder.config("spark.serializer", "org.apache.spark.serializer.KryoSerializer")
    builder = builder.config("spark.sql.shuffle.partitions", "200")
    # Apply s3/minio hadoop conf by injecting into JVM hadoop configuration after session creation
    spark = builder.getOrCreate()

    if s3_conf:
        hconf = spark._jsc.hadoopConfiguration()
        hconf.set("fs.s3a.endpoint", s3_conf.get("endpoint"))
        hconf.set("fs.s3a.access.key", s3_conf.get("access_key"))
        hconf.set("fs.s3a.secret.key", s3_conf.get("secret_key"))
        # path style for MinIO
        if s3_conf.get("path_style", "true").lower() == "true":
            hconf.set("fs.s3a.path.style.access", "true")
        # disable SSL if needed
        if s3_conf.get("use_ssl", "false").lower() == "false":
            hconf.set("fs.s3a.connection.ssl.enabled", "false")
        # recommended tuning for s3a
        hconf.set("fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        # If using MinIO without AWS credentials provider chain
        hconf.set("fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
        logger.info("Configured S3A/MinIO settings into Spark hadoopConfiguration")

    if extra_conf:
        for k, v in extra_conf.items():
            spark.conf.set(k, v)

    return spark

def parse_args():
    p = argparse.ArgumentParser(description="PySpark Structured Streaming sample app")
    p.add_argument("--kafka-bootstrap", required=True, help="Kafka bootstrap servers, e.g. kafka:9092")
    p.add_argument("--topic", default="events", help="Kafka topic to subscribe")
    p.add_argument("--output-path", required=True, help="Parquet output path (local or s3a URI)")
    p.add_argument("--checkpoint-path", required=True, help="Checkpoint directory (local or s3a URI)")
    p.add_argument("--window-duration", default="5 minutes", help="Window duration, e.g. '5 minutes'")
    p.add_argument("--watermark", default="10 minutes", help="Watermark duration, e.g. '10 minutes'")
    p.add_argument("--starting-offsets", default="earliest", choices=["earliest", "latest"], help="Kafka starting offsets")
    # S3/MinIO settings (optional)
    p.add_argument("--s3-endpoint", default=None, help="S3A endpoint (e.g. http://minio:9000)")
    p.add_argument("--s3-access-key", default=None, help="S3 access key")
    p.add_argument("--s3-secret-key", default=None, help="S3 secret key")
    p.add_argument("--s3-path-style", default="true", help="Use path style access for S3A (true/false)")
    return p.parse_args()

def main():
    args = parse_args()

    s3_conf = None
    if args.s3_endpoint:
        # Normalize endpoint without scheme for hadoop config when needed
        endpoint = args.s3_endpoint
        # Keep scheme if provided (hadoop accepts http://host:port)
        s3_conf = {
            "endpoint": endpoint,
            "access_key": args.s3_access_key or os.getenv("S3_ACCESS_KEY"),
            "secret_key": args.s3_secret_key or os.getenv("S3_SECRET_KEY"),
            "path_style": args.s3_path_style,
            "use_ssl": "false" if endpoint.startswith("http://") else "true"
        }

    spark = build_spark(s3_conf=s3_conf)

    # Define JSON schema for events
    schema = StructType() \
        .add("id", StringType()) \
        .add("user_id", StringType()) \
        .add("event_type", StringType()) \
        .add("event_time", StringType()) \
        .add("value", DoubleType())

    kafka_df = (
        spark.readStream.format("kafka")
        .option("kafka.bootstrap.servers", args.kafka_bootstrap)
        .option("subscribe", args.topic)
        .option("startingOffsets", args.starting_offsets)
        .load()
    )

    # Parse JSON value
    json_df = kafka_df.select(from_json(col("value").cast("string"), schema).alias("data")).select("data.*")
    # cast event_time to proper timestamp; adjust format if needed
    events = json_df.withColumn("event_time", to_timestamp(col("event_time")))

    # Aggregation: count per event_type per tumbling window
    agg = (
        events.withWatermark("event_time", args.watermark)
        .groupBy(window(col("event_time"), args.window_duration), col("event_type"))
        .count()
        .selectExpr("window.start as window_start", "window.end as window_end", "event_type", "count")
    )

    # Write to Parquet (append mode). Spark will create partition directories if path includes partition cols.
    query = (
        agg.writeStream
        .format("parquet")
        .outputMode("append")
        .option("path", args.output_path)
        .option("checkpointLocation", args.checkpoint_path)
        .trigger(processingTime="30 seconds")
        .start()
    )

    # Graceful shutdown handling
    def stop_gracefully(signum, frame):
        logger.info("Received signal %s. Stopping streaming query...", signum)
        try:
            query.stop()
            logger.info("Query stopped.")
        except Exception as e:
            logger.exception("Error stopping query: %s", e)
        finally:
            spark.stop()
            logger.info("Spark session stopped. Exiting.")
            sys.exit(0)

    signal.signal(signal.SIGINT, stop_gracefully)
    signal.signal(signal.SIGTERM, stop_gracefully)

    logger.info("Streaming query started. Awaiting termination...")
    query.awaitTermination()

if __name__ == "__main__":
    main()