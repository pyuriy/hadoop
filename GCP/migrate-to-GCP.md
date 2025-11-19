# Migrating Hadoop to Google Cloud Platform (GCP)

Migrating on-premises or cloud-hosted Hadoop ecosystems to GCP allows organizations to leverage managed services like Dataproc for Apache Hadoop and Spark, Cloud Storage for scalable object storage, and BigQuery for analytics. This reduces operational overhead, improves elasticity, and cuts costs—often by 50% or more through features like preemptible VMs and autoscaling. Recent incentives include migration credits and tools to accelerate the process. This guide outlines a structured approach, drawing from official GCP documentation and real-world experiences.

## Migration Decision Tree
Before diving in, use this decision tree to select the right GCP services based on your workloads. It evaluates common Hadoop use cases to decide between lift-and-shift to Dataproc, refactoring to serverless options, or hybrids.

1. **Do you have NoSQL workloads?**
   - If using HBase with co-processors or SQL via Phoenix: Migrate to Dataproc for compatibility.
   - If no co-processors or SQL needed: Refactor to Bigtable for a fully managed NoSQL database.

2. **Are you processing streaming data?**
   - If using Apache Beam: Shift to Dataflow for unified streaming/batch processing.
   - If using Spark Streaming or Kafka: Migrate to Dataproc with GCP integrations.

3. **Are you doing interactive data analysis or ad hoc querying?**
   - If using Spark with notebooks (e.g., Jupyter or Zeppelin): Use Dataproc for interactive clusters.
   - If using SQL with Hive or Presto and want to retain it: Migrate to Dataproc.
   - If seeking a managed SQL solution: Refactor to BigQuery for serverless querying.

4. **Are you doing ETL or batch processing?**
   - If running ETL/batch with MapReduce, Pig, Spark, or Hive: Lift-and-shift to Dataproc.
   - If using orchestration like Apache Airflow or Oozie without changes: Migrate to Dataproc.
   - If preferring managed orchestration: Use Cloud Composer (managed Airflow).

For simple lift-and-shift, copy data to Cloud Storage, update HDFS paths to `gs://` URIs, and submit jobs to Dataproc clusters.

## Planning and Assessment
1. **Inventory Workloads**: Catalog jobs (MapReduce, Spark, Hive), data volumes, dependencies (e.g., custom JARs), and SLAs. Identify candidates for lift-and-shift vs. modernization (e.g., Spark to Dataflow).
2. **Benchmark Performance and Costs**: Compare on-premises baselines against GCP using trial Dataproc clusters. Factor in fixed on-prem capacity vs. cloud pay-as-you-go. Aim for cost-neutral migration initially, then optimize.
3. **Team and Tooling Prep**: Train on GCP; build self-service Terraform modules for cluster provisioning. Anticipate quota increases for IPs, VMs, and nodes.
4. **Security and Compliance**: Map IAM roles to GCP primitives; enable VPC Service Controls for data isolation.

**Pro Tip**: Start with small, non-critical workloads to build momentum.

## Data Migration: From HDFS to Cloud Storage
Hadoop Distributed File System (HDFS) data must move to Cloud Storage (GCS), which is HDFS-compatible via the `gs://` connector. Use Storage Transfer Service for agent-based transfers to handle large-scale, secure migrations. Note: Metadata like permissions isn't preserved; plan for post-migration ACLs.

### Steps:
1. **Configure Permissions**:
   - Grant roles to your user, the Google-managed service account (`project-PROJECT_NUMBER@storage-transfer-service.iam.gserviceaccount.com`), and transfer agent account: `roles/storage.admin`, `roles/storage.objectAdmin`, and HDFS access (e.g., Kerberos if enabled).

2. **Install Agents into a Pool**:
   - Create a pool in the Console (Storage Transfer Service > Agent pools > Create).
   - Install agents (e.g., 3-5 for redundancy) on machines with HDFS access:
     - **Console**: Select pool > Install agent > Follow OS-specific instructions (Linux/Windows).
     - **gcloud CLI**: `gcloud transfer agents install --pool=AGENT_POOL --count=3 --hdfs-namenode-uri=hdfs://namenode:8020` (add Kerberos flags if needed).
     - **Docker**: `docker run gcr.io/cloud-ingest/storage-transfer-agent --pool=AGENT_POOL --hdfs-namenode-uri=...`.
   - Agents need access to namenode, datanodes, KMS, and KDC.

3. **Create and Run Transfer Job**:
   - **Console**: Storage Transfer Service > Create transfer job > Source: HDFS > Destination: GCS bucket > Select agent pool, HDFS path (e.g., `hdfs:///user/data/`), filters (e.g., `*.avro`), schedule, and options (overwrite, delete source).
   - **gcloud CLI**: `gcloud transfer jobs create hdfs:///data/path/ gs://my-bucket/output/ --source-agent-pool=AGENT_POOL --overwrite-objects=true`.
   - Monitor via Console or `gcloud transfer jobs describe JOB_ID`.

**Considerations**: For multi-namenode setups, reinstall agents if the primary changes. Test with subsets; transfers are resumable.

## Workload Migration: Jobs to Dataproc
Dataproc provides fully managed Hadoop/Spark clusters with 99.9% uptime SLA, ephemeral provisioning, and seamless GCS integration.

### Steps:
1. **Create a Dataproc Cluster**:
   ```
   gcloud dataproc clusters create my-cluster \
     --region=us-central1 \
     --master-machine-type=n1-standard-4 \
     --num-workers=4 \
     --worker-machine-type=n1-standard-2 \
     --image-version=2.1-debian10 \
     --enable-component-gateway  # For UI access
   ```

2. **Adapt and Submit Jobs**:
   - Update input/output paths: Replace `hdfs://` with `gs://`.
   - Upload custom JARs/scripts to GCS.
   - Submit: `gcloud dataproc jobs submit pyspark gs://bucket/my-spark-job.py --cluster=my-cluster --region=us-central1 -- --input=gs://bucket/input/ --output=gs://bucket/output/`.
   - For Hive: Use `--hive-interactive` or connect via Beeline.

3. **Scale and Optimize**:
   - Enable autoscaling: `--autoscaling-policy=policy-id` (create via `gcloud dataproc autoscaling-policies create`).
   - Use preemptible workers for 80% cost savings: `--num-preemptible-workers=2`.

4. **Delete Cluster**: `gcloud dataproc clusters delete my-cluster --region=us-central1` (ephemeral for cost control).

**Considerations**: Test for GCS connector compatibility; use workflow templates for Oozie/Airflow equivalents.

## Migrating Hive Managed Tables to BigQuery
For analytics workloads, migrate Hive tables to BigQuery via the Data Transfer Service connector, which handles schema extraction, data transfer, and incremental updates.

### Steps:
1. **Generate Hive Metadata**: Run the `dwh-migration-dumper` tool on your cluster to create `hive-dumper-output.zip` in a GCS bucket.

2. **Enable APIs and Permissions**:
   - Enable Data Transfer and Storage Transfer APIs.
   - Create a service account with `roles/bigquery.admin`.
   - Grant the service agent roles like `roles/storagetransfer.admin`, `roles/storage.objectAdmin`.

3. **Set Up Transfer Agent (for HDFS)**: Install Docker on agent machines, create a pool, and install agents as in data migration.

4. **(For S3 Storage)**: Configure AWS credentials and IP allowlists.

5. **Schedule Transfer**:
   - **Console**: BigQuery > Data transfers > Create transfer > Source: Hive Managed Tables > Specify patterns (e.g., `db1.*`), metadata ZIP path, metastore (Dataproc Metastore or BigLake), destination GCS/BigQuery.
   - **bq CLI**: `bq mk --transfer_config --data_source=hadoop --params='{"table_name_pattern": "db1.*", "metadata_gcs_path": "gs://bucket/hive-dumper-output.zip", ...}' --location=US`.
   - Options: Incremental (daily), translation output for schema mapping.

6. **Monitor**: Use `bq transfer show` or `dwh-dts-status` tool from GitHub.

**Considerations**: Minimum 24-hour schedule; supports Iceberg tables via BigLake. For one-time: Set `end_time`.

## Best Practices
- **Decentralize Ownership**: Empower teams with self-service clusters via Terraform to improve agility and attribution.
- **Persistent Data in GCS**: Avoid HDFS; use GCS for decoupling storage from compute.
- **Autoscaling Everywhere**: Scale clusters dynamically; target <15-min create/delete times.
- **Prioritize Migration**: Start with preemptible-compatible jobs; combine with Spark upgrades.
- **Benchmark and Monitor**: Use Datadog or Cloud Monitoring; balance CUDs with preemptibles.
- **Integrate Deeply**: Leverage GCP-native features like custom VMs; track product maturity (e.g., wait for GA).

## Case Studies and Costs
- **Squarespace**: Migrated self-hosted Hadoop to Dataproc/BigQuery, gaining elasticity and reducing ops.
- **Otto Group**: "Evaporated" their data lake to GCP, saving costs and boosting performance.
- **Choreograph (WPP)**: 50% cost drop post-Hadoop to Dataproc migration.

**Cost Tips**: Use preemptibles (80% off), CUDs (up to 57% off), and migration credits. Estimate via Pricing Calculator; monitor with Billing exports to BigQuery.

## Next Steps
- Hands-on: Try the Dataproc codelab.
- Consult: Engage GCP Migration Center for assessments.
- Resources: [Dataproc Migration Guide](https://cloud.google.com/dataproc/docs/guides/migrate), [BigQuery Migration](https://cloud.google.com/bigquery/docs/migration-intro).

This migration can be phased over weeks to months—start small, iterate, and scale!
