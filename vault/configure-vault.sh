#!/bin/bash
set -e

export VAULT_ADDR="http://127.0.0.1:8200"

vault server -dev -dev-root-token-id="root-token" &
sleep 3

export VAULT_TOKEN="root-token"

vault secrets enable -path=secret kv-v2

vault kv put secret/cloud-ops/dev/db \
  host="db.cloud-ops-dev.internal" \
  port="5432" \
  username="appuser" \
  password="1S8JBNXWtc9VuWkUexmu1w==" \
  dbname="cloud_ops_dev"

vault kv put secret/cloud-ops/dev/app \
  flask_secret_key="425fd515d90cadfb5a2f4be95f5d8a96fc2094ca3efbe0ff4bce124ac395cc15" \
  jwt_secret="e3113fb73c15467d0f24d241bf8ec445fca16a6108d26574dbb1bb0b63743c74" \
  environment="dev"

vault kv put secret/cloud-ops/dev/api \
  api_key="dev-api-key-12345" \
  api_endpoint="https://api.example.com"

vault kv get secret/cloud-ops/dev/db
vault kv get secret/cloud-ops/dev/app

vault auth enable aws

vault policy write cloud-ops-policy - << 'EOF'
path "secret/data/cloud-ops/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/cloud-ops/*" {
  capabilities = ["read", "list"]
}
EOF