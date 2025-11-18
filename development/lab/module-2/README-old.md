
# Module 2 — Schemas & Serialization: Avro + Schema Registry (1–2 hrs)

## Goals

- Register an Avro schema in Schema Registry and produce Avro-encoded messages
- Understand schema compatibility settings

## Tasks

- Register "user_event" Avro schema
- Produce Avro messages via a small Python script using confluent-kafka
- Change schema (add optional field) and test compatibility (BACKWARD, FORWARD, FULL)

## Hints

- Use the Schema Registry REST API to POST schemas
- Use confluent_kafka.avro.AvroProducer in Python (or confluent-kafka + avro lib)

## Verification

- Consumer can decode Avro messages using the same Schema Registry subject.

Below is a detailed, step-by-step walkthrough for Module 2. It explains how to register a schema, produce and consume Avro-encoded messages, and experiment with compatibility settings (BACKWARD, FORWARD, FULL). I include shell and Python examples you can run inside the lab environment (schema-registry at http://schema-registry:8081, Kafka at kafka:9092).

##  Overview / prerequisites

- Running Schema Registry reachable at http://schema-registry:8081.
- Kafka broker reachable at kafka:9092.
- Python environment with:
  - confluent-kafka (and confluent-kafka[avro] for AvroProducer/AvroConsumer), or confluent-kafka + fastavro + requests for manual encode/decode.
  - fastavro (for manual decoding).
- jq installed in container/host (optional; used in curl examples).
- Topic name in this lab: events (we will use subject naming for value: user_event-value by convention).

### 1) Avro schema — create the initial schema (user_event v1)

Create a file [user_event_v1.avsc](./user_event_v1.avsc) with this content:

```avro
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "lab.avro",
  "fields": [
    {"name": "id", "type": "string"},
    {"name": "user_id", "type": "string"},
    {"name": "event_type", "type": "string"},
    {"name": "event_time", "type": "string"},
    {"name": "value", "type": ["null", "double"], "default": null}
  ]
}
```

**Notes:**

- event_time as string here for simplicity; you can encode timestamps as strings or logical types if you prefer.
- value is nullable with default null so it's backward/forward-friendly for changes to that field.

### 2) Register the schema in Schema Registry via REST (curl + jq)

Schema Registry expects a JSON object { "schema": "<avro schema as JSON string>" }.

Easy reliable way using jq to post the schema file:

Assuming you're in same directory as user_event_v1.avsc

```bash
schema=$(<user_event_v1.avsc)
payload=$(jq -nc --arg s "$schema" '{"schema":$s}')
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "$payload" \
  http://schema-registry:8081/subjects/user_event-value/versions | jq
```

Expected response:
```{ "id": <numeric-schema-id> }```

Take note of the returned id (you can also list versions and ids later).

Alternative: register using Python (requests):

```python
import requests, json
schema = open("user_event_v1.avsc").read()
resp = requests.post("http://schema-registry:8081/subjects/user_event-value/versions",
                     headers={"Content-Type":"application/vnd.schemaregistry.v1+json"},
                     data=json.dumps({"schema": schema}))
print(resp.json())
```

### 3) Inspect subjects, versions, and schema ids

List subjects:

```curl http://schema-registry:8081/subjects | jq```

Get versions for your subject:

```curl http://schema-registry:8081/subjects/user_event-value/versions | jq```

Get a schema by id:
```curl http://schema-registry:8081/schemas/ids/1 | jq```

### 4) Produce Avro-encoded messages: simplest using confluent_kafka.avro.AvroProducer

#### Option A — using confluent-kafka[avro] (convenient):

Python example: produce_avro.py

```python
from confluent_kafka.avro import AvroProducer
import json
import time

value_schema_str = open("user_event_v1.avsc").read()

conf = {
    'bootstrap.servers': 'kafka:9092',
    'schema.registry.url': 'http://schema-registry:8081'
}

producer = AvroProducer(conf, default_value_schema=value_schema_str)

for i in range(10):
    val = {
        "id": str(i),
        "user_id": f"user_{i%3}",
        "event_type": "click" if i%2==0 else "view",
        "event_time": "2025-11-18T03:00:00Z",
        "value": None
    }
    producer.produce(topic="events", value=val)
    producer.flush()
    time.sleep(0.1)
```

**Notes:**

- AvroProducer will register the schema (or reuse existing) and serialize values in Confluent wire format (magic byte + schema id + payload).
- The subject used will be user_event-value if you provided default_value_schema and your topic is events; check client docs for exact subject naming conventions.

#### Option B — using confluent_kafka with manual schema registry client + fastavro

If you prefer to manage registration and serialization yourself:

- Register schema (as in step 2), get returned id.
- Use fastavro.schemaless_writer to encode the record to bytes, then prepend Confluent wire format header:
  - 1 byte: 0 (magic)
  - 4 bytes: schema id, big-endian integer
  - rest: Avro-encoded payload

Example encode snippet:

```python
import io, struct, json, requests
from fastavro import schemaless_writer

schema = json.loads(open("user_event_v1.avsc").read())
# register first, or assume you have id 1
resp = requests.get("http://schema-registry:8081/subjects/user_event-value/versions/latest")
schema_id = resp.json()["id"]

def encode_confluent_avro(payload_dict, schema, schema_id):
    bio = io.BytesIO()
    # magic byte
    bio.write(b'\x00')
    # 4-byte schema id big-endian
    bio.write(struct.pack('>I', schema_id))
    # avro payload
    schemaless_writer(bio, schema, payload_dict)
    return bio.getvalue()

Then produce the returned bytes as Kafka message value using confluent-kafka Producer.produce(topic='events', value=bytes_value).
```

### 5) Consume Avro messages and decode (consumer side)

#### Option A — AvroConsumer (confluent_kafka.avro)

```python
from confluent_kafka.avro import AvroConsumer

conf = {
    'bootstrap.servers': 'kafka:9092',
    'schema.registry.url':'http://schema-registry:8081',
    'group.id': 'lab-avro-consumer',
    'auto.offset.reset': 'earliest'
}
c = AvroConsumer(conf)
c.subscribe(['events'])
msg = c.poll(10)
if msg:
    print(msg.value())
c.close()
```

AvroConsumer will fetch the writer schema via the schema id embedded in the message and decode to Python dict.

#### Option B — manual decode using fastavro and Schema Registry REST

Read message.value() bytes from Kafka consumer, then:

```python
import io, struct, requests
from fastavro import schemaless_reader

def decode_confluent_avro(bytestr):
    bio = io.BytesIO(bytestr)
    magic = bio.read(1)
    if magic != b'\x00':
        raise ValueError("Unknown magic byte")
    schema_id_bytes = bio.read(4)
    schema_id = struct.unpack('>I', schema_id_bytes)[0]
    schema = requests.get(f'http://schema-registry:8081/schemas/ids/{schema_id}').json()['schema']
    schema = json.loads(schema)
    record = schemaless_reader(bio, schema)
    return record
```

This approach is useful to understand the wire format and to support non-Confluent clients.

### 6) Compatibility modes: concepts and how to test

Compatibility controls whether a new schema can be registered relative to previous versions. Common modes:

- NONE — no compatibility checks.
- BACKWARD — new schema must be able to read data produced with the previous schema(s) (new schema is backward-compatible with previous). Most common for producers evolving schema while consumers use latest schema.
- FORWARD — new schema must be such that old readers can read data produced with new schema.
- FULL — both backward and forward (i.e., both sets of constraints).
- Backward/Forward can be applied per subject or globally.

Set compatibility for subject:

```bash
# set BACKWARD
curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility":"BACKWARD"}' \
  http://schema-registry:8081/config/user_event-value | jq
```

Get compatibility:
```curl http://schema-registry:8081/config/user_event-value | jq```

Test compatibility by trying to register evolved schemas.

#### Example evolution #1 — Add an optional field with default (backward compatible)

user_event_v2_add_optional.avsc:

```avro
{
  "type": "record",
  "name": "UserEvent",
  "namespace": "lab.avro",
  "fields": [
    {"name": "id", "type": "string"},
    {"name": "user_id", "type": "string"},
    {"name": "event_type", "type": "string"},
    {"name": "event_time", "type": "string"},
    {"name": "value", "type": ["null", "double"], "default": null},
    {"name": "email", "type": ["null", "string"], "default": null}
  ]
}
```

- Registering this with BACKWARD compatibility should succeed because new schema can read old data (new field has default).
- With FORWARD compatibility, adding a field with default is also usually fine; FULL also fine.
- If you add a field without default or nullable type, BACKWARD may fail.

#### Example evolution #2 — Remove a field (not backward compatible unless default present)

If you remove "value" field entirely in the new schema:

- BACKWARD: new schema cannot read old messages that contain "value" because reader expects fewer fields — this is typically not allowed.
- FORWARD: may still be allowed depending on specifics.

Concrete test flow:

1. Set compatibility to BACKWARD:
   curl -X PUT ... '{"compatibility":"BACKWARD"}' http://schema-registry:8081/config/user_event-value
2. Try to register v2 (with optional email) — expected: 200 OK with new id.
3. Try to register another v3 that removes a required field — expected: 4xx error and JSON explaining incompatibility.

Example: Post v2:

```bash
schema=$(<user_event_v2_add_optional.avsc)
payload=$(jq -nc --arg s "$schema" '{"schema":$s}')
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "$payload" \
  http://schema-registry:8081/subjects/user_event-value/versions | jq
```

If compatibility prevents the change you will see an error payload describing why registration failed.

### 7) Full end-to-end verification steps

- Register v1 (step 2). Note schema id.
- Produce Avro messages (step 4) using AvroProducer (which will reference the schema id).
- Consume them with AvroConsumer / manual decode (step 5) to confirm payloads decoded correctly.
- Set compatibility to BACKWARD; attempt to register v2 (add optional field) — should succeed.
- Produce messages using v2 (AvroProducer using v2 as default schema); consume with v1 AvroConsumer configured to use v1? In most realistic flows producers write with new schema id, consumers fetch writer schema and decode; to test reader-only compatibility you may simulate old consumer expecting v1 schema — that’s more involved; but you can at minimum verify the registry accepted the new schema.
- Change compatibility to FORWARD and attempt to register a different incompatible change to observe rejection.

### 8) Troubleshooting / gotchas

- Subject naming: Confluent convention: <topic>-value for value schemas, <topic>-key for key schemas. If your producer sets subject name strategy differently, the subject names differ (e.g., topic+recordName strategy).
- Content-Type when registering: must be application/vnd.schemaregistry.v1+json.
- Escaping the schema JSON for curl can be error-prone — use jq to prepare payload or use a small Python script.
- If consumer fails to decode, check the bytes: Confluent wire format begins with 0x00 magic byte and 4-byte schema id. If your producer wrote raw Avro without Confluent framing, AvroConsumer will fail.
- Ensure confluent-kafka[avro] installed to use AvroProducer and AvroConsumer.
- If using MinIO/S3 or different network, ensure schema-registry address reachable by your code (use full http://host:port).

### 9) Example quick scripts and files (summary)

Files:
- user_event_v1.avsc (initial schema)
- user_event_v2_add_optional.avsc (evolution example)
- produce_avro.py (AvroProducer example)
- consume_avro.py (AvroConsumer example)
- manual_encode_produce.py (fastavro + schema registry id + Producer)
- manual_decode_consume.py (fastavro decode of incoming Kafka bytes)