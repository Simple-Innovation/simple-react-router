# Azure Web App Deployment Guide

This guide explains how to deploy the Simple React Router demo application to Azure Web App using GitHub Actions. The deployment uses **Bicep** (Infrastructure as Code) to automatically provision Azure resources.

## Prerequisites

- An Azure account with an active subscription
- A GitHub repository with the Simple React Router code
- Admin access to the GitHub repository (to configure secrets)
- Azure CLI installed (for creating service principal)

### Install Azure CLI in a GitHub Codespace

Prefer the official Microsoft installer for the modern Azure CLI (`az`) when working in a Codespace. The official installer provides the supported, up-to-date distribution and is the recommended path for production or CI environments. If you must use a node/npm package, note it historically installs a legacy `azure` command (see note below) and is not recommended.

Official installer (requires sudo in the Codespace):

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

User (no-sudo) alternative via pip:

```bash
python3 -m pip install --user azure-cli
export PATH="$HOME/.local/bin:$PATH"
az --version
```

If you already have a legacy npm-installed package and need to diagnose why `az` is missing, check the npm prefix/bin as described below.

Note about the npm `azure-cli` package

The community npm package historically provides the older Node.js-based Azure CLI (often called `azure` or `azure-xplat-cli`) and installs an executable named `azure` rather than the newer `az` command used by Microsoft's modern CLI. If you installed that package, you may find the legacy executable in your npm global bin directory (usually `$(npm prefix -g)/bin`). We strongly recommend installing the official `az` CLI instead.

Alternatives (preferred when available)

- Official Microsoft installer (requires sudo in the environment):

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

- Install via pip (user install):

```bash
python3 -m pip install --user azure-cli
```

Use these alternatives if you need the officially supported distribution or run into npm package limitations.

## Setup Steps

### Login to Azure and select subscription

Before creating a service principal, make sure you're logged in to the Azure CLI and have selected the correct subscription. This ensures the service principal and resources are created in the intended subscription.

Interactive login (recommended when working locally):

```bash
# Sign in with your user account (opens a browser window)
az login

# List available subscriptions (helps you pick the right one)
az account list --output table

# Set the active subscription by name or id
az account set --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME"

# Verify the active subscription id
az account show --query id --output tsv
```

Non-interactive login using a service principal (useful for CI or automation):

```bash
# Example: login with client id, client secret and tenant id
az login --service-principal \
  --username <APP_CLIENT_ID> \
  --password <APP_CLIENT_SECRET> \
  --tenant <TENANT_ID>

# Then set and verify the subscription as above
az account set --subscription "YOUR_SUBSCRIPTION_ID_OR_NAME"
az account show --query id --output tsv
```

Notes:

- If you are creating the service principal locally, first ensure `az account show` returns the subscription you intend to use. Use `az account set` to switch if needed.
- The `AZURE_SUBSCRIPTION_ID` repository Variable should match the subscription you select here; the workflow reads the subscription id from a repository Variable named `AZURE_SUBSCRIPTION_ID`.

### 1. Create an Azure Service Principal

The service principal allows GitHub Actions to manage your Azure resources. Run the following command in Azure CLI:

```bash
az ad sp create-for-rbac \
  --name "simple-react-router-deploy" \
  --role contributor \
  --scopes /subscriptions/{your-subscription-id} \
  --sdk-auth
```

Replace `{your-subscription-id}` with your actual Azure subscription ID. You can find your subscription ID by running:

```bash
az account show --query id --output tsv
```

The command will output JSON credentials. **Save this entire JSON output** - you'll need it in the next step.

### Authenticate the GitHub CLI (`gh`) using a Personal Access Token (PAT)

If you want the helper script to upload secrets automatically (`--set-secrets`), `gh` must be authenticated with a token that has permission to manage Actions secrets for the repository. There are two common token types:

- Fine-grained personal access token (recommended): when creating the token, select the specific repository and grant the repository permission "Secrets (Actions)" → Read & write (and optionally "Actions" → Read & write).
- Classic personal access token: grant the `repo` scope (sufficient for private repos) and `workflow` if needed.

Create a token at <https://github.com/settings/tokens> (choose "Fine-grained" for tighter scope). Keep the token secret.

Authenticate `gh` non-interactively with your token (example):

```bash
# Prefer reading the token from an environment variable or .env file to avoid leaving it in your shell history
# Example .env file:
#   GITHUB_PAT=ghp_xxx...yourtoken...
export $(grep -v '^#' .env | xargs)
# If GITHUB_PAT is set in your environment, save and clear it so gh stores the credentials instead
PREV_GITHUB_PAT="${GITHUB_PAT-}"
unset GITHUB_PAT
echo "$GITHUB_PAT" | gh auth login --with-token
# restore the previous value (if any) to avoid leaking the token in the environment
if [[ -n "${PREV_GITHUB_PAT-}" ]]; then
  export GITHUB_PAT="$PREV_GITHUB_PAT"
fi

# Confirm auth status
gh auth status

# Verify you can read the repository public key (replace owner/repo as needed):
gh api repos/Simple-Innovation/simple-react-router/actions/secrets/public-key -q '.key'
```

If the last command returns a long base64-looking string, `gh` has permission to manage secrets for that repository and the helper script can upload secrets using `--set-secrets`.

Example using the helper script with a token (non-interactive):

```bash
./scripts/create-service-principal.sh \
  --subscription-id $(az account show --query id -o tsv) \
  --output azure-credentials.json \
  --yes --set-secrets --github-token "$GITHUB_PAT"
```

Security notes:

- Prefer fine-grained tokens and restrict them to the single repository and only the permissions required (Secrets (Actions) → Read & write).
- Avoid passing tokens directly on the command line if possible (use environment variables or stdin) so they don't appear in shell history or process listings.
- Revoke the token when it is no longer needed.

Alternatively, use the included helper script `scripts/create-service-principal.sh` which wraps the command and saves the JSON for you.

Note: the `--sdk-auth` flag is deprecated in recent `az` releases and will be removed in the future. The helper script avoids this warning by creating the service principal and assembling the SDK-style JSON itself, producing an output compatible with the `AZURE_CREDENTIALS` secret used by the GitHub Action `azure/login`.

Example (interactive):

```bash
# Ensure you are logged in and have set the subscription (see above)
./scripts/create-service-principal.sh --output azure-credentials.json

# Then copy the contents of azure-credentials.json into the AZURE_CREDENTIALS secret
```

Example (non-interactive):

```bash
./scripts/create-service-principal.sh --subscription-id $(az account show --query id -o tsv) --name my-sp --output my-creds.json --yes
```

### 2. Configure GitHub Repository Secrets

1. Open your GitHub repository
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Create the following secrets and repository variables:

   - `AZURE_CREDENTIALS` (secret)

     - Value: The entire JSON output from step 1

   - `AZURE_SUBSCRIPTION_ID` (repository Variable)

     - Value: Your Azure subscription ID (e.g., `12345678-1234-1234-1234-123456789abc`)

   - `AZURE_RESOURCE_GROUP_NAME` (repository Variable)
     - Value: Name for your resource group (e.g., `simple-react-router-rg`)

Note: this workflow requires `AZURE_RESOURCE_GROUP_NAME` to be a repository Variable (not a secret). Set it under Settings → Variables → Actions.

### 3. Update Workflow Configuration (Optional)

1. Open `.github/workflows/azure-webapp-deploy.yml` in your repository
2. Find the `env` section at the top of the file
3. Optionally update the following values:

   ```yaml
   env:
     # NOTE: The workflow requires `AZURE_WEBAPP_NAME` to be set as a repository Variable.
     AZURE_WEBAPP_NAME: <your-webapp-name>
     AZURE_WEBAPP_PACKAGE_PATH: "dev/dist"
     NODE_VERSION: "22.x"
     AZURE_LOCATION: "eastus" # Azure region
     APP_SERVICE_PLAN_SKU: "F1" # F1=Free, B1=Basic, S1=Standard
   ```

   The workflow will default the resource group name to `simple-react-router-rg` if the repository Variable `AZURE_RESOURCE_GROUP_NAME` is not set.

4. Commit and push the changes

### 4. Deploy

The workflow is configured to run automatically on:

- Every push to the `main` branch
- Manual trigger via GitHub Actions UI

To manually trigger:

1. Go to your repository on GitHub
2. Click on the "Actions" tab
3. Select "Deploy to Azure Web App" workflow
4. Click "Run workflow" button
5. Select the branch and click "Run workflow"

The deployment process will:

1. **Provision Infrastructure**: Deploy Bicep template to create/update Azure resources
2. **Build Application**: Install dependencies, run tests, and build the demo app
3. **Deploy to Azure**: Deploy the built application to the Azure Web App

### 5. Verify Deployment

1. Once the workflow completes, go to your Azure Web App URL
2. The URL format is: `https://{AZURE_WEBAPP_NAME}.azurewebsites.net`
3. You should see the Simple React Router demo application running
4. You can also view the deployed resources in the Azure Portal under your resource group

## Workflow Details

The GitHub Actions workflow (`.github/workflows/azure-webapps-deploy.yml`) performs the following:

### Infrastructure Job

- Checks out the code
- Logs in to Azure using service principal credentials
- Creates or updates the resource group
- Deploys the Bicep template to provision Azure resources:
  - App Service Plan (Linux-based)
  - Web App (Node.js 22 LTS)
- Outputs the web app name for subsequent jobs

### Build Job

- Checks out the code
- Sets up Node.js 22.x
- Installs dependencies
- Runs tests to ensure code quality
- Builds the TypeScript library
- Builds the demo application for production
- Uploads build artifacts

### Deploy Job

- Downloads build artifacts
- Logs in to Azure using service principal credentials
- Deploys to Azure Web App using the web app name from infrastructure job
- Sets up the production environment

## Important Files

- **`.github/workflows/azure-webapps-deploy.yml`**: GitHub Actions workflow definition
- **`infrastructure/main.bicep`**: Bicep template for Azure infrastructure (App Service Plan and Web App)
- **`dev/web.config`**: IIS configuration for Azure App Service (handles SPA routing)
- **`vite.config.ts`**: Vite configuration that includes plugin to copy web.config to build output

## Troubleshooting

### Infrastructure Deployment Fails

- Verify the `AZURE_CREDENTIALS` secret is correctly configured
- Ensure the service principal has Contributor access to the subscription
- Check that the `AZURE_SUBSCRIPTION_ID` repository Variable and `AZURE_RESOURCE_GROUP_NAME` repository Variable are set
- Review the GitHub Actions logs for specific error messages
- Verify the web app name is globally unique (Bicep adds a unique suffix by default)

### Authentication Fails

- Ensure the service principal credentials haven't expired
- Verify the `AZURE_CREDENTIALS` secret contains valid JSON
- Check that the service principal has the required permissions

### Deployment Fails

- Verify the infrastructure job completed successfully
- Check that the web app was created in the Azure Portal
- Review the GitHub Actions logs for specific error messages

### Routes Not Working (404 errors)

- Ensure `web.config` is present in the deployed files
- Check Azure App Service logs in the Azure Portal

### Application Not Loading

- Check the Azure App Service logs in Azure Portal under "Monitoring" > "Log stream"
- Verify the build artifacts include `index.html` and assets

### Build Fails

- Check that all dependencies are listed in `package.json`
- Verify Node.js version compatibility
- Review test failures in the GitHub Actions logs

## Local Testing

To test the production build locally:

```bash
# Build the demo app
npm run build:demo

# Serve the built files (using any static server)
npx serve dev/dist
```

## Customization

### Change Azure Region

Update the `AZURE_LOCATION` environment variable in the workflow file:

```yaml
env:
  AZURE_LOCATION: "westus2" # or 'eastus', 'westeurope', etc.
```

### Change App Service Plan Tier

Update the `APP_SERVICE_PLAN_SKU` environment variable:

```yaml
env:
  APP_SERVICE_PLAN_SKU: "B1" # F1=Free, B1=Basic, S1=Standard, P1V2=Premium
```

Or modify the Bicep template (`infrastructure/main.bicep`) to add more SKU options.

### Change Node.js Version

Update the `NODE_VERSION` environment variable in the workflow file:

```yaml
env:
  NODE_VERSION: "22.x" # or '18.x', '20.x'
```

And update the `nodeVersion` parameter in the infrastructure deployment step:

```yaml
parameters: >
  nodeVersion=22-lts  # or 18-lts, 20-lts
```

### Change Build Output Path

Update the `AZURE_WEBAPP_PACKAGE_PATH` environment variable:

```yaml
env:
  AZURE_WEBAPP_PACKAGE_PATH: "your/custom/path"
```

### Modify Deployment Trigger

Edit the `on` section in the workflow file. For example, to deploy on release:

```yaml
on:
  release:
    types: [published]
  workflow_dispatch:
```

### Customize Azure Resources

Edit `infrastructure/main.bicep` to customize the Azure resources. You can add:

- Application Insights for monitoring
- Azure CDN for content delivery
- Custom domains and SSL certificates
- Environment-specific configurations

## Cost Considerations

- **Free Tier**: Suitable for testing and demos, includes 60 CPU minutes per day
- **Basic Tier**: Starting at ~$13/month, includes custom domain and SSL
- **Standard Tier**: Starting at ~$75/month, includes auto-scaling and deployment slots

For production applications, consider using Standard tier or higher for better performance and features.

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [GitHub Actions for Azure](https://github.com/Azure/actions)
- [Azure Web Apps Deploy Action](https://github.com/Azure/webapps-deploy)
