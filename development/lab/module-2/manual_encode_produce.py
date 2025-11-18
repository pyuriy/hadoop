#!/usr/bin/env python3
import io, struct, json, requests, random, time
from fastavro import schemaless_writer
from confluent_kafka import Producer

SCHEMA_REG = "http://schema-registry:8081"
SUBJECT = "user_event-value"
TOPIC = "events"
KAFKA = "kafka:9092"

# get latest schema id
r = requests.get(f"{SCHEMA_REG}/subjects/{SUBJECT}/versions/latest")
r.raise_for_status()
schema_id = r.json()["id"]
schema = json.loads(r.json()["schema"])

p = Producer({"bootstrap.servers": KAFKA})

def encode(payload):
    bio = io.BytesIO()
    bio.write(b'\x00')  # magic byte
    bio.write(struct.pack(">I", schema_id))
    schemaless_writer(bio, schema, payload)
    return bio.getvalue()

for i in range(5):
    rec = {"id": str(i), "user_id": f"user_{i%3}", "event_type":"view", "event_time":"2025-11-18T03:00:00Z", "value": None}
    val = encode(rec)
    p.produce(TOPIC, value=val)
    p.flush()
    time.sleep(0.1)

print("Manual produced 5 messages with schema id", schema_id)