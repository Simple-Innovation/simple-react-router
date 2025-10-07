#!/usr/bin/env bash
set -euo pipefail

# create-service-principal.sh
# Convenience wrapper to create an Azure service principal and save the --sdk-auth JSON
# Usage: ./scripts/create-service-principal.sh [--subscription-id ID] [--name NAME] [--role ROLE] [--output FILE] [--yes]

NAME="simple-react-router-deploy"
ROLE="contributor"
SUBSCRIPTION_ID=""
OUTPUT_FILE="azure-credentials.json"
AUTO_YES=0

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --subscription-id ID   Azure subscription id to scope the service principal (default: active subscription)
  --name NAME            Service principal name (default: $NAME)
  --role ROLE            Role for the SP (default: $ROLE)
  --output FILE          File to write the JSON credentials to (default: $OUTPUT_FILE)
  --yes                  Don't prompt for confirmation
  -h, --help             Show this help

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
    --yes)
      AUTO_YES=1; shift 1;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2; usage; exit 2;;
  esac
done

command -v az >/dev/null 2>&1 || { echo "az CLI is required but not found. Install it: https://aka.ms/InstallAzureCLIDeb" >&2; exit 3; }

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
set -x
az ad sp create-for-rbac \
  --name "$NAME" \
  --role "$ROLE" \
  --scopes "/subscriptions/${SUBSCRIPTION_ID}" \
  --sdk-auth > "$OUTPUT_FILE"
set +x

echo
echo "Service principal created. Credentials written to: $OUTPUT_FILE"
echo
echo "Next steps:"
echo "1) Copy the contents of $OUTPUT_FILE and add it to the GitHub repository secret named AZURE_CREDENTIALS." 
echo "   Settings → Secrets and variables → Actions → New repository secret (AZURE_CREDENTIALS)"
echo "2) Add AZURE_SUBSCRIPTION_ID secret (value: $SUBSCRIPTION_ID)"
echo
echo "Tip: to set the secret using the GH CLI (if installed):"
echo "  gh secret set AZURE_CREDENTIALS --body \"")"
echo
echo "Done."
