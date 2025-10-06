# Infrastructure as Code (Bicep)

This directory contains the Bicep templates for provisioning Azure resources needed for the Simple React Router demo application.

## Files

- **`main.bicep`**: Main Bicep template that defines Azure resources
- **`main.parameters.json`**: Parameter file with default values (optional, values can be passed via workflow)

## Resources Provisioned

The Bicep template creates the following Azure resources:

1. **App Service Plan** (Linux-based)
   - SKU: Configurable (Default: F1 - Free tier)
   - OS: Linux
   - Reserved: true (required for Linux)

2. **Web App** (App Service)
   - Runtime: Node.js 22 LTS
   - Platform: Linux
   - HTTPS Only: Enabled
   - Always On: Enabled (except on Free tier)

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `webAppName` | string | Name of the web app | `simple-react-router-{uniqueString}` |
| `location` | string | Azure region for resources | Resource group location |
| `appServicePlanSku` | string | App Service Plan pricing tier | `F1` (Free) |
| `nodeVersion` | string | Node.js version | `22-lts` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `webAppName` | string | The name of the deployed web app |
| `webAppUrl` | string | The URL of the deployed web app |
| `webAppId` | string | The resource ID of the web app |

## Deployment

### Via GitHub Actions (Recommended)

The workflow automatically deploys this template when you push to the `main` branch. See [DEPLOYMENT.md](../DEPLOYMENT.md) for setup instructions.

### Manual Deployment via Azure CLI

```bash
# Create resource group
az group create --name simple-react-router-rg --location eastus

# Deploy Bicep template
az deployment group create \
  --resource-group simple-react-router-rg \
  --template-file main.bicep \
  --parameters webAppName=my-react-router-app \
               appServicePlanSku=F1 \
               nodeVersion=22-lts
```

### Validate Template

```bash
az deployment group validate \
  --resource-group simple-react-router-rg \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Customization

### Add Application Insights

Add the following to `main.bicep`:

```bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${webAppName}-insights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

// Add to Web App appSettings
{
  name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
  value: appInsights.properties.InstrumentationKey
}
```

### Add Custom Domain

Add the following to `main.bicep`:

```bicep
resource customDomain 'Microsoft.Web/sites/hostNameBindings@2023-01-01' = {
  parent: webApp
  name: 'www.yourdomain.com'
  properties: {
    siteName: webApp.name
    hostNameType: 'Verified'
  }
}
```

### Change to Premium Tier with Autoscale

```bicep
param appServicePlanSku string = 'P1V2'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: appServicePlanSku
    capacity: 1
  }
  properties: {
    reserved: true
  }
}
```

## Best Practices

1. **Use Unique Names**: The template uses `uniqueString()` to ensure globally unique resource names
2. **Enable HTTPS**: The template enforces HTTPS-only connections
3. **Use Tags**: Add tags for better resource management and cost tracking
4. **Separate Environments**: Use different resource groups for dev, staging, and production
5. **Monitor Costs**: Free tier is limited; upgrade only when needed

## Learn More

- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service on Linux](https://docs.microsoft.com/azure/app-service/overview)
- [Best practices for Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
