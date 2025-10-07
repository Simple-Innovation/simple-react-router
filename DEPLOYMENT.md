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

````

Alternatives (preferred when available)

- Official Microsoft installer (requires sudo in the environment):

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
````

- Install via pip (user install):

```bash
python3 -m pip install --user azure-cli
```

Use these alternatives if you need the officially supported distribution or run into npm package limitations.

## Setup Steps

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

### 2. Configure GitHub Repository Secrets

1. Open your GitHub repository
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Create the following secrets:

   **AZURE_CREDENTIALS**

   - Value: The entire JSON output from step 1

   **AZURE_SUBSCRIPTION_ID**

   - Value: Your Azure subscription ID (e.g., `12345678-1234-1234-1234-123456789abc`)

   **AZURE_RESOURCE_GROUP**

   - Value: Name for your resource group (e.g., `simple-react-router-rg`)

### 3. Update Workflow Configuration (Optional)

1. Open `.github/workflows/azure-webapps-deploy.yml` in your repository
2. Find the `env` section at the top of the file
3. Optionally update the following values:

   ```yaml
   env:
     AZURE_WEBAPP_NAME: simple-react-router # Your web app name
     AZURE_WEBAPP_PACKAGE_PATH: "dev/dist"
     NODE_VERSION: "22.x"
     AZURE_LOCATION: "eastus" # Azure region
     APP_SERVICE_PLAN_SKU: "F1" # F1=Free, B1=Basic, S1=Standard
   ```

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
- Check that the `AZURE_SUBSCRIPTION_ID` and `AZURE_RESOURCE_GROUP` secrets are set
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
