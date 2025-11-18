#!/usr/bin/env bash
SCHEMA_REG_URL=${SCHEMA_REG_URL:-http://schema-registry:8081}
SUBJECT=${SUBJECT:-user_event-value}
COMPAT=${1:-BACKWARD}  # usage: ./set_compatibility.sh BACKWARD

curl -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"compatibility\":\"${COMPAT}\"}" \
  ${SCHEMA_REG_URL}/config/${SUBJECT} | jq