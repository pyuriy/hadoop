#!/usr/bin/env python3
from confluent_kafka.avro import AvroProducer
import time, json, random

KAFKA_BOOTSTRAP = "kafka:9092"
SCHEMA_REG_URL = "http://schema-registry:8081"
TOPIC = "events"

value_schema_str = open("user_event_v1.avsc").read()

conf = {
    "bootstrap.servers": KAFKA_BOOTSTRAP,
    "schema.registry.url": SCHEMA_REG_URL
}

producer = AvroProducer(conf, default_value_schema=value_schema_str)

for i in range(20):
    rec = {
        "id": str(i),
        "user_id": f"user_{i%5}",
        "event_type": "click" if i%3 else "purchase",
        "event_time": "2025-11-18T03:00:00Z",
        "value": float(i) * 0.5 if i % 2 == 0 else None
    }
    producer.produce(topic=TOPIC, value=rec)
    producer.flush()
    time.sleep(0.05)

print("Produced 20 messages")