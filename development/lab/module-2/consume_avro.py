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