#!/usr/bin/env bash
set -euo pipefail

# create-service-principal.sh
# Convenience wrapper to create an Azure service principal and save the --sdk-auth JSON
# Usage: ./scripts/create-service-principal.sh [--subscription-id ID] [--name NAME] [--role ROLE] [--output FILE] [--yes]

NAME="simple-react-router-deploy"
ROLE="contributor"
SUBSCRIPTION_ID=""
OUTPUT_FILE="azure-credentials.json"
GITHUB_TOKEN=""
AUTO_YES=0
SET_SECRETS=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --subscription-id ID   Azure subscription id to scope the service principal (default: active subscription)
  --name NAME            Service principal name (default: $NAME)
  --role ROLE            Role for the SP (default: $ROLE)
  --output FILE          File to write the JSON credentials to (default: $OUTPUT_FILE)
  --set-secrets         Attempt to set the secrets in GitHub using the gh CLI (requires gh to be installed and authenticated)
  --yes                  Don't prompt for confirmation
  -h, --help             Show this help
  --github-token TOKEN   Provide a GitHub PAT/fine-grained token to authenticate gh for uploading secrets (keeps token out of shell history when passed as env)

Example:
  $0 --subscription-id \\$(az account show --query id -o tsv) --name my-sp --output my-creds.json

After running, add the generated JSON to the GitHub secret named AZURE_CREDENTIALS and set AZURE_SUBSCRIPTION_ID accordingly.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --subscription-id)
      SUBSCRIPTION_ID="$2"; shift 2;;
    --name)
      NAME="$2"; shift 2;;
    --role)
      ROLE="$2"; shift 2;;
    --output)
      OUTPUT_FILE="$2"; shift 2;;
    --set-secrets)
      SET_SECRETS=1; shift 1;;
      --github-token)
        GITHUB_TOKEN="$2"; shift 2;;
    --yes)
      AUTO_YES=1; shift 1;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

command -v az >/dev/null 2>&1 || { echo "az CLI is required but not found. Install it: https://aka.ms/InstallAzureCLIDeb" >&2; exit 3; }

# Ensure jq is available for JSON parsing
command -v jq >/dev/null 2>&1 || { echo "jq is required but not found. Install it with 'sudo apt-get install -y jq' or 'brew install jq'" >&2; exit 3; }

# Determine subscription id if not provided
if [[ -z "$SUBSCRIPTION_ID" ]]; then
  if az account show >/dev/null 2>&1; then
    SUBSCRIPTION_ID=$(az account show --query id --output tsv)
  else
    echo "You are not logged in. Please run: az login" >&2
    exit 4
  fi
fi

echo "Using subscription: $SUBSCRIPTION_ID"
echo "Service principal name: $NAME"
echo "Role: $ROLE"
echo "Output file: $OUTPUT_FILE"

if [[ $AUTO_YES -ne 1 ]]; then
  read -p "Create service principal in subscription ${SUBSCRIPTION_ID}? [y/N] " -r
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."; exit 1
  fi
fi

echo "Creating service principal..."

# Create the service principal (without --sdk-auth to avoid deprecation warnings). The command
# returns a minimal JSON with appId, password and tenant which we use to assemble an SDK-style
# JSON file compatible with azure/login action.
SP_JSON=$(az ad sp create-for-rbac \
  --name "$NAME" \
  --role "$ROLE" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  -o json)

APP_ID=$(echo "$SP_JSON" | jq -r '.appId // .clientId')
PASSWORD=$(echo "$SP_JSON" | jq -r '.password // .clientSecret')
TENANT=$(echo "$SP_JSON" | jq -r '.tenant')

if [[ -z "$APP_ID" || -z "$PASSWORD" || -z "$TENANT" || "$APP_ID" == "null" ]]; then
  echo "Error: failed to create service principal or parse response:" >&2
  echo "$SP_JSON" >&2
  exit 5
fi

cat > "$OUTPUT_FILE" <<JSON
{
  "clientId": "$APP_ID",
  "clientSecret": "$PASSWORD",
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
JSON

echo
echo "Service principal created. Credentials written to: $OUTPUT_FILE"
echo
echo "Next steps:"
echo "1) Copy the contents of $OUTPUT_FILE and add it to the GitHub repository secret named AZURE_CREDENTIALS." 
echo "   Settings → Secrets and variables → Actions → New repository secret (AZURE_CREDENTIALS)"
echo "2) Add AZURE_SUBSCRIPTION_ID secret (value: $SUBSCRIPTION_ID)"
echo
if [[ $SET_SECRETS -eq 1 ]]; then
  if command -v gh >/dev/null 2>&1; then
    echo "Uploading secrets to GitHub using gh..."
    # If a token was provided, authenticate gh non-interactively for this session
    if [[ -n "$GITHUB_TOKEN" ]]; then
      echo "Authenticating gh with provided token..."
      # Use a here-string to avoid token appearing in process list
      gh auth login --with-token <<< "$GITHUB_TOKEN" >/dev/null 2>&1 || echo "Warning: gh auth login failed with provided token"
    fi
    # AZURE_CREDENTIALS
    gh secret set AZURE_CREDENTIALS --body "$(cat "$OUTPUT_FILE")" || echo "Failed to set AZURE_CREDENTIALS via gh"
    # AZURE_SUBSCRIPTION_ID
    echo -n "$SUBSCRIPTION_ID" | gh secret set AZURE_SUBSCRIPTION_ID || echo "Failed to set AZURE_SUBSCRIPTION_ID via gh"
    echo "Secrets uploaded (or attempted). Verify in repository Settings → Secrets and variables → Actions."
  else
    echo "gh CLI not found; cannot upload secrets automatically. Install gh and authenticate, or set secrets manually in GitHub." >&2
  fi
else
  echo "Tip: to set the secret using the GH CLI (if installed):"
  echo "  gh secret set AZURE_CREDENTIALS --body \"$(cat $OUTPUT_FILE | sed -e 's/"/\\"/g')\""
  echo "  echo -n \"$SUBSCRIPTION_ID\" | gh secret set AZURE_SUBSCRIPTION_ID"
fi
echo
echo "Done."
