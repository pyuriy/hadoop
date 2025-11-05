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

