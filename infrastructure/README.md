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

2. **SQL Server**
   - Version: 12.0 (SQL Server 2014 compatible)
   - TLS: Minimum version 1.2
   - Authentication: SQL authentication with configurable admin credentials

3. **SQL Database**
   - SKU: Basic tier (5 DTUs, 2GB)
   - Collation: SQL_Latin1_General_CP1_CI_AS
   - TLS encryption enabled
   - Azure services firewall rule enabled

4. **Web App** (App Service)
   - Runtime: Node.js 22 LTS
   - Platform: Linux
   - HTTPS Only: Enabled
   - Always On: Enabled (except on Free tier)
   - Managed Identity: System-assigned identity enabled for SQL authentication
   - Environment Variables: SQL connection details configured

## Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `webAppName` | string | Name of the web app | `simple-react-router-{uniqueString}` |
| `location` | string | Azure region for resources | Resource group location |
| `appServicePlanSku` | string | App Service Plan pricing tier | `F1` (Free) |
| `nodeVersion` | string | Node.js version | `22-lts` |
| `sqlAdminLogin` | string | SQL Server administrator login | `sqladmin` |
| `sqlAdminPassword` | secure string | SQL Server administrator password | *Required* |
| `sqlDatabaseName` | string | SQL Database name | `UsersDB` |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `webAppName` | string | The name of the deployed web app |
| `webAppUrl` | string | The URL of the deployed web app |
| `webAppId` | string | The resource ID of the web app |
| `sqlServerName` | string | The name of the SQL Server |
| `sqlServerFqdn` | string | The fully qualified domain name of the SQL Server |
| `sqlDatabaseName` | string | The name of the SQL Database |
| `webAppPrincipalId` | string | The principal ID of the web app's managed identity |

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
               nodeVersion=22-lts \
               sqlAdminPassword='YourSecurePassword123!'
```

**Important**: Always use a strong password for `sqlAdminPassword`. The password must:
- Be at least 8 characters long
- Contain characters from at least three categories: uppercase, lowercase, numbers, and symbols

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

## Database Setup

The template provisions an Azure SQL Database with the following features:

### Managed Identity Authentication (Required)

The Web App uses **Azure Managed Identity exclusively** to connect to the SQL Database:
- No credentials stored in application code or configuration
- SQL authentication is disabled for security compliance
- Azure automatically manages the identity lifecycle
- Token-based authentication with Azure Active Directory
- Enhanced security with automatic credential rotation

### Initial Setup Required

After deploying the infrastructure, you **must** grant the Web App's managed identity access to the database:

```sql
-- Connect to the SQL Database as admin
CREATE USER [your-web-app-name] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-web-app-name];
ALTER ROLE db_datawriter ADD MEMBER [your-web-app-name];
ALTER ROLE db_ddladmin ADD MEMBER [your-web-app-name];
```

Replace `your-web-app-name` with the actual name of your Web App.

### Database Initialization

The application automatically:
- Creates the required `Users` table on first run
- Populates sample data if the table is empty
- Handles schema migrations transparently

### Connection Details

The template automatically configures these environment variables on the Web App:
- `SQL_SERVER`: Fully qualified domain name of the SQL Server
- `SQL_DATABASE`: Database name

**Note**: SQL_USER and SQL_PASSWORD are no longer configured as the application uses Managed Identity exclusively for enhanced security.

## Best Practices

1. **Use Unique Names**: The template uses `uniqueString()` to ensure globally unique resource names
2. **Enable HTTPS**: The template enforces HTTPS-only connections
3. **Use Tags**: Add tags for better resource management and cost tracking
4. **Separate Environments**: Use different resource groups for dev, staging, and production
5. **Monitor Costs**: Free tier is limited; upgrade only when needed
6. **Secure Passwords**: Use strong, randomly generated passwords for SQL admin accounts (used only for setup)
7. **Managed Identity Only**: The application uses Azure Managed Identity exclusively - SQL authentication is disabled
8. **Backup Database**: Enable automated backups for production databases
9. **Grant Minimal Permissions**: Only grant necessary database roles to managed identities

## Learn More

- [Bicep Documentation](https://docs.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service on Linux](https://docs.microsoft.com/azure/app-service/overview)
- [Best practices for Bicep](https://docs.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
