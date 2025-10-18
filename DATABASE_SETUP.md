# Azure SQL Database Setup Guide

This guide provides step-by-step instructions for setting up and configuring the Azure SQL Database for the Simple React Router application.

## Prerequisites

- Azure subscription
- Azure CLI installed (optional, for manual deployment)
- SQL Server Management Studio (SSMS) or Azure Data Studio (optional, for database management)

## Deployment Steps

### 1. Deploy Infrastructure

Deploy the Bicep template with a secure SQL admin password:

```bash
az deployment group create \
  --resource-group simple-react-router-rg \
  --template-file infrastructure/main.bicep \
  --parameters webAppName=my-react-router-app \
               sqlAdminPassword='YourSecurePassword123!'
```

**Note**: Replace `YourSecurePassword123!` with a strong password that meets Azure SQL requirements:

- Minimum 8 characters
- Contains uppercase letters
- Contains lowercase letters
- Contains numbers
- Contains special characters

### 2. Configure Managed Identity Access (Automated)

**When using GitHub Actions deployment**, this step is now **automatically configured** during deployment! The workflow runs a script that grants the Web App's managed identity the necessary database permissions.

**For manual deployments**, you can run the configuration script:

```bash
# From the repository root
bash ./scripts/configure-managed-identity.sh \
  <resource-group> \
  <sql-server-name> \
  <database-name> \
  <web-app-name> \
  <sql-admin-login> \
  <sql-admin-password>
```

**Alternatively, you can manually grant permissions** using SQL:

```sql
-- Connect to your SQL Database using Azure portal Query Editor or SSMS
-- Use the SQL admin credentials you provided during deployment

-- Create a user for the Web App's managed identity
CREATE USER [your-web-app-name] FROM EXTERNAL PROVIDER;

-- Grant necessary permissions
ALTER ROLE db_datareader ADD MEMBER [your-web-app-name];
ALTER ROLE db_datawriter ADD MEMBER [your-web-app-name];
ALTER ROLE db_ddladmin ADD MEMBER [your-web-app-name];
```

Replace `[your-web-app-name]` with the actual name of your Web App (e.g., `simple-react-router-abc123`).

### 3. Verify Deployment

1. Navigate to your Web App URL (available in deployment outputs)
2. Click on "Users List" in the navigation
3. You should see the sample users from the database

## Alternative: Using Azure Portal

### Step 1: Deploy Infrastructure

1. Open Azure Portal
2. Navigate to "Deploy a custom template"
3. Click "Build your own template in the editor"
4. Copy the contents of `infrastructure/main.bicep`
5. Fill in the parameters, including a secure `sqlAdminPassword`
6. Review and create

### Step 2: Grant Managed Identity Access

#### Option A: Using the automated script (Recommended)

Download or clone the repository and run:

```bash
bash ./scripts/configure-managed-identity.sh \
  <resource-group> \
  <sql-server-name> \
  <database-name> \
  <web-app-name> \
  <sql-admin-login> \
  <sql-admin-password>
```

#### Option B: Using Azure Portal Query Editor

1. Navigate to your SQL Server in Azure Portal
2. Click on "Databases" → Select your database
3. Click "Query editor (preview)" and sign in with SQL admin credentials
4. Run the SQL commands from Step 2 above

## Local Development Setup

**Security Note**: The application uses Azure Managed Identity authentication in production. For local development and database administration, both SQL authentication (with admin credentials) and Azure AD authentication are supported.

**Azure AD Authentication Setup**: During deployment, the workflow automatically configures an Azure AD administrator for the SQL Server, enabling Azure AD authentication. This allows you to connect using your Azure account credentials.

For local development, you can authenticate using Azure credentials:

### 1. Install and configure Azure CLI

```bash
# Install Azure CLI (if not already installed)
# See: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Login with your Azure account
az login
```

### 2. Grant your Azure account access to the database

Connect to the SQL Database using Azure portal Query Editor or SSMS with SQL admin credentials, then run:

```sql
-- Replace 'your-email@domain.com' with your Azure account email
CREATE USER [your-email@domain.com] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [your-email@domain.com];
ALTER ROLE db_datawriter ADD MEMBER [your-email@domain.com];
ALTER ROLE db_ddladmin ADD MEMBER [your-email@domain.com];
```

### 3. Configure environment variables

Create a `.env` file (not committed to git):

```bash
SQL_SERVER=your-server-name.database.windows.net
SQL_DATABASE=UsersDB
```

**Note**: No SQL_USER or SQL_PASSWORD needed - Azure Managed Identity is used automatically.

### 4. Allow your IP address

Add your development machine's IP to the SQL Server firewall:

```bash
az sql server firewall-rule create \
  --resource-group simple-react-router-rg \
  --server your-server-name \
  --name AllowMyIP \
  --start-ip-address YOUR_IP \
  --end-ip-address YOUR_IP
```

Or use Azure Portal:

1. Navigate to your SQL Server
2. Click "Networking"
3. Add your client IP address

### 5. Run the application

```bash
npm run dev:server  # Start Express server (port 8080)
npm run dev         # In another terminal, start Vite dev server (port 3000)
```

The application will use your Azure CLI credentials via `DefaultAzureCredential`.

Visit `http://localhost:3000` to see the application.

## Database Schema

The application automatically creates the following schema on first run:

```sql
CREATE TABLE Users (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Name NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    CreatedAt DATETIME2 DEFAULT GETDATE()
)
```

Sample data is also automatically inserted if the table is empty.

## Troubleshooting

### Issue: "The server is not currently configured to accept this token"

**Error**: When trying to connect via Azure Portal Query Editor with Azure AD authentication, you get:

```text
Microsoft Entra authentication
Login failed for user. The server is not currently configured to accept this token
```

**Solution**: The SQL Server needs an Azure AD administrator configured. Run the configuration script:

```bash
bash ./scripts/configure-azuread-admin.sh \
  <resource-group> \
  <sql-server-name>
```

This script runs automatically during GitHub Actions deployment. For manual deployments, you need to run it after infrastructure deployment, or configure the Azure AD admin via Azure Portal:

1. Navigate to your SQL Server in Azure Portal
2. Click "Microsoft Entra ID" in the left menu
3. Click "Set admin" and select your Azure AD user
4. Click "Save"

### Issue: "Database not initialized" error

**Solution**: Ensure the Web App has environment variables configured:

- `SQL_SERVER`
- `SQL_DATABASE`

These are automatically set by the Bicep template during deployment.

### Issue: "Login failed" error in production

**Solution**: Grant the managed identity access to the database using the SQL commands in Step 2.

### Issue: Authentication error in local development

**Solution**:

1. Ensure you are logged in to Azure CLI: `az login`
2. Verify your Azure account has been granted access to the database (see Local Development Setup, Step 2)
3. Check that your IP is allowed in SQL Server firewall rules
4. Confirm `DefaultAzureCredential` is finding your Azure CLI credentials

### Issue: "Cannot read config file" during npm run lint

**Solution**: This is a pre-existing issue with the ESLint configuration, not related to the database setup. The build and tests work correctly.

## Security Best Practices

1. **Managed Identity only** - SQL authentication is disabled for security compliance
2. **No credentials in code** - The application uses Azure Managed Identity exclusively
3. **Rotate SQL admin password** regularly (used only for initial setup and emergencies)
4. **Enable firewall rules** to restrict access to known IP addresses
5. **Enable auditing** on the SQL Database for compliance
6. **Use TLS 1.2+** for all connections (automatically configured)
7. **Review connection logs** regularly in Azure Portal
8. **Principle of least privilege** - Grant only necessary database permissions to managed identities

## Monitoring

Monitor your database in Azure Portal:

1. Navigate to your SQL Database
2. View metrics: DTU usage, storage, connections
3. Set up alerts for high resource usage
4. Review Query Performance Insights

## Cost Management

The template uses **Basic tier** by default:

- 5 DTUs
- 2 GB storage
- ~$5/month

For production workloads, consider upgrading to Standard or Premium tiers.

## Additional Resources

- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/azure-sql/)
- [Managed Identity for Azure SQL](https://docs.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)
- [SQL Database Pricing](https://azure.microsoft.com/pricing/details/sql-database/)
