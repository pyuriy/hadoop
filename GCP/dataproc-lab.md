# Comprehensive Hands-On Lab: Managing Dataproc Clusters on GCP

This hands-on lab guides you through provisioning, using, and managing Apache Hadoop/Spark clusters with Google Cloud Dataproc. Dataproc is a fully managed service that automates cluster creation, scaling, and maintenance, allowing you to focus on data processing. You'll create clusters of different types, submit batch jobs (Spark and PySpark), resize dynamically, interact via SSH, and monitor performance. By the end, you'll have practical experience with Dataproc for big data workloads.

**Estimated Time:** 1-2 hours  
**Cost:** ~$2-5 (use a small cluster; monitor in Billing console. Free tier/Qwiklabs eligible)  
**Level:** Beginner to Intermediate (basic CLI knowledge assumed)  
**Date Context:** As of November 18, 2025, use Dataproc image version 2.3 (default for premium tier clusters).

## Objectives
- Enable required APIs and set up your environment.
- Create standard, single-node, and high-availability (HA) clusters using gcloud CLI.
- Submit and monitor Spark and PySpark jobs.
- Resize clusters and enable autoscaling.
- SSH into the cluster for interactive exploration (e.g., Hive queries).
- Clean up resources to avoid costs.

## Prerequisites
1. **GCP Account:** A project with billing enabled (create at [console.cloud.google.com](https://console.cloud.google.com)). Use [Google Cloud Skills Boost](https://www.cloudskillsboost.google/) for free credits.
2. **APIs Enabled:** In Console > APIs & Services > Library, enable:
   - Cloud Dataproc API
   - Compute Engine API
3. **Tools:** 
   - [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated (`gcloud auth login`).
   - Set project: `gcloud config set project YOUR_PROJECT_ID`.
   - Optional: Python 3.8+ for PySpark (install `pip install pyspark` locally for testing).
4. **Quotas:** Default quotas suffice; check Compute Engine > Quotas if needed.
5. **Bucket:** Create a GCS bucket for job files: `gsutil mb gs://your-bucket-dplab/`.

**Pro Tip:** Use Cloud Shell (in Console) for all commands—it's pre-configured. Set default region/zone: `gcloud config set compute/zone us-central1-f` and `gcloud config set dataproc/region us-central1`.

## Section 1: Environment Setup (5 mins)
Verify your setup to ensure smooth execution.

### Steps:
1. Open Cloud Shell in the Console.
2. Authenticate and set project:
   ```
   gcloud auth list
   gcloud config list project  # Should show YOUR_PROJECT_ID
   ```
   If not set: `gcloud config set project YOUR_PROJECT_ID`.
3. Set environment variables:
   ```
   export PROJECT_ID=YOUR_PROJECT_ID
   export REGION=us-central1
   export CLUSTER_NAME=${USER}-dplab-cluster  # Unique name, e.g., john-dplab-cluster
   export BUCKET=gs://your-bucket-dplab/
   echo $CLUSTER_NAME  # Verify
   ```

**Checkpoint:** Commands run without errors; variables echo correctly.

## Section 2: Creating Dataproc Clusters (20 mins)
Dataproc supports standard (multi-node), single-node (dev/testing), and HA clusters. We'll create each type using gcloud CLI, with optional flags for optimization.

### 2.1 Create a Standard Cluster (Multi-Node)
Default: 1 master + 2 workers. Use preemptible workers for cost savings (~80% off).

```
gcloud dataproc clusters create $CLUSTER_NAME-standard \
  --region=$REGION \
  --image-version=2.3-debian10 \  # Latest as of Nov 2025
  --master-machine-type=n1-standard-2 \
  --num-workers=2 \
  --worker-machine-type=n1-standard-2 \
  --num-preemptible-workers=1 \  # Cost-optimized
  --scopes=cloud-platform \  # Full access for jobs
  --properties=spark:spark.jars=gs://spark-lib/bigquery/spark-bigquery-latest.jar  # Optional: BigQuery connector
```
- Monitor: `gcloud dataproc clusters describe $CLUSTER_NAME-standard --region=$REGION` (wait for "RUNNING").

### 2.2 Create a Single-Node Cluster (Dev/Testing)
No workers; master handles everything. Ideal for quick iterations.

```
gcloud dataproc clusters create $CLUSTER_NAME-single \
  --region=$REGION \
  --num-workers=0 \  # Single-node mode
  --image-version=2.3-debian10 \
  --master-machine-type=n1-standard-4  # More CPU for solo processing
```
- Verify: `gcloud dataproc clusters list --region=$REGION` (shows 0 workers).

### 2.3 Create a High-Availability (HA) Cluster
Multiple masters for failover (requires Zookeeper).

```
gcloud dataproc clusters create $CLUSTER_NAME-ha \
  --region=$REGION \
  --image-version=2.3-debian10 \
  --master-machine-type=n1-standard-2 \
  --num-secondary-masters=2 \  # 3 total masters
  --num-workers=3 \
  --enable-component-gateway  # UI access
```
- Note: HA adds resilience but increases cost.

**Checkpoint:** List clusters: `gcloud dataproc clusters list --region=$REGION`. All should be "RUNNING". Use Console > Dataproc > Clusters for visuals.

## Section 3: Submitting Jobs to Your Cluster (30 mins)
Submit batch jobs via gcloud. We'll use the standard cluster; adapt for others.

### 3.1 Submit a Built-in Spark Job (SparkPi Estimation)
Estimates Pi using Monte Carlo simulation—no custom code needed.

```
gcloud dataproc jobs submit spark \
  --cluster=$CLUSTER_NAME-standard \
  --region=$REGION \
  --class=org.apache.spark.examples.SparkPi \
  --jars=file:///usr/lib/spark/examples/jars/spark-examples_2.12-3.5.0.jar \  # Built-in JAR
  -- 1000  # Iterations
```
- Monitor: `gcloud dataproc jobs list --cluster=$CLUSTER_NAME-standard --region=$REGION`.
- Wait: `gcloud dataproc jobs wait JOB_ID --region=$REGION` (get ID from list).
- Output: In Console > Dataproc > Jobs > Select job > Logs (look for Pi ≈ 3.14).

### 3.2 Submit a PySpark Job (Word Count on Shakespeare)
Upload a sample script to GCS, then submit.

1. Create `wordcount.py` locally (or in Cloud Shell):
   ```python
   import sys
   from pyspark.sql import SparkSession

   spark = SparkSession.builder.appName("WordCount").getOrCreate()
   input_path = sys.argv[1] if len(sys.argv) > 1 else "gs://dataproc-readonly/us-states.json"  # Sample input
   output_path = sys.argv[2] if len(sys.argv) > 2 else "gs://$PROJECT_ID/wordcount-output"

   df = spark.read.json(input_path)
   words = df.select("name").rdd.flatMap(lambda row: row[0].split()).map(lambda word: (word, 1))
   counts = words.reduceByKey(lambda a, b: a + b)
   counts.saveAsTextFile(output_path)
   spark.stop()
   ```
   - Adapt input: Use `gs://dataflow-samples/shakespeare/kinglear.txt` for text.

2. Upload: `gsutil cp wordcount.py $BUCKET`.

3. Submit:
   ```
   gcloud dataproc jobs submit pyspark \
     --cluster=$CLUSTER_NAME-standard \
     --region=$REGION \
     $BUCKET/wordcount.py \
     -- --input=gs://dataflow-samples/shakespeare/kinglear.txt --output=$BUCKET/wordcount-output
   ```
- Results: `gsutil cat $BUCKET/wordcount-output/part-00000*` (shows word counts).

### 3.3 Submit a Hive Job (SQL Query)
For interactive querying on GCS data.

```
gcloud dataproc jobs submit hive \
  --cluster=$CLUSTER_NAME-standard \
  --region=$REGION \
  --execute-hive-statement="SHOW TABLES"
```
- For custom: `--hive-interactive` or use Beeline via SSH (Section 5).

**Checkpoint:** Jobs complete successfully; outputs verifiable in GCS/Logs.

## Section 4: Resizing and Autoscaling (10 mins)
Dataproc supports dynamic scaling for efficiency.

### Steps:
1. Resize (add workers):
   ```
   gcloud dataproc clusters update $CLUSTER_NAME-standard \
     --region=$REGION \
     --num-workers=4  # From 2 to 4
   ```
   - Verify: `gcloud dataproc clusters describe $CLUSTER_NAME-standard --region=$REGION`.

2. Enable Autoscaling:
   - Create policy: `gcloud dataproc autoscaling-policies create basic-policy --region=$REGION --max-secondary-worker-count=10`.
   - Apply: `gcloud dataproc clusters update $CLUSTER_NAME-standard --region=$REGION --autoscaling-policy=basic-policy`.
   - Test: Submit a heavy job; watch workers scale in Console.

**Checkpoint:** Cluster description shows updated node counts.

## Section 5: Interactive Exploration via SSH (10 mins)
Access the master for ad-hoc work.

### Steps:
1. SSH to master:
   ```
   gcloud compute ssh $CLUSTER_NAME-standard-m \
     --zone=us-central1-f --region=$REGION
   ```
   - Inside: Run `spark-shell` for interactive Spark or `beeline -u jdbc:hive2://` for Hive.
   - Example Hive query: `beeline -u jdbc:hive2://localhost:10000 --execute="CREATE TABLE IF NOT EXISTS test (id INT); SHOW TABLES;"`.

2. Exit: `exit` or `logout`.

**Pro Tip:** Use `--tunnel-through-iap` for secure access.

**Checkpoint:** Successfully connected; ran a simple command.

## Section 6: Monitoring and Troubleshooting (5 mins)
- **Console:** Dataproc > Clusters/Jobs for metrics (CPU, HDFS usage).
- **CLI:** `gcloud dataproc jobs describe JOB_ID --region=$REGION` for logs.
- **Advanced:** Integrate Cloud Monitoring; set alerts for job failures.
- Common Issues: Region mismatch (fix with `--region`), quota exceeded (request increase).

**Checkpoint:** View live metrics in Console.

## Cleanup (5 mins)
Delete to stop billing:
```
gcloud dataproc clusters delete $CLUSTER_NAME-standard $CLUSTER_NAME-single $CLUSTER_NAME-ha --region=$REGION
gsutil rm -r $BUCKET  # Remove outputs
```
- Verify: `gcloud dataproc clusters list --region=$REGION` (empty).

## Next Steps
- Advanced: Explore Dataproc Serverless for job-only execution (no cluster management).
- Codelabs: Try [Provisioning with gcloud](https://codelabs.developers.google.com/codelabs/cloud-dataproc-gcloud) or [CDC with Pub/Sub](https://codelabs.developers.google.com/cdc-using-dataproc-cloud-pubsub).
- Docs: [Submit Jobs](https://cloud.google.com/dataproc/docs/guides/submit-job).

This lab builds foundational skills—experiment with your data next! Questions? Check [Dataproc Docs](https://cloud.google.com/dataproc/docs).
