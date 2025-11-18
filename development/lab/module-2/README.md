
# Module 2 — Schemas & Serialization: Avro + Schema Registry (1–2 hrs)

Goals
- Register an Avro schema in Schema Registry and produce Avro-encoded messages
- Understand schema compatibility settings

Tasks
- Register "user_event" Avro schema
- Produce Avro messages via a small Python script using confluent-kafka
- Change schema (add optional field) and test compatibility (BACKWARD, FORWARD, FULL)

Hints
- Use the Schema Registry REST API to POST schemas
- Use confluent_kafka.avro.AvroProducer in Python (or confluent-kafka + avro lib)

Verification
- Consumer can decode Avro messages using the same Schema Registry subject.


Below is a step‑by‑step, runnable, detailed guide you can follow inside the lab docker-compose environment (schema-registry: http://schema-registry:8081, kafka: kafka:9092). It includes commands, scripts, and explanations for registering schemas, producing Avro messages, consuming & decoding them, and experimenting with compatibility modes.

Prerequisites
- Docker Compose lab running (schema-registry and Kafka accessible at the service names above).
- Python 3.8+ environment (the jupyter/pyspark-notebook container or your local env).
- Install these Python packages (in the notebook container or venv):
  - pip install "confluent-kafka[avro]" fastavro requests
  - jq available on host/container for curl payload handling (optional but helpful)

High-level flow
1. Create initial Avro schema (v1).
2. Register schema in Schema Registry (subject: user_event-value).
3. Produce Avro-encoded messages referencing the schema (AvroProducer or manual).
4. Consume and decode messages (AvroConsumer or manual decode).
5. Change schema (v2 add optional field) and test compatibility (BACKWARD, FORWARD, FULL).
6. Verify consumers decode correctly and observe registry behavior on incompatible changes.

1) Create schema files
Create two schema files: initial v1 and an evolved v2 (adds an optional field).

```json name=user_event_v1.avsc
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "lab.avro",
  "fields": [
    { "name": "id", "type": "string" },
    { "name": "user_id", "type": "string" },
    { "name": "event_type", "type": "string" },
    { "name": "event_time", "type": "string" },
    { "name": "value", "type": ["null", "double"], "default": null }
  ]
}
```

```json name=user_event_v2_add_optional.avsc
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "lab.avro",
  "fields": [
    { "name": "id", "type": "string" },
    { "name": "user_id", "type": "string" },
    { "name": "event_type", "type": "string" },
    { "name": "event_time", "type": "string" },
    { "name": "value", "type": ["null", "double"], "default": null },
    { "name": "email", "type": ["null", "string"], "default": null }
  ]
}
```

2) Register schema via Schema Registry REST API (curl or Python)
You can POST the schema JSON string to /subjects/<subject>/versions.

Example shell script (register_schema.sh) — will register user_event-v1:

```bash name=register_schema.sh
#!/usr/bin/env bash
set -e
SCHEMA_REG_URL=${SCHEMA_REG_URL:-http://schema-registry:8081}
SUBJECT=${SUBJECT:-user_event-value}
SCHEMA_FILE=${SCHEMA_FILE:-user_event_v1.avsc}

schema_json=$(jq -Rs '.' < "$SCHEMA_FILE") # read file and convert to JSON string
payload=$(jq -nc --arg s "$schema_json" '{"schema":$s}')
echo "Registering $SCHEMA_FILE to $SCHEMA_REG_URL/subjects/$SUBJECT/versions"
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "$payload" "$SCHEMA_REG_URL/subjects/$SUBJECT/versions" | jq
```

Run:
- Put the avsc file in the same directory and run: chmod +x register_schema.sh && ./register_schema.sh

Python alternative:

```python name=register_schema.py
#!/usr/bin/env python3
import requests, json, sys
SCHEMA_REG = "http://schema-registry:8081"
SUBJECT = "user_event-value"
with open("user_event_v1.avsc") as f:
    schema_str = f.read()
resp = requests.post(f"{SCHEMA_REG}/subjects/{SUBJECT}/versions",
                     headers={"Content-Type": "application/vnd.schemaregistry.v1+json"},
                     data=json.dumps({"schema": schema_str}))
print(resp.status_code, resp.text)
```

After registration you will receive a JSON response like { "id": 1 } — note the schema id.

Useful inspection curl commands:
- List subjects: curl http://schema-registry:8081/subjects | jq
- Get versions: curl http://schema-registry:8081/subjects/user_event-value/versions | jq
- Get schema by id: curl http://schema-registry:8081/schemas/ids/1 | jq

3) Produce Avro-encoded messages (preferred: AvroProducer)
Use confluent_kafka.avro.AvroProducer which handles registration and framing for you.

produce_avro.py — AvroProducer example:

```python name=produce_avro.py
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
```

Run it in the container (or environment that can reach kafka and schema-registry):
- python produce_avro.py

Note: AvroProducer by default will use subject naming strategy that creates the subject name topic-name-value (e.g., events-value) unless you change the subject naming strategy.

4) Alternative: manual encode + produce (fastavro + requests)
This shows the Confluent wire format (magic byte + 4-byte schema id + avro payload). Useful to understand what's happening under the hood.

manual_encode_produce.py:

```python name=manual_encode_produce.py
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
```

5) Consume & decode Avro messages
Preferred: AvroConsumer (handles Confluent framing and schema lookups)

consume_avro.py:

```python name=consume_avro.py
#!/usr/bin/env python3
from confluent_kafka.avro import AvroConsumer

conf = {
    "bootstrap.servers": "kafka:9092",
    "schema.registry.url": "http://schema-registry:8081",
    "group.id": "lab-avro-consumer",
    "auto.offset.reset": "earliest"
}

c = AvroConsumer(conf)
c.subscribe(["events"])
try:
    while True:
        msg = c.poll(2)
        if msg is None:
            break
        if msg.error():
            print("Consumer error:", msg.error())
            break
        print("Decoded message:", msg.value())
finally:
    c.close()
```

Manual decode example (if you used manual encode earlier):

manual_decode_consume.py

```python name=manual_decode_consume.py
#!/usr/bin/env python3
import struct, io, json, requests
from fastavro import schemaless_reader
from confluent_kafka import Consumer

KAFKA = "kafka:9092"
SCHEMA_REG = "http://schema-registry:8081"

c = Consumer({"bootstrap.servers": KAFKA, "group.id":"manual-decoder", "auto.offset.reset":"earliest"})
c.subscribe(["events"])

def decode(bytestr):
    bio = io.BytesIO(bytestr)
    magic = bio.read(1)
    if magic != b'\x00':
        raise Exception("Unknown magic byte")
    schema_id = struct.unpack('>I', bio.read(4))[0]
    r = requests.get(f"{SCHEMA_REG}/schemas/ids/{schema_id}")
    r.raise_for_status()
    schema = json.loads(r.json()["schema"])
    record = schemaless_reader(bio, schema)
    return record, schema_id

try:
    while True:
        msg = c.poll(2)
        if msg is None:
            break
        if msg.error():
            print("Error:", msg.error()); break
        rec, sid = decode(msg.value())
        print("schema_id:", sid, "record:", rec)
finally:
    c.close()
```

6) Compatibility modes — what they mean and how to test
Compatibility options (common ones):
- NONE — no checks
- BACKWARD — new schema must be able to read data produced with previous schema(s)
- FORWARD — old readers must be able to read data written with new schema
- FULL — both backward and forward compatibility

Set compatibility for the subject (curl examples):

```bash name=set_compatibility.sh
#!/usr/bin/env bash
SCHEMA_REG_URL=${SCHEMA_REG_URL:-http://schema-registry:8081}
SUBJECT=${SUBJECT:-user_event-value}
COMPAT=${1:-BACKWARD}  # usage: ./set_compatibility.sh BACKWARD

curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"compatibility\":\"${COMPAT}\"}" \
  ${SCHEMA_REG_URL}/config/${SUBJECT} | jq
```

Test sequence to demonstrate compatibility:
- Set subject compatibility to BACKWARD: ./set_compatibility.sh BACKWARD
- Register v1 (already done)
- Register v2 (user_event_v2_add_optional.avsc) — should succeed with BACKWARD because added field is optional and has default
  - Use register_schema.sh with SCHEMA_FILE=user_event_v2_add_optional.avsc
- Try an incompatible change (e.g., remove a field or add a non-nullable field without default). Registering such schema will return 4xx error with compatibility explanation.

Example incompatible schema (remove value field):

```json name=user_event_v3_remove_value.avsc
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "lab.avro",
  "fields": [
    { "name": "id", "type": "string" },
    { "name": "user_id", "type": "string" },
    { "name": "event_type", "type": "string" },
    { "name": "event_time", "type": "string" }
  ]
}
```

Registering v3 with BACKWARD should fail — the registry will return an error describing why (e.g., deleting a field without default breaks compatibility).

7) End‑to‑end verification checklist
- After v1 registration: produce messages (produce_avro.py) and consume via AvroConsumer (consume_avro.py) — consumer prints decoded dictionaries.
- After adding v2 and registering with BACKWARD: producing v2 messages should succeed; AvroConsumer (which fetches writer schema id and reader schema is not needed) will decode v2 messages fine.
- Try register v3 (incompatible): registry should return HTTP error. Confirm with curl response.
- Inspect schema history and IDs: curl /subjects/user_event-value/versions and /schemas/ids/<id> to map ids to content.

8) Tips, gotchas, and troubleshooting
- Subject naming: default Confluent behavior uses topic-name-value for value schemas. If you use a different SubjectNameStrategy in client configs, subject names differ.
- Wire format: AvroProducer and AvroConsumer use the Confluent wire format: magic byte 0x00 + 4-byte schema id + Avro payload. Manual producers/consumers must implement that.
- When consumers decode, they request the writer schema identified by schema id — if registry not reachable, AvroConsumer fails.
- If you use logical types (timestamp-millis), ensure consumers support them or use string timestamp to avoid confusion.
- Watch for JSON encoding issues when posting schema via curl; use jq to escape properly or use Python requests.
- If AvroProducer tries to register a schema and registration fails due to compatibility, the producer will fail to serialize/produce.

9) Optional: Spark Structured Streaming reading Avro from Kafka with Schema Registry

- If you want Spark to decode Avro messages written in Confluent wire format, you can:
  - Use the Confluent schema-registry client library for Spark or
  - Implement a UDF to call the same manual decode logic (retrieve writer schema by id and call fastavro.schemaless_reader) — but this is slower.
  - Alternatively, produce JSON for Spark or use Kafka Connect to convert Avro to JSON.

10) What we have here

- Step-by-step narrative and commands to implement Module 2.
- Several ready-to-run script files you can drop into the lab environment:
  - user_event_v1.avsc (initial schema)
  - user_event_v2_add_optional.avsc (evolution example)
  - user_event_v3_remove_value.avsc (incompatible example)
  - register_schema.sh and register_schema.py (schema registration)
  - produce_avro.py (AvroProducer)
  - manual_encode_produce.py (manual encoding + produce)
  - consume_avro.py (AvroConsumer)
  - manual_decode_consume.py (manual decode)
  - set_compatibility.sh (set compatibility mode)
