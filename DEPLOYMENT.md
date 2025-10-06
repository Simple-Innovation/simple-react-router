# Azure Web App Deployment Guide

This guide explains how to deploy the Simple React Router demo application to Azure Web App using GitHub Actions.

## Prerequisites

- An Azure account with an active subscription
- A GitHub repository with the Simple React Router code
- Admin access to the GitHub repository (to configure secrets)

## Setup Steps

### 1. Create an Azure Web App

1. Sign in to the [Azure Portal](https://portal.azure.com)
2. Click "Create a resource" and search for "Web App"
3. Click "Create" and fill in the following:
   - **Subscription**: Choose your subscription
   - **Resource Group**: Create new or use existing
   - **Name**: Choose a unique name (e.g., `simple-react-router-demo`)
   - **Publish**: Code
   - **Runtime stack**: Node 22 LTS
   - **Operating System**: Linux
   - **Region**: Choose your preferred region
4. Choose an appropriate pricing plan (Free tier works for testing)
5. Click "Review + create" and then "Create"
6. Wait for deployment to complete

### 2. Download Publish Profile

1. Navigate to your newly created Web App in the Azure Portal
2. In the left menu, click on "Overview"
3. In the top menu, click "Download publish profile"
4. Save the downloaded `.PublishSettings` file

### 3. Configure GitHub Repository Secret

1. Open your GitHub repository
2. Go to **Settings** > **Secrets and variables** > **Actions**
3. Click "New repository secret"
4. Name: `AZURE_WEBAPP_PUBLISH_PROFILE`
5. Value: Open the downloaded `.PublishSettings` file in a text editor and copy its entire contents
6. Click "Add secret"

### 4. Update Workflow Configuration

1. Open `.github/workflows/azure-webapps-deploy.yml` in your repository
2. Find the `env` section at the top of the file
3. Update the `AZURE_WEBAPP_NAME` value to match your Azure Web App name:
   ```yaml
   env:
     AZURE_WEBAPP_NAME: your-webapp-name    # Change this to your app name
     AZURE_WEBAPP_PACKAGE_PATH: 'dev/dist'
     NODE_VERSION: '22.x'
   ```
4. Commit and push the changes

### 5. Deploy

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
1. Install dependencies
2. Run tests
3. Build the library
4. Build the demo application
5. Deploy to Azure Web App

### 6. Verify Deployment

1. Once the workflow completes, go to your Azure Web App URL
2. The URL format is: `https://your-webapp-name.azurewebsites.net`
3. You should see the Simple React Router demo application running

## Workflow Details

The GitHub Actions workflow (`.github/workflows/azure-webapps-deploy.yml`) performs the following:

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
- Deploys to Azure Web App using the publish profile
- Sets up the production environment

## Important Files

- **`.github/workflows/azure-webapps-deploy.yml`**: GitHub Actions workflow definition
- **`dev/web.config`**: IIS configuration for Azure App Service (handles SPA routing)
- **`vite.config.ts`**: Vite configuration that includes plugin to copy web.config to build output

## Troubleshooting

### Deployment Fails
- Verify the `AZURE_WEBAPP_PUBLISH_PROFILE` secret is correctly configured
- Check that the `AZURE_WEBAPP_NAME` matches your Azure Web App name exactly
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

### Change Node.js Version
Update the `NODE_VERSION` environment variable in the workflow file:
```yaml
env:
  NODE_VERSION: '22.x'  # or '18.x', '20.x'
```

### Change Build Output Path
Update the `AZURE_WEBAPP_PACKAGE_PATH` environment variable:
```yaml
env:
  AZURE_WEBAPP_PACKAGE_PATH: 'your/custom/path'
```

### Modify Deployment Trigger
Edit the `on` section in the workflow file. For example, to deploy on release:
```yaml
on:
  release:
    types: [published]
  workflow_dispatch:
```

## Cost Considerations

- **Free Tier**: Suitable for testing and demos, includes 60 CPU minutes per day
- **Basic Tier**: Starting at ~$13/month, includes custom domain and SSL
- **Standard Tier**: Starting at ~$75/month, includes auto-scaling and deployment slots

For production applications, consider using Standard tier or higher for better performance and features.

## Additional Resources

- [Azure App Service Documentation](https://docs.microsoft.com/azure/app-service/)
- [GitHub Actions for Azure](https://github.com/Azure/actions)
- [Azure Web Apps Deploy Action](https://github.com/Azure/webapps-deploy)
