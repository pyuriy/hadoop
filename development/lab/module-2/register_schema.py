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