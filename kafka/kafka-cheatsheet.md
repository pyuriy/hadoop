# Confluent Kafka Cheatsheet

This cheatsheet covers core Apache Kafka concepts enhanced by Confluent Platform features (as of late 2025). Confluent builds on Kafka with tools like Schema Registry, Kafka Connect, ksqlDB, and Control Center. Assumes basic familiarity with Kafka; focus is on practical commands and configs. For full docs, see [Confluent Documentation](https://docs.confluent.io/).

## 1. Installation & Setup
### Quick Start (Local Cluster)
```bash
# Download & start Confluent Platform (Community Edition)
curl -O https://packages.confluent.io/archive/7.7/confluent-7.7.0.tar.gz  # Update version as needed
tar -xzf confluent-7.7.0.tar.gz
cd confluent-7.7.0
export CONFLUENT_HOME=$PWD

# Start services (Zookeeper, Kafka, Schema Registry, Connect, ksqlDB, Control Center)
bin/confluent local services start

# Verify
bin/confluent local services status
```

### Docker Compose (Production-like)
Use Confluent's official images:
```yaml
# docker-compose.yml
version: '3'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.7.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
  kafka:
    image: confluentinc/cp-kafka:7.7.0
    depends_on: [zookeeper]
    ports: ["9092:9092"]
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
  schema-registry:
    image: confluentinc/cp-schema-registry:7.7.0
    depends_on: [kafka]
    ports: ["8081:8081"]
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
```
```bash
docker-compose up -d
```

## 2. Core Kafka Concepts
| Concept | Description | Key Properties |
|---------|-------------|----------------|
| **Topic** | Logical channel for messages. | Partitions (for parallelism), Replication Factor (durability, default 1). |
| **Partition** | Ordered, immutable log of messages. | Leader (handles reads/writes), Followers (replicas). |
| **Producer** | Publishes messages to topics. | Key (for partitioning), Value, Headers. |
| **Consumer** | Subscribes to topics/partitions. | Group ID (for load balancing), Offset (position in log). |
| **Broker** | Kafka server handling storage/traffic. | Cluster-wide coordination via Zookeeper/KRaft (Kafka 3.3+). |

KRAFT - Kafka RAFT
RAFT stands for Replicated Agreement for Fault Tolerance.

### Creating/Deleting Topics
```bash
# Create topic
kafka-topics --create --topic my-topic --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1

# List topics
kafka-topics --list --bootstrap-server localhost:9092

# Describe topic
kafka-topics --describe --topic my-topic --bootstrap-server localhost:9092

# Delete topic (requires delete.topic.enable=true in broker config)
kafka-topics --delete --topic my-topic --bootstrap-server localhost:9092
```

## 3. Producers & Consumers
### Producer (Java Example)
```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("key.serializer", "org.apache.kafka.common.serialization.StringSerializer");
props.put("value.serializer", "io.confluent.kafka.serializers.KafkaJsonSerializer");  // Confluent JSON
props.put("schema.registry.url", "http://localhost:8081");  // For Schema Registry

KafkaProducer<String, Object> producer = new KafkaProducer<>(props);
producer.send(new ProducerRecord<>("my-topic", "key", payload));
producer.close();
```

### Consumer (Java Example)
```java
Properties props = new Properties();
props.put("bootstrap.servers", "localhost:9092");
props.put("group.id", "my-group");
props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
props.put("value.deserializer", "io.confluent.kafka.serializers.KafkaJsonDeserializer");
props.put("schema.registry.url", "http://localhost:8081");
props.put("specific.avro.reader", "true");  // For Avro

KafkaConsumer<String, Object> consumer = new KafkaConsumer<>(props);
consumer.subscribe(Collections.singletonList("my-topic"));
while (true) {
    ConsumerRecords<String, Object> records = consumer.poll(Duration.ofMillis(100));
    for (ConsumerRecord<String, Object> record : records) {
        System.out.printf("Key: %s, Value: %s%n", record.key(), record.value());
    }
    consumer.commitSync();  // Manual commit
}
```

### Console Tools
```bash
# Produce messages
kafka-console-producer --topic my-topic --bootstrap-server localhost:9092 --property "parse.key=true" --property "key.separator=:" 

# Consume messages
kafka-console-consumer --topic my-topic --from-beginning --bootstrap-server localhost:9092 --property "print.key=true" --property "key.separator=:"
```

## 4. Schema Registry
Manages Avro/JSON/Protobuf schemas for data evolution.

### Commands
```bash
# Start Schema Registry (if not running)
confluent local services schema-registry start  # Local
# Or via Docker as above

# Register schema (from file)
curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data-binary @schema.avsc \
  http://localhost:8081/subjects/my-topic-value/v1/versions

# List subjects
curl -X GET http://localhost:8081/subjects

# Get latest schema
curl -X GET http://localhost:8081/subjects/my-topic-value/versions/latest

# Delete subject (irreversible)
curl -X DELETE http://localhost:8081/subjects/my-topic-value
```

### Config (schema-registry.properties)
```
listeners=http://0.0.0.0:8081
kafkastore.bootstrap.servers=localhost:9092
kafkastore.topic=_schemas
```

## 5. Kafka Connect
Framework for streaming data integration (sources/sinks).

### Start Connect
```bash
# Local mode
confluent local services connect start

# Distributed mode (configs in connect-distributed.properties)
connect-distributed start ../etc/kafka/connect-distributed.properties
```

### Connectors
| Type | Example | Config Snippet |
|------|---------|----------------|
| **File Source** | Ingest from file. | `name=file-source`<br>`connector.class=FileStreamSource`<br>`file=./input.txt`<br>`topic=my-topic` |
| **JDBC Sink** | Write to DB. | `name=jdbc-sink`<br>`connector.class=io.confluent.connect.jdbc.JdbcSinkConnector`<br>`topics=my-topic`<br>`connection.url=jdbc:postgresql://localhost:5432/db` |
| **S3 Sink** | Export to S3. | `name=s3-sink`<br>`connector.class=io.confluent.connect.s3.S3SinkConnector`<br>`topics=my-topic`<br>`s3.bucket.name=my-bucket`<br>`format.class=io.confluent.connect.s3.format.json.JsonFormat` |

### Manage Connectors
```bash
# POST new connector (JSON payload)
curl -X POST -H "Content-Type: application/json" --data @connector.json http://localhost:8083/connectors

# List connectors
curl -X GET http://localhost:8083/connectors

# Delete
curl -X DELETE http://localhost:8083/connectors/file-source

# Status
curl -X GET http://localhost:8083/connectors/file-source/status
```

## 6. ksqlDB (Stream Processing)
SQL-like engine for Kafka streams/tables.

### Start ksqlDB
```bash
confluent local services ksql-server start  # Local
# Or Docker: confluentinc/cp-ksqldb-server:7.7.0 on port 8088
```

### Basic Queries (via ksql CLI: `ksql>`)
```sql
-- Create stream from topic
CREATE STREAM my_stream (id INT, name STRING) 
WITH (KAFKA_TOPIC='my-topic', VALUE_FORMAT='JSON');

-- Create table (aggregated view)
CREATE TABLE user_counts AS 
SELECT USERID, COUNT(*) AS cnt 
FROM my_stream 
GROUP BY USERID 
EMIT CHANGES;

-- Query stream
SELECT * FROM my_stream EMIT CHANGES LIMIT 5;

-- Insert into stream
INSERT INTO my_stream (id, name) VALUES (1, 'Alice');

-- Drop
DROP STREAM my_stream;
DROP TABLE user_counts;
```

### CLI Commands
```bash
ksql --bootstrap-server localhost:9092 --schema-registry-url http://localhost:8081
```

## 7. Control Center
Web UI for monitoring (default: http://localhost:9021).

- **Features**: Topic browser, consumer lag, Connect tasks, Schema viewer.
- **Start**: `confluent local services control-center start`

## 8. Security (SASL/SSL)
### Broker Config (server.properties)
```
# SASL_PLAINTEXT
listeners=SASL_PLAINTEXT://0.0.0.0:9092
security.inter.broker.protocol=SASL_PLAINTEXT
sasl.mechanism.inter.broker.protocol=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="admin" password="admin-secret";

# SSL
listeners=SSL://0.0.0.0:9093
ssl.keystore.location=/path/to/keystore.jks
ssl.keystore.password=secret
ssl.key.password=secret
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=secret
```

### Client Config
```properties
# Producer/Consumer
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="client" password="client-secret";
ssl.truststore.location=/path/to/truststore.jks
ssl.truststore.password=secret
```

## 9. Performance Tuning
| Parameter | Default | Tuning Tip |
|-----------|---------|------------|
| **num.partitions** | 1 | Increase for throughput (e.g., 10-100 based on load). |
| **batch.size** | 16KB | Larger for batching (e.g., 1MB), but watch latency. |
| **linger.ms** | 0 | >0 for batching (e.g., 5ms). |
| **compression.type** | none | Use 'snappy' or 'lz4' for space/CPU trade-off. |
| **acks** | 1 | 'all' for durability. |
| **enable.idempotence** | false | true for exactly-once semantics. |
| **max.in.flight.requests.per.connection** | 5 | 1 with idempotence for ordering. |

### Monitoring
- JMX Metrics: Enable `JMX_PORT=9999` in broker.
- Tools: Prometheus + Grafana integration via Confluent Metrics Reporter.

## 10. Common Errors & Troubleshooting
| Error | Cause | Fix |
|-------|-------|-----|
| **LEADER_NOT_AVAILABLE** | No leader elected. | Check replication factor; increase min.insync.replicas. |
| **OFFSET_OUT_OF_RANGE** | Consumer offset invalid. | Reset: `kafka-consumer-groups --reset-offsets --group my-group --topic my-topic --to-earliest`. |
| **Schema mismatch** | Incompatible evolution. | Use COMPATIBILITY=BACKWARD in Schema Registry. |
| **Connect task failed** | Config issue. | Check logs: `connect-distributed worker.log`. |
| **High latency** | Under-partitioned. | Monitor consumer lag via Control Center; rebalance groups. |

## Quick References
- **Bootstrap Servers**: `localhost:9092` (default).
- **Ports**: Kafka 9092, Schema Reg 8081, Connect 8083, ksqlDB 8088, Control Center 9021.
- **Exactly-Once**: Enable `enable.idempotence=true` + transactions.
- **KRaft Mode** (Zookeeper-free): Set `process.roles=broker,controller` in 3.3+.

For advanced topics (e.g., Flink integration, Cloud configs), refer to Confluent docs. Update versions for your env!

# Kafka Deep Dive: Answering Key Questions

Below, I'll address each question with clear explanations, drawing from Apache Kafka's core mechanics (up to Kafka 3.8+ as of late 2025). These build on standard configurations; always test in your environment. References to Confluent features (e.g., Control Center) are included where relevant for monitoring.

## 1. Role of Active Controller in Kafka
The **active controller** is a single elected broker in a Kafka cluster responsible for cluster-wide administrative tasks and metadata management. It ensures consistency across the cluster without every broker handling these operations independently.

- **Key Responsibilities**:
  - **Leader Election**: Detects broker failures via Zookeeper (pre-Kafka 3.3) or KRaft (quorum-based controllers in 3.3+), elects new partition leaders, and assigns replicas.
  - **Partition Reassignment**: Handles manual or automatic rebalancing of partitions (e.g., during scaling or failures) by updating metadata in Zookeeper/KRaft.
  - **Topic Management**: Processes create/delete/list topic requests, assigns partitions, and configures replication.
  - **Preferred Replica Election**: Ensures even distribution of leaders across brokers to avoid hotspots.
  - **Cluster Metadata Sync**: Broadcasts changes (e.g., via ControllerChange events) to all brokers.

- **How It Works**:
  - Election: Brokers register as potential controllers; the first to acquire a Zookeeper lock (or KRaft epoch) becomes active. Only one is active at a time—failover is fast (sub-second in KRaft).
  - Failover: If the active controller dies, another is elected automatically.
  - Monitoring: Use `kafka-broker-api-versions` or Confluent Control Center to check controller status.

- **Why It Matters**: Centralizes coordination for efficiency, but in KRaft mode (recommended for new clusters), it's more distributed and Zookeeper-free for better scalability.

## 2. How Does Kafka Handle Log Compaction?
Kafka's **log compaction** is a retention and cleanup policy that enables "key-based" message retention, ideal for stateful topics (e.g., storing the latest user profile by user ID). It treats the log as a compacted key-value store rather than a pure append log.

- **Mechanism**:
  - **Enabled Per Topic**: Set `log.cleanup.policy=compact` (or `compact,cleanup` for hybrid with time/size-based deletion) when creating the topic:
    ```bash
    kafka-topics --create --topic compacted-topic --partitions 3 --replication-factor 3 --config log.cleanup.policy=compact --config log.compaction.interval.ms=300000
    ```
  - **Compaction Process**:
    - Kafka runs a background **log compactor** thread per broker (configurable via `log.compactor.threads`).
    - It scans segments periodically (default every 5 minutes via `log.compaction.interval.ms`) and removes older messages with the same key, keeping only the **tombstone** (null value) or the latest value per key.
    - Tombstones: Send a message with the key and null value to explicitly delete a key (triggers removal during compaction).
    - **Dirty Ratio**: Compaction triggers if a segment's "dirty" records exceed `log.cleaner.delete.retention.ms` (default 1 day) or `log.cleaner.min.compaction.lag.ms`.
  - **Guarantees**: Compaction is asynchronous and doesn't block producers/consumers. It's idempotent—multiple writes of the same key/version are safe. Offsets are preserved for consumers.

- **Trade-offs**:
  - **Pros**: Space-efficient for changelog topics; supports exactly-once semantics in stream processing (e.g., Kafka Streams).
  - **Cons**: CPU-intensive; not suitable for pure event logs (use `delete` policy instead).
  - **Tuning**: Monitor via JMX metrics like `kafka.log:type=Log,name=Size` or Confluent Control Center. Set `log.segment.bytes=1GB` for larger segments to reduce overhead.

- **Example Use**: In ksqlDB, compact topics back materialized views: `CREATE TABLE AS SELECT ... WITH (kafka_topic='changelog', cleanup.policy='compact');`.

## 3. Which Partitioner/Assignor Strategy Would You Use for Better Performance & Durability in Kafka?
For **performance** (throughput, low latency) and **durability** (fault tolerance, even load), choose strategies that minimize shuffling, enable batching, and distribute load evenly. Defaults have improved in recent versions.

- **Producer Partitioner** (How messages are assigned to partitions):
  - **Recommended: Sticky Partitioner** (`partitioner.class=org.apache.kafka.clients.producer.internals.StickyPartitioner`, default since Kafka 2.4).
    - **Why?** Builds batches sequentially on the same partition before rotating (improves batching efficiency, reducing network overhead by 20-50%). Better performance than round-robin, which scatters keys.
    - **Durability**: Works with keys for sticky hashing; fallback to round-robin if no key.
    - **Config**: `enable.idempotence=true` + `acks=all` for durability without perf hit.
  - **Alternative**: DefaultHashPartitioner for key-based sticky distribution (durable but less batching if keys vary).

- **Consumer Assignor** (How partitions are assigned to consumers in a group):
  - **Recommended: CooperativeStickyAssignor** (default since Kafka 2.4; use with `partition.assignment.strategy=org.apache.kafka.clients.consumer.CooperativeStickyAssignor`).
    - **Why?** Incremental rebalancing (only revokes/assigns changed partitions), reducing downtime by up to 90% vs. eager assignors. Sticky to prior assignments for cache locality and perf.
    - **Durability**: Handles failures gracefully; pairs with `session.timeout.ms=30000` and `heartbeat.interval.ms=3000`.
    - **When to Use**: High-throughput groups with frequent joins/leaves.
  - **Alternatives**:
    - RangeAssignor: Simple range-based (perf for sorted keys, but uneven).
    - RoundRobin: Even distribution (good baseline, but full rebalance on changes).

- **Overall Tips**: Set `max.in.flight.requests.per.connection=5` (or 1 for strict ordering). Monitor partition balance in Control Center. For durability, always use replication factor ≥3.

## 4. What Happens When min.insync.replicas Are Not Met? What’s the Ideal Number Would You Use? Why?
`min.insync.replicas` (default: 1) defines the minimum number of in-sync replicas (ISRs) required for a partition's leader to accept writes when `acks=all` (durability mode).

- **What Happens If Not Met**:
  - Producers receive a `NotEnoughReplicasException` (or `NotEnoughReplicasAfterAppendException` post-write).
  - The broker rejects the write, ensuring no data is lost to under-replicated partitions.
  - ISR Shrinks: If replicas lag/fail, ISR drops. If it falls below `min.insync.replicas`, writes are blocked until recovery (e.g., a replica catches up).
  - Impact: Temporary unavailability for writes; consumers unaffected. Logs show `ALLOCATION_FAILED` or ISR shrinkage.

- **Ideal Number**: **2** (for most production setups).
  - **Why?**
    - **Durability**: Tolerates 1 failure (with replication factor=3) without blocking writes—balances availability (avoids single point of failure) and fault tolerance.
    - **vs. 1**: Too risky (writes succeed even if only leader is in-sync; data loss on leader crash).
    - **vs. 3**: Overly conservative (blocks on 2 failures; hurts availability in large clusters).
  - **Contextual Tweaks**: Use 1 for low-durability dev topics; 3 for ultra-critical (e.g., finance). Set via topic config: `--config min.insync.replicas=2`.
  - **Monitoring**: Watch `kafka.server:type=ReplicaManager,name=UnderReplicatedPartitions` JMX metric or Control Center alerts.

## 5. Slow Consumer/Consumer Lag on Kafka Topic, How Do You Handle It?
Consumer lag (offset delta between produced and consumed messages) indicates bottlenecks. Triage systematically: monitor via `kafka-consumer-groups --describe` or Control Center lag charts.

- **Step-by-Step Handling**:
  1. **Diagnose**:
     - Check lag: `kafka-consumer-groups --bootstrap-server localhost:9092 --group my-group --describe`.
     - Metrics: Consumer processing time vs. `fetch.max.wait.ms` (default 500ms). Use Prometheus for `kafka_consumer_lag`.
  2. **Scale Horizontally**:
     - Add consumers to the group (up to #partitions for parallelism).
     - Increase partitions: `kafka-topics --alter --topic my-topic --partitions 12` (but rebalance triggers lag spike).
  3. **Tune Fetching**:
     - Increase `fetch.min.bytes=1MB` and `fetch.max.bytes=50MB` for larger batches.
     - Reduce `max.poll.records=500` if processing is slow.
     - Enable `enable.auto.commit=false` + manual commits for finer control.
  4. **Optimize Processing**:
     - Profile app code (e.g., offload to async threads).
     - Use Kafka Streams or ksqlDB for in-Kafka processing to reduce external lag.
     - Compress data (`compression.type=lz4`) to lower network I/O.
  5. **Infra Fixes**:
     - Upgrade hardware (CPU/RAM for consumers).
     - Check network/jitter; set `session.timeout.ms=60000` for flaky connections.
     - Reset offsets if catch-up needed: `--reset-offsets --to-latest`.
  6. **Prevention**: Set consumer quotas (`client.quota.callback.class`) to cap slow groups.

- **When Severe**: Pause/resume consumers (`consumer.pause()`) or use a dead-letter queue for failed records.

## 6. How Do You Triage Frequent Consumer Group Rebalancing?
Frequent rebalances (e.g., every few minutes) disrupt processing, causing lag spikes. Triggered by heartbeats failing or group changes. Use `kafka-consumer-groups --describe` to spot patterns.

- **Triage Steps**:
  1. **Identify Frequency/Cause**:
     - Logs: Look for "Revoking previously assigned..." or "JoinGroup failed".
     - Metrics: `rebalance-latency-avg` JMX; Control Center's consumer view.
     - Common Culprits: Short `heartbeat.interval.ms` (default 3s), long `session.timeout.ms` (30s), or consumer crashes > timeout.
  2. **Quick Fixes**:
     - Increase timeouts: `session.timeout.ms=60000`, `heartbeat.interval.ms=10000` (but not >1/3 of session).
     - Use CooperativeStickyAssignor (as above) to make rebalances incremental.
  3. **Stability Checks**:
     - Heartbeats: Ensure consumers poll frequently (`max.poll.interval.ms=300000` default; reduce if processing >5min).
     - Network: Ping brokers; tune TCP keepalives.
     - Crashes: Fix app errors (e.g., OOM); add retries with backoff.
  4. **Group Design**:
     - Static Membership (Kafka 2.3+): Set `group.instance.id=unique-per-consumer` for no rebalance on restarts.
     - Smaller Groups: Split into multiple groups if >50 consumers.
     - Avoid Dynamic Joins: Pre-scale consumers.
  5. **Advanced**:
     - Enable consumer metrics reporting.
     - Test with chaos tools (e.g., Confluent's Chaos Toolkit) to simulate failures.
     - If persistent, migrate to KRaft for faster metadata ops.

- **Goal**: Aim for rebalances <1/hour. Static IDs can eliminate them for stable groups.

For hands-on testing, spin up a local Confluent cluster as in the cheatsheet. If you need code examples or configs, let me know!

