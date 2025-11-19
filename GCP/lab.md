# Comprehensive GCP Big Data Lab: Building an End-to-End Analytics Pipeline

This hands-on lab guides you through creating a complete big data pipeline on Google Cloud Platform (GCP). You'll ingest streaming data via Pub/Sub, process it with Dataflow for real-time analytics, store and query results in BigQuery, and optionally run a batch job on Dataproc. The scenario simulates processing e-commerce clickstream data (e.g., user events) to compute real-time metrics like top products viewed.

**Estimated Time:** 2-3 hours  
**Cost:** ~$5-10 (use Qwiklabs for free credits or enable billing; monitor via Billing console)  
**Level:** Intermediate (basic GCP/CLI knowledge assumed)

## Objectives
- Ingest streaming data into Pub/Sub.
- Build and deploy a Dataflow streaming pipeline using Apache Beam.
- Load and query processed data in BigQuery.
- (Optional) Run a Spark job on Dataproc for batch aggregation.
- Understand integration, monitoring, and cleanup.

## Prerequisites
1. **GCP Account:** Sign up at [cloud.google.com](https://cloud.google.com) with billing enabled (or use [Google Cloud Skills Boost](https://www.cloudskillsboost.google/) for free labs).
2. **Project Setup:** Create a new project (e.g., `bigdata-lab-project`). Enable APIs: BigQuery, Dataflow, Pub/Sub, Dataproc (via Console > APIs & Services > Library).
3. **Tools:** Install [gcloud CLI](https://cloud.google.com/sdk/docs/install), set default project (`gcloud config set project bigdata-lab-project`), and authenticate (`gcloud auth login`).
4. **Environment:** Local machine with Python 3.8+ for Dataflow (install Beam: `pip install apache-beam[gcp]==2.58.0` – check latest via `pip search apache-beam`).
5. **Quotas:** Ensure sufficient quotas (e.g., Dataflow workers: 10 vCPU; default is fine for this lab).

**Pro Tip:** Use the GCP Console for visuals; CLI for automation. All commands assume `us-central1` region – adjust as needed.

## Section 1: Data Ingestion with Pub/Sub (15 mins)
Pub/Sub decouples producers from consumers for scalable messaging.

### Steps:
1. **Create a Topic:**
   ```
   gcloud pubsub topics create ecommerce-events
   ```

2. **Create a Subscription (Pull Mode for Testing):**
   ```
   gcloud pubsub subscriptions create ecommerce-sub --topic=ecommerce-events
   ```

3. **Simulate Streaming Data:** Use a Python script to publish mock click events (JSON: `{ "user_id": "u123", "product": "laptop", "event": "view", "timestamp": "2025-11-18T10:00:00Z" }`). Save as `publish_events.py`:
   ```python
   from google.cloud import pubsub_v1
   import json
   import time
   import random

   project_id = "bigdata-lab-project"
   topic_id = "ecommerce-events"
   publisher = pubsub_v1.PublisherClient()
   topic_path = publisher.topic_path(project_id, topic_id)

   products = ["laptop", "phone", "tablet"]
   users = ["u" + str(i) for i in range(1, 101)]

   for _ in range(1000):  # Publish 1000 events
       event = {
           "user_id": random.choice(users),
           "product": random.choice(products),
           "event": "view",
           "timestamp": "2025-11-18T" + f"{random.randint(0,23):02d}:{random.randint(0,59):02d}:00Z"
       }
       future = publisher.publish(topic_path, json.dumps(event).encode("utf-8"))
       print(f"Published: {event['product']}")
       time.sleep(0.1)  # Simulate stream
   ```
   Run: `python publish_events.py`

4. **Verify:** Pull messages:
   ```
   gcloud pubsub subscriptions pull ecommerce-sub --limit=5 --auto-ack
   ```
   Expected: JSON events printed.

**Checkpoint:** You have a streaming topic with ~1000 events.

## Section 2: Streaming Processing with Dataflow (45 mins)
Dataflow runs Apache Beam pipelines for unified batch/stream processing. We'll count product views by user in real-time.

### Steps:
1. **Prepare Pipeline Code:** Save as `streaming_wordcount.py` (adapted from official Dataflow codelab):
   ```python
   import apache_beam as beam
   import json
   from apache_beam.options.pipeline_options import PipelineOptions, SetupOptions, StandardOptions

   class ParseEvent(beam.DoFn):
       def process(self, element):
           data = json.loads(element)
           yield beam.pvalue.TaggedOutput('output', (data['user_id'], data['product']))

   def run_pipeline(argv=None):
       pipeline_options = PipelineOptions(flags=argv)
       pipeline_options.view_as(SetupOptions).save_main_session = True
       pipeline_options.view_as(StandardOptions).streaming = True

       with beam.Pipeline(options=pipeline_options) as p:
           (p
            | 'Read Pub/Sub' >> beam.io.ReadFromPubSub(subscription='projects/bigdata-lab-project/subscriptions/ecommerce-sub')
            | 'Parse JSON' >> beam.ParDo(ParseEvent()).with_outputs('output', main='dropped')
            | 'Pair With One' >> beam.Map(lambda x: (x, 1))
            | 'Group By Key' >> beam.GroupByKey()
            | 'Sum Views' >> beam.Map(lambda x: {'user': x[0], 'product': x[1][0], 'views': sum(x[1][1])})
            | 'Write to BigQuery' >> beam.io.WriteToBigQuery(
                'bigdata-lab-project:bigdata_dataset.product_views',
                schema='user:STRING, product:STRING, views:INTEGER',
                create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED,
                write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND)
           )

   if __name__ == '__main__':
       run_pipeline()
   ```

2. **Create BigQuery Dataset (for Output):**
   ```
   bq mk --dataset bigdata-lab-project:bigdata_dataset
   ```

3. **Deploy Pipeline:**
   ```
   python streaming_wordcount.py \
     --runner=DataflowRunner \
     --project=bigdata-lab-project \
     --region=us-central1 \
     --subnetwork=default \
     --temp_location=gs://your-bucket/tmp/  # Create bucket first: gsutil mb gs://your-bucket
   ```
   Monitor in Console > Dataflow > Jobs (look for "streaming_wordcount").

4. **Run Publisher Again:** Execute `python publish_events.py` to trigger processing.

**Checkpoint:** Pipeline graph shows in Console; events flow to BigQuery (query later).

## Section 3: Analytics and Querying with BigQuery (30 mins)
BigQuery is a serverless data warehouse for SQL analytics on petabyte-scale data.

### Steps:
1. **Load Sample Data (if needed for batch testing):** Use public dataset for baseline.
   ```
   bq load --source_format=NEWLINE_DELIMITED_JSON bigdata_dataset.sample_clicks gs://cloud-training-demos/labs/dataproc-wordcount/input/shakespeare/kinglear.txt  # Adapt to JSON
   ```
   (For our case, Dataflow loads directly.)

2. **Query Processed Data:** In Console > BigQuery or CLI:
   ```
   bq query --use_legacy_sql=false "
   SELECT user, product, SUM(views) as total_views
   FROM \`bigdata-lab-project.bigdata_dataset.product_views\`
   GROUP BY user, product
   ORDER BY total_views DESC
   LIMIT 10"
   ```
   Expected: Top 10 user-product views.

3. **Advanced: Partition and Cluster Table** (Optimize for queries; from codelab):
   - Edit table schema in Console: Add partition by `timestamp` (if added to schema).
   - Run: `bq show --format=prettyjson bigdata_dataset.product_views`

4. **Visualize:** Connect to Looker Studio (free): Create report from BigQuery table for dashboard.

**Checkpoint:** Query returns aggregated views; execution time <1s.

## Section 4: (Optional) Batch Processing with Dataproc (30 mins)
Dataproc manages Spark/Hadoop clusters for cost-effective batch jobs.

### Steps:
1. **Create Cluster:**
   ```
   gcloud dataproc clusters create bigdata-cluster \
     --region=us-central1 \
     --master-machine-type=n1-standard-2 \
     --num-workers=2 \
     --worker-machine-type=n1-standard-2 \
     --image-version=2.0-debian10
   ```

2. **Submit Spark Job:** Save aggregation script as `aggregate_views.py`:
   ```python
   from pyspark.sql import SparkSession
   from pyspark.sql.functions import sum as spark_sum

   spark = SparkSession.builder.appName("AggregateViews").getOrCreate()
   df = spark.read.format("bigquery").option("table", "bigdata-lab-project:bigdata_dataset.product_views").load()
   df.groupBy("product").agg(spark_sum("views").alias("total")).write.format("bigquery").option("table", "bigdata-lab-project:bigdata_dataset.aggregated_products").mode("overwrite").save()
   spark.stop()
   ```
   Submit:
   ```
   gcloud dataproc jobs submit pyspark aggregate_views.py \
     --cluster=bigdata-cluster \
     --region=us-central1 \
     --properties=spark.sql.catalogImplementation=in-memory
   ```
   (Requires BigQuery connector JAR in cluster init – add via `--jars=gs://hadoop-lib/gcs/hadoop3-3.3.1.jar` if needed.)

3. **Query Results:**
   ```
   bq query "SELECT * FROM \`bigdata-lab-project.bigdata_dataset.aggregated_products\` ORDER BY total DESC"
   ```

4. **Delete Cluster:** (To save costs)
   ```
   gcloud dataproc clusters delete bigdata-cluster --region=us-central1
   ```

**Checkpoint:** Aggregated table created; top products listed.

## Monitoring and Best Practices
- **Logging/Monitoring:** View in Console > Operations > Logging. Set alerts for Dataflow errors.
- **Costs:** Use preemptible VMs in Dataproc; streaming slots in BigQuery.
- **Security:** Assign IAM roles (e.g., Pub/Sub Publisher to your account).
- **Scaling:** Dataflow autoscales; test with more events.
- **Troubleshooting:** Check quotas, regions match, bucket exists.

## Cleanup (5 mins)
Prevent charges:
```
gcloud pubsub topics delete ecommerce-events
gcloud pubsub subscriptions delete ecommerce-sub
gcloud dataflow jobs cancel JOB_ID --region=us-central1  # From console
bq rm -r bigdata_dataset
gsutil rm -r gs://your-bucket/
```
(Optional) Delete project.

## Next Steps
- Explore full codelabs: [Dataflow Text Processing](https://codelabs.developers.google.com/codelabs/cloud-dataflow-starter), [BigQuery Wikipedia Queries](https://codelabs.developers.google.com/codelabs/cloud-bigquery-wikipedia), [Dataproc Basics](https://codelabs.developers.google.com/codelabs/cloud-dataproc-gcloud).
- Enroll in [Data Engineering Learning Path](https://cloud.google.com/learn/training/data-engineering-and-analytics) for more labs.

This lab demonstrates a production-like pipeline. Adapt for your data! Questions? Check [GCP Docs](https://cloud.google.com/bigquery/docs).
