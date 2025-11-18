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