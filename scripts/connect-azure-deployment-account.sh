#!/bin/bash

# This script logs into Azure using the service principal credentials from azure-credentials.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="${SCRIPT_DIR}/../azure-credentials.json"

echo "Connecting to Azure using service principal..."

# Check if credentials file exists
if [[ ! -f "${CREDENTIALS_FILE}" ]]; then
  echo "Error: Credentials file not found at ${CREDENTIALS_FILE}"
  exit 1
fi

# Extract values from JSON file using jq (or python as fallback)
if command -v jq &> /dev/null; then
  CLIENT_ID=$(jq -r '.clientId' "${CREDENTIALS_FILE}")
  CLIENT_SECRET=$(jq -r '.clientSecret' "${CREDENTIALS_FILE}")
  TENANT_ID=$(jq -r '.tenantId' "${CREDENTIALS_FILE}")
  SUBSCRIPTION_ID=$(jq -r '.subscriptionId' "${CREDENTIALS_FILE}")
else
  # Fallback to python if jq is not available
  CLIENT_ID=$(python3 -c "import json; print(json.load(open('${CREDENTIALS_FILE}'))['clientId'])")
  CLIENT_SECRET=$(python3 -c "import json; print(json.load(open('${CREDENTIALS_FILE}'))['clientSecret'])")
  TENANT_ID=$(python3 -c "import json; print(json.load(open('${CREDENTIALS_FILE}'))['tenantId'])")
  SUBSCRIPTION_ID=$(python3 -c "import json; print(json.load(open('${CREDENTIALS_FILE}'))['subscriptionId'])")
fi

# Login to Azure using service principal
az login --service-principal \
  --username "${CLIENT_ID}" \
  --password "${CLIENT_SECRET}" \
  --tenant "${TENANT_ID}"

# Set the default subscription
az account set --subscription "${SUBSCRIPTION_ID}"

# Verify login
echo ""
echo "Successfully logged in to Azure!"
echo "Subscription: $(az account show --query name -o tsv)"
echo "Subscription ID: ${SUBSCRIPTION_ID}"
echo "Tenant ID: ${TENANT_ID}"
