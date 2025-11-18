# Comprehensive Confluent Kafka Hands-On Lab

Nice confluent kafaka [lab](https://docs.confluent.io/platform/current/get-started/platform-quickstart.html#quickstart)

Welcome to this comprehensive hands-on lab for Confluent Platform 8.1 (released with Apache Kafka 4.1 as of November 2025). This lab guides you through setting up a local development environment, exploring core Kafka features, and integrating Confluent's value-added components like Schema Registry, Kafka Connect, and ksqlDB. By the end, you'll have practical experience with streaming data pipelines.

**Estimated Time**: 2-3 hours  
**Level**: Intermediate (basic command-line and JSON familiarity assumed)  
**Goals**:

- Install and run a local Confluent cluster.
- Perform basic producer/consumer operations.
- Manage schemas for data evolution.
- Ingest/export data with Connect.
- Process streams with ksqlDB.
- Monitor via Control Center.

For full reference, see [Confluent Docs](https://docs.confluent.io/platform/current/overview.html). All commands assume a Unix-like shell (macOS/Linux); adapt for Windows.

## Prerequisites

- Docker & Docker Compose (v20+)
- 8GB+ RAM (for local cluster)
- Java 11+ (for any custom apps, optional)
- Optional: VS Code or IDE for editing configs/JSON.

## Part 1: Installation - Local Cluster Setup
We'll use Docker Compose for a single-node cluster including Zookeeper (for simplicity; KRaft is advanced), Kafka, Schema Registry, Connect, ksqlDB, and Control Center. This mirrors production but scaled down.

### Step 1.1: Create Project Directory
```bash
mkdir confluent-kafka-lab
cd confluent-kafka-lab
```

### Step 1.2: Docker Compose File
Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:8.1.0
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000

  kafka:
    image: confluentinc/cp-kafka:8.1.0
    hostname: kafka
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "9093:9093"  # For external access if needed
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_JMX_PORT: 9991
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka:29092
      CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'false'
      CONFLUENT_SUPPORT_CUSTOMER_ID: anonymous

  schema-registry:
    image: confluentinc/cp-schema-registry:8.1.0
    hostname: schema-registry
    container_name: schema-registry
    depends_on:
      - kafka
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'kafka:29092'
      SCHEMA_REGISTRY_KAFKASTORE_CONNECTION_URL: 'zookeeper:2181'

  kafka-connect:
    image: confluentinc/cp-kafka-connect:8.1.0
    hostname: connect
    container_name: kafka-connect
    depends_on:
      - kafka
      - schema-registry
    ports:
      - "8083:8083"
    environment:
      CONNECT_BOOTSTRAP_SERVERS: 'kafka:29092'
      CONNECT_REST_ADVERTISED_HOST_NAME: connect
      CONNECT_GROUP_ID: connect-cluster
      CONNECT_CONFIG_STORAGE_TOPIC: _connect-configs
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_OFFSET_FLUSH_INTERVAL_MS: 10000
      CONNECT_OFFSET_STORAGE_TOPIC: _connect-offsets
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_STATUS_STORAGE_TOPIC: _connect-status
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_VALUE_CONVERTER: io.confluent.connect.avro.AvroConverter
      CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONNECT_INTERNAL_KEY_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_INTERNAL_VALUE_CONVERTER: org.apache.kafka.connect.json.JsonConverter
      CONNECT_REST_ADVERTISED_LISTENERS: http://localhost:8083
      CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components"
      CONNECT_CONFIG_STORAGE_PARTITION: 0
      CONNECT_OFFSET_STORAGE_PARTITION: 0
      CONNECT_STATUS_STORAGE_PARTITION: 0
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka:29092
      CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'false'
      CONFLUENT_SUPPORT_CUSTOMER_ID: anonymous

  ksqldb-server:
    image: confluentinc/cp-ksqldb-server:8.1.0
    hostname: ksqldb-server
    container_name: ksql-server
    depends_on:
      - kafka
      - schema-registry
    ports:
      - "8088:8088"
    environment:
      KSQL_LISTENERS: http://0.0.0.0:8088
      KSQL_BOOTSTRAP_SERVERS: 'kafka:29092'
      KSQL_HOST_NAME: ksqldb-server
      KSQL_LOGGING_STREAMED_LOG_TOPICS: _confluent-ksql-default_log
      KSQL_STREAMS_AUTO_OFFSET_RESET: earliest
      KSQL_CACHE_MAX_BYTES_BUFFERING: 50000000
      KSQL_QUERY_APPLICATION_ID: ksql_sandbox
      KSQL_PERSISTENT_QUERY: 'true'
      KSQL_SERVICE_ID: default_
      KSQL_SINK_NUMBERED_KEY_NAME: KSQL_INTERNAL_ROWKEY
      KSQL_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONNECT_BOOTSTRAP_SERVERS: 'kafka:29092'
      CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka:29092
      CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'false'
      CONFLUENT_SUPPORT_CUSTOMER_ID: anonymous

  ksqldb-cli:
    image: confluentinc/cp-ksqldb-cli:8.1.0
    container_name: ksql-cli
    depends_on:
      - ksqldb-server
    entrypoint: /usr/bin/ksql
    volumes:
      - ./scripts:/opt/scripts  # Optional for custom scripts
    environment:
      KSQLDB_SERVER_URL: http://ksqldb-server:8088
      KSQLDB_CLI_HEADLESS: "true"

  control-center:
    image: confluentinc/cp-enterprise-control-center:8.1.0
    hostname: control-center
    container_name: control-center
    depends_on:
      - kafka
      - schema-registry
      - kafka-connect
      - ksqldb-server
    ports:
      - "9021:9021"
    environment:
      CONTROL_CENTER_BOOTSTRAP_SERVERS: 'kafka:29092'
      CONTROL_CENTER_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      CONTROL_CENTER_ADVERTISED_LISTENER: http://localhost:9021
      CONTROL_CENTER_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONTROL_CENTER_CONNECT_CLUSTER: connect
      CONTROL_CENTER_KSQL_URL: http://ksqldb-server:8088
      CONTROL_CENTER_KSQL_STREAMS_URL: http://ksqldb-server:8088
      CONTROL_CENTER_INTERNAL_TOPICS_REPLICATION_FACTOR: 1
      CONTROL_CENTER_METRICS_REPORTER_BOOTSTRAP_SERVERS: kafka:29092
      CONTROL_CENTER_METRICS_REPORTER_TOPIC_REPLICAS: 1
      CONFLUENT_METRICS_ENABLE: 'false'
      CONFLUENT_SUPPORT_CUSTOMER_ID: anonymous
      # Note: Enterprise license needed for full features; use trial key if available
```

**Note**: This uses Community Edition images. For Enterprise (e.g., advanced Control Center), add a license via env var `CONTROL_CENTER_LICENSE=your-license-key`.

### Step 1.3: Start the Cluster
```bash
docker-compose up -d
```
Wait 1-2 minutes for services to initialize.

### Step 1.4: Verify Setup
```bash
# Check logs
docker-compose logs kafka

# List topics (should show internal ones like __consumer_offsets)
docker run --rm --network confluent-kafka-lab_default confluentinc/cp-kafka:8.1.0 kafka-topics --bootstrap-server kafka:29092 --list

# Access Control Center
open http://localhost:9021  # Or visit in browser
```
- In Control Center, navigate to **Cluster Overview** to confirm all components are green.

**Checkpoint**: If issues, check Docker logs for errors (e.g., port conflicts).

## Part 2: Basic Kafka Operations
Work with topics, producers, and consumers using Kafka CLI tools.

### Step 2.1: Create and Describe a Topic
```bash
# Exec into Kafka container for CLI access
docker exec -it kafka kafka-topics --create --topic orders --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --config retention.ms=86400000 --config cleanup.policy=delete

# Describe
docker exec -it kafka kafka-topics --describe --topic orders --bootstrap-server localhost:9092
```
- Output shows 3 partitions, leader/follower assignments.

### Step 2.2: Produce Messages
```bash
# Console producer (type messages like {"order_id":1,"item":"book"}, Ctrl+C to exit)
docker exec -it kafka kafka-console-producer --topic orders --bootstrap-server localhost:9092 --property parse.key=true --property key.separator=:
```
Sample input:
```
1:{"order_id":1,"item":"book","price":10.99}
2:{"order_id":2,"item":"laptop","price":999.99}
```

### Step 2.3: Consume Messages
Terminal 1 (produce more if needed), Terminal 2:
```bash
# Consume from beginning
docker exec -it kafka kafka-console-consumer --topic orders --from-beginning --bootstrap-server localhost:9092 --property print.key=true --property key.separator=:
```
- See ordered messages by key (partitioning demo).

### Step 2.4: Consumer Groups
```bash
# Create group and consume (lag simulation)
docker exec -it kafka kafka-console-consumer --topic orders --from-beginning --bootstrap-server localhost:9092 --group lab-group --property print.key=true --property key.separator=:

# Describe group (check offsets/lag)
docker exec -it kafka kafka-consumer-groups --bootstrap-server localhost:9092 --group lab-group --describe
```
- Run multiple consumers in parallel to see rebalancing.

**Checkpoint**: Verify in Control Center > **Topics > orders** for message count and consumer lag.

## Part 3: Schema Registry - Data with Schemas
Schemas ensure type-safe evolution (e.g., Avro format).

### Step 3.1: Register a Schema
Create `order-value.avsc`:
```json
{
  "type": "record",
  "name": "Order",
  "fields": [
    {"name": "order_id", "type": "int"},
    {"name": "item", "type": "string"},
    {"name": "price", "type": "float"}
  ]
}
```
Register:
```bash
# Copy file to container (or use curl)
docker cp order-value.avsc kafka:/tmp/

# Register via curl from host
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data-binary @order-value.avsc \
  http://localhost:8081/subjects/orders-value/versions

# List subjects
curl http://localhost:8081/subjects
```
- Schema ID (e.g., 1) is returned.

### Step 3.2: Produce with Schema
Use Avro console producer (requires schema):
```bash
# Produce Avro (keys as string)
docker exec -it kafka kafka-avro-console-producer --topic orders --bootstrap-server localhost:9092 \
  --property schema.registry.url=http://schema-registry:8081 \
  --property value.schema='{"type":"record","name":"Order","fields":[{"name":"order_id","type":"int"},{"name":"item","type":"string"},{"name":"price","type":"float"}]}'
```
Input (JSON-like):
```
{"order_id": 3, "item": "phone", "price": 599.99}
```

### Step 3.3: Consume with Schema
```bash
docker exec -it kafka kafka-avro-console-consumer --topic orders --from-beginning --bootstrap-server localhost:9092 \
  --property schema.registry.url=http://schema-registry:8081 --property print.key=true
```
- See deserialized JSON.

**Checkpoint**: In Control Center > **Schema Registry**, view the `orders-value` subject and compatibility (default: BACKWARD).

**Exercise**: Evolve schema by adding a field (e.g., "quantity": "int") and re-register (POST to /versions). Produce compatible data and observe.

## Part 4: Kafka Connect - Data Integration
Connect streams data in/out of Kafka (source/sink).

### Step 4.1: File Source Connector
Create `file-source.json`:
```json
{
  "name": "file-source",
  "config": {
    "connector.class": "FileStreamSource",
    "file": "/tmp/input.txt",
    "topic": "orders-raw",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "key.converter.schemas.enable": "false",
    "value.converter.schemas.enable": "false"
  }
}
```
Add sample data: `echo '{"order_id":4,"item":"tablet"}' > input.txt` (on host; copy to container if needed).

Deploy:
```bash
# Copy config
docker cp file-source.json kafka-connect:/tmp/

# POST connector
curl -X POST -H "Content-Type: application/json" --data @file-source.json http://localhost:8083/connectors

# List
curl http://localhost:8083/connectors
```

### Step 4.2: JDBC Sink Connector (Simulated)
For a real DB, use PostgreSQL, but here simulate with console sink or S3 (requires AWS creds). Instead, use a JSON sink to another topic.

Create `json-sink.json`:
```json
{
  "name": "json-sink",
  "config": {
    "connector.class": "io.confluent.connect.replicator.ReplicatorSourceConnector",  # Or use FileSink for simplicity
    "topics": "orders-raw",
    "target.topic": "orders-processed",
    "key.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter"
  }
}
```
Deploy similarly.

### Step 4.3: Verify
```bash
# Consume sink topic
docker exec -it kafka kafka-console-consumer --topic orders-processed --from-beginning --bootstrap-server localhost:9092
```
- See data flowing through.

**Checkpoint**: Control Center > **Connect > Connectors** shows status/running tasks. Pause/resume via UI.

**Exercise**: Install a hub connector (e.g., `confluent-hub install confluentinc/kafka-connect-jdbc:latest`) inside Connect container and configure a real sink.

## Part 5: ksqlDB - Stream Processing
SQL for Kafka streams/tables.

### Step 5.1: Access ksqlDB CLI
```bash
# Run CLI (interactive)
docker run --rm --network confluent-kafka-lab_default -i confluentinc/cp-ksqldb-cli:8.1.0 ksql --host ksqldb-server:8088

# Or exec: docker exec -it ksql-server ksql-server-start /etc/ksql-server/ksql-server.properties -d  # But use CLI
```
In CLI (`ksql>` prompt):

### Step 5.2: Create Stream from Topic
```sql
-- Create stream (use JSON for simplicity)
CREATE STREAM orders_stream (order_id INT, item STRING, price DOUBLE) 
WITH (KAFKA_TOPIC='orders', VALUE_FORMAT='JSON', KEY='order_id');

-- List streams
SHOW STREAMS;

-- Query (real-time)
SELECT * FROM orders_stream EMIT CHANGES LIMIT 5;
```
- Produces new messages to see live output.

### Step 5.3: Create Table & Aggregate
```sql
-- Table for aggregations
CREATE TABLE orders_by_item AS 
SELECT item, COUNT(*) AS order_count, AVG(price) AS avg_price 
FROM orders_stream 
GROUP BY item 
EMIT CHANGES;

-- Query table
SELECT * FROM orders_by_item EMIT CHANGES;
```

### Step 5.4: Insert & Push Query
```sql
-- Insert (produces to topic)
INSERT INTO orders_stream (order_id, item, price) VALUES (5, 'headphones', 49.99);

-- Persistent query (runs in background)
RUN SCRIPT '/path/to/query.sql';  # Or use CREATE STREAM AS SELECT for joins
```

Exit CLI with `exit;`.

**Checkpoint**: Control Center > **ksqlDB > Queries** shows running queries. Terminate via `TERMINATE query_id;`.

**Exercise**: Join two streams (create another topic/stream) or use windowed aggregations (e.g., tumbling windows).

## Part 6: Monitoring & Cleanup
### Step 6.1: Explore Control Center
- **Topics**: Inspect partitions, retention, compaction.
- **Consumers**: View lag, rebalances.
- **Schema Registry**: Compatibility rules.
- **Connect**: Task metrics.
- **ksqlDB**: Query health.
- Set alerts (Enterprise) or export metrics.

### Step 6.2: Performance Check
```bash
# Consumer lag
docker exec -it kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group connect-cluster

# JMX (optional: use jconsole or Prometheus)
```

### Step 6.3: Cleanup
```bash
# Stop cluster
docker-compose down -v  # -v removes volumes

# Delete topics (if testing)
docker exec -it kafka kafka-topics --delete --topic orders --bootstrap-server localhost:9092
```

## Next Steps & Extensions
- **Advanced**: Enable KRaft (Zookeeper-free): Update configs with `process.roles=broker,controller`.
- **Security**: Add SASL/SSL (see cheatsheet).
- **Scaling**: Multi-broker setup; deploy to Kubernetes via Confluent Operator.
- **Cloud**: Migrate to Confluent Cloud (free tier available).
- **Troubleshooting**: Common issues in Part 10 of cheatsheet.

Congratulations! You've built a full streaming pipeline. Fork this repo, experiment, and share your queries on X (@ConfluentInc). Questions? Ask for extensions!
