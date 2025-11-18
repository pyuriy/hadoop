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