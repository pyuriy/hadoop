# GCP Big Data Cheatsheet

This cheatsheet covers key Google Cloud Platform (GCP) services for big data processing, analytics, and storage. It focuses on core concepts, features, and common CLI commands (using `gcloud`, `bq`, `gsutil`, etc.). For the latest details, refer to official docs. Assumes basic GCP setup (project enabled, APIs activated).

## Services Overview

| Service          | Purpose | Key Use Cases | Integration |
|------------------|---------|---------------|-------------|
| **BigQuery**    | Serverless data warehouse for analytics | SQL queries on petabyte-scale data, ML integration, BI dashboards | Dataflow for ingestion, Pub/Sub for streaming, Storage for raw data |
| **Dataflow**    | Managed stream/batch processing | ETL pipelines, real-time analytics, data transformation | Beam SDK, Pub/Sub input, BigQuery/Storage output |
| **Dataproc**    | Managed Hadoop/Spark clusters | Batch processing, Spark jobs, Hive queries | Cloud Storage for input/output, BigQuery connector |
| **Pub/Sub**     | Asynchronous messaging | Event-driven architectures, streaming ingestion | Dataflow for processing, BigQuery for loading |
| **Data Fusion** | No-code ETL platform | Visual pipeline building, data integration | Connects to Storage, BigQuery, on-prem sources |
| **Cloud Storage (GCS)** | Scalable object storage | Data lakes, raw data landing zone | Serves as input/output for all services |

## BigQuery

**Overview**: Fully managed, serverless data warehouse with AI-ready features. Supports SQL queries on structured/unstructured data (e.g., Iceberg, Delta formats). Separates storage (columnar, ACID-compliant) from compute for scalability. Handles TBs in seconds, PBs in minutes.

**Key Features**:
- ANSI SQL with joins, window functions, geospatial/ML (BigQuery ML).
- Federated queries to external sources (GCS, Bigtable).
- Governance via Dataplex (catalog, lineage).
- BI Engine for sub-second queries in tools like Looker/Tableau.

**Data Types**: Standard (STRING, INT64, FLOAT64), nested/repeated (ARRAY, STRUCT), geospatial (GEOGRAPHY).

**CLI Examples** (using `bq` tool):
| Operation | Command |
|-----------|---------|
| Create dataset | `bq mk --dataset --location=US myproject:mydataset` |
| Load CSV to table | `bq load --source_format=CSV mydataset.mytable gs://bucket/file.csv schema.json` |
| Run query | `bq query --nouse_legacy_sql 'SELECT COUNT(*) FROM mydataset.mytable'` |
| Create table | `bq mk --table mydataset.mytable` |
| Export to GCS | `bq extract --destination_format=CSV mydataset.mytable gs://bucket/export/*.csv` |

## Dataflow

**Overview**: Fully managed service for unified batch/streaming pipelines using Apache Beam SDK. Handles autoscaling, fault tolerance, and exactly-once processing.

**Key Concepts**:
- **Pipeline**: Directed graph of PTransforms (e.g., ParDo for custom logic).
- **Transforms**: Read (from Pub/Sub/GCS), process (Map, GroupByKey), write (to BigQuery).
- Supported: Java, Python, Go, Scala.

**Example: Simple Streaming Word Count Pipeline** (Python/Beam):
1. Install: `pip install apache-beam[gcp]`.
2. Code snippet (core logic):
   ```python
   import apache_beam as beam

   with beam.Pipeline() as pipeline:
       lines = pipeline | beam.io.ReadFromText('gs://dataflow-samples/shakespeare/kinglear.txt')
       counts = (lines
                 | beam.FlatMap(lambda line: line.split())
                 | 'PairWithOne' >> beam.Map(lambda x: (x, 1))
                 | 'GroupAndSum' >> beam.CombinePerKey(sum)
                 | beam.io.WriteToText('gs://BUCKET/output'))
   ```
3. Deploy (CLI via Python runner):
   ```
   python -m apache_beam.examples.wordcount_example \
     --runner=DataflowRunner \
     --project=myproject \
     --region=us-central1 \
     --input=gs://dataflow-samples/shakespeare/kinglear.txt \
     --output=gs://mybucket/results \
     --temp_location=gs://mybucket/tmp/
   ```

## Dataproc

**Overview**: Managed Spark/Hadoop service for running clusters on-demand. Automates provisioning, scaling, and deletion to minimize costs. Supports ephemeral clusters for jobs.

**Key Concepts**:
- **Cluster Types**: Single-node (testing), Standard (multi-master/worker), High Availability (Zookeeper for failover).
- Configurations: Machine types, preemptible VMs for cost savings, autoscaling policies.

**CLI Examples** (using `gcloud dataproc`):
| Operation | Command |
|-----------|---------|
| Create standard cluster | `gcloud dataproc clusters create my-cluster --region=us-central1 --num-workers=2 --master-machine-type=n1-standard-2` |
| Create single-node cluster | `gcloud dataproc clusters create my-cluster --region=us-central1 --single-node --master-machine-type=n1-standard-4` |
| Submit Spark job | `gcloud dataproc jobs submit pyspark gs://mybucket/script.py --cluster=my-cluster --region=us-central1 -- --arg1=value` |
| Submit Hadoop job | `gcloud dataproc jobs submit hadoop gs://mybucket/jar.jar --cluster=my-cluster --region=us-central1` |
| Delete cluster | `gcloud dataproc clusters delete my-cluster --region=us-central1` |

## Pub/Sub

**Overview**: Scalable, real-time messaging for decoupling apps. Publishers send to topics; subscribers pull/push from subscriptions. Supports at-least-once delivery, dead-letter queues.

**Key Concepts**:
- **Topics**: Message channels.
- **Subscriptions**: Pull (client polls) or push (server delivers to HTTP endpoint).
- Latencies: ~100ms; scales to millions of messages/sec.

**CLI Examples** (using `gcloud pubsub`):
| Operation | Command |
|-----------|---------|
| Create topic | `gcloud pubsub topics create my-topic` |
| Create pull subscription | `gcloud pubsub subscriptions create my-sub --topic=my-topic` |
| Create push subscription | `gcloud pubsub subscriptions create my-sub --topic=my-topic --push-endpoint=https://example.com/push` |
| Publish message | `gcloud pubsub topics publish my-topic --message="Hello, world!"` |
| Pull messages | `gcloud pubsub subscriptions pull my-sub --auto-ack` |

## Data Fusion

**Overview**: Fully managed, code-free data integration service based on CDAP. Builds ETL/ELT pipelines visually for batch/real-time data movement.

**Key Components**:
- **Instances**: Managed environments (control plane for UI, data plane for execution).
- **Pipelines**: DAGs of nodes (sources, transforms, sinks).
- **Plugins**: Extensible (e.g., BigQuery sink, GCS source).
- Execution: Uses Dataproc clusters; supports previews and triggers.

**Pipeline Creation Overview**:
1. Create instance: Via console (`gcloud datafusion instances create my-instance --location=us-central1`).
2. In Studio UI: Drag nodes (e.g., GCS source → Transform → BigQuery sink).
3. Preview: Test on sample data.
4. Deploy: Schedule or trigger; configure compute profile (e.g., Spark resources).

## Cloud Storage (GCS)

**Overview**: Durable object storage for unstructured data (up to 5TB/object). Classes: Standard (hot), Nearline (infrequent), Coldline (archive). Supports versioning, lifecycle rules for big data lakes.

**Key gsutil Commands** (for big data workflows):
| Command | Description | Example |
|---------|-------------|---------|
| `cp` | Copy/upload files | `gsutil cp localfile gs://bucket/folder/` |
| `rsync` | Sync directories | `gsutil rsync -d localdir gs://bucket/folder/` |
| `ls` | List objects | `gsutil ls gs://bucket/**` |
| `rm` | Delete objects | `gsutil rm gs://bucket/object` |
| `acl get/set` | Manage access | `gsutil acl ch -u AllUsers:R gs://bucket/object` (public read) |
| `versioning set` | Enable versioning | `gsutil versioning set on gs://bucket` |
| `lifecycle set` | Auto-delete old versions | `gsutil lifecycle set config.json gs://bucket` |

## Architecture & Best Practices

**Typical Big Data Pipeline**:
1. **Ingestion**: Pub/Sub for streams → GCS for batch landing.
2. **Processing**: Dataflow for transformations → Dataproc for Spark ML.
3. **Storage/Analysis**: GCS data lake → BigQuery for queries.
4. **Orchestration**: Cloud Composer (Airflow) for workflows; Data Fusion for ETL.
5. **Monitoring**: Cloud Monitoring/Logging; Dataplex for governance.

**Best Practices**:
- Use columnar formats (Parquet/Avro) in GCS for efficiency.
- Partition/cluster BigQuery tables by common filters.
- Enable autoscaling in Dataflow/Dataproc for cost control.
- Secure with IAM roles (e.g., BigQuery Data Editor).
- Cost: Query only needed data; use reservations/slots for predictable workloads.

For hands-on, start with BigQuery sandbox (no billing). Refer to [GCP Big Data Analytics](https://cloud.google.com/architecture/big-data-analytics) for diagrams.
