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

# If no GitHub token was provided via CLI, try to read it from a .env file (do not export or print it)
if [[ -z "$GITHUB_TOKEN" && -f .env ]]; then
  # Prefer GITHUB_TOKEN, fall back to GITHUB_PAT
  read_env_var() {
    local key="$1"
    local val
    val=$(grep -m1 -E "^${key}=" .env || true)
    if [[ -n "$val" ]]; then
      # Remove key and equals, strip surrounding quotes if present
      val=${val#${key}=}
      val=${val%}
      val=${val#}
      echo "$val"
    fi
  }

  TOKEN_FROM_ENV=$(read_env_var "GITHUB_TOKEN" || true)
  if [[ -z "$TOKEN_FROM_ENV" ]]; then
    TOKEN_FROM_ENV=$(read_env_var "GITHUB_PAT" || true)
  fi
  if [[ -n "$TOKEN_FROM_ENV" ]]; then
    GITHUB_TOKEN="$TOKEN_FROM_ENV"
    # Do not print the token; just indicate we loaded one
    echo "Loaded GitHub token from .env (will use it for gh authentication)."
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

# Prefer subscriptionId from the generated JSON when uploading the separate secret
SUBSCRIPTION_ID_FROM_JSON=$(jq -r '.subscriptionId // empty' "$OUTPUT_FILE" 2>/dev/null || true)
if [[ -n "$SUBSCRIPTION_ID_FROM_JSON" ]]; then
  SUBSCRIPTION_ID_TO_UPLOAD="$SUBSCRIPTION_ID_FROM_JSON"
else
  SUBSCRIPTION_ID_TO_UPLOAD="$SUBSCRIPTION_ID"
fi

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
      # Preserve any existing GITHUB_PAT, then clear it from the environment so gh will store credentials
      PREV_GITHUB_PAT="${GITHUB_PAT-}"
      unset GITHUB_PAT
      # Use a here-string to avoid token appearing in process list
      if ! gh auth login --with-token <<< "$GITHUB_TOKEN" >/dev/null 2>&1; then
        echo "Warning: gh auth login failed with provided token" >&2
      fi
      # Restore previous env var if it existed
      if [[ -n "${PREV_GITHUB_PAT-}" ]]; then
        export GITHUB_PAT="$PREV_GITHUB_PAT"
      fi
    fi
    # AZURE_CREDENTIALS
    upload_failed=0

    upload_secret() {
      local name="$1"
      local body="$2"
      if ! echo -n "$body" | gh secret set "$name" -R "$REPO" 2>/tmp/gh_err; then
        upload_failed=1
        return 1
      fi
      return 0
    }

    # Determine repo (owner/repo) to pass to gh; fall back to current directory's origin
    REPO=""
    if gh repo view --json nameWithOwner >/dev/null 2>&1; then
      REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
    else
      # Try to read from git remote
      REPO=$(git remote get-url origin 2>/dev/null || true)
      # Convert git@github.com:owner/repo.git to owner/repo
      REPO=${REPO#git@github.com:}
      REPO=${REPO#https://github.com/}
      REPO=${REPO%.git}
    fi

    # Upload AZURE_CREDENTIALS
    if ! upload_secret AZURE_CREDENTIALS "$(cat "$OUTPUT_FILE")"; then
      echo "Failed to set AZURE_CREDENTIALS via gh"
    fi

    # Create/update repository variable AZURE_SUBSCRIPTION_ID (so workflows can use vars.AZURE_SUBSCRIPTION_ID)
    if ! gh api --method PUT "/repos/${REPO}/actions/variables/AZURE_SUBSCRIPTION_ID" -f value="$SUBSCRIPTION_ID_TO_UPLOAD" 2>/tmp/gh_var_err; then
      echo "Failed to create/update repository variable AZURE_SUBSCRIPTION_ID" >&2
      upload_failed=1
      echo "Error details:"; sed -n '1,200p' /tmp/gh_var_err || true
    fi

    if [[ $upload_failed -eq 1 ]]; then
      echo
      echo "Troubleshooting: gh authentication & permissions"
      echo "--- gh auth status ---"
      gh auth status || true
      echo "--- try fetching repository public key (permission check) ---"
      if ! gh api repos/${REPO}/actions/secrets/public-key -q '.key' 2>/tmp/gh_err; then
        echo "Failed to fetch repo public key. Inspect error below:"
        sed -n '1,200p' /tmp/gh_err || true
        echo "Common causes: token lacks 'Secrets (Actions) -> Read & write' permission for repository, token not authorized for repo, or org restrictions (SSO)."
      else
        echo "Repository public key fetched successfully; problem may be with upload encryption or gh client."
      fi
      echo "Check the token permissions and that the token is authorized for the repository." 
    else
      echo "Secrets uploaded successfully. Verify in repository Settings → Secrets and variables → Actions."
    fi
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
