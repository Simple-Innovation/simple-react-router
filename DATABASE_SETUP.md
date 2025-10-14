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

### 2. Configure Managed Identity Access (Recommended)

After deployment, grant the Web App's managed identity access to the database:

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
1. Navigate to your SQL Server in Azure Portal
2. Click on "Databases" → Select your database
3. Click "Query editor (preview)" and sign in with SQL admin credentials
4. Run the SQL commands from Step 2 above

## Local Development Setup

For local development, you can connect to the Azure SQL Database:

### 1. Create a .env file (not committed to git)

```bash
SQL_SERVER=your-server-name.database.windows.net
SQL_DATABASE=UsersDB
SQL_USER=sqladmin
SQL_PASSWORD=YourSecurePassword123!
```

### 2. Allow your IP address

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

### 3. Run the application

```bash
npm run dev:server  # Start Express server (port 8080)
npm run dev         # In another terminal, start Vite dev server (port 3000)
```

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

### Issue: "Database not initialized" error

**Solution**: Ensure the Web App has environment variables configured:
- `SQL_SERVER`
- `SQL_DATABASE`
- `SQL_USER`
- `SQL_PASSWORD`

These are automatically set by the Bicep template during deployment.

### Issue: "Login failed" error in production

**Solution**: Grant the managed identity access to the database using the SQL commands in Step 2.

### Issue: Cannot connect from local machine

**Solution**: 
1. Check that your IP is allowed in SQL Server firewall rules
2. Verify SQL authentication is enabled on the server
3. Ensure connection string details are correct

### Issue: "Cannot read config file" during npm run lint

**Solution**: This is a pre-existing issue with the ESLint configuration, not related to the database setup. The build and tests work correctly.

## Security Best Practices

1. **Never commit passwords or connection strings** to version control
2. **Use managed identity** in production instead of SQL authentication
3. **Rotate SQL admin password** regularly
4. **Enable firewall rules** to restrict access to known IP addresses
5. **Enable auditing** on the SQL Database for compliance
6. **Use TLS 1.2+** for all connections (automatically configured)
7. **Review connection logs** regularly in Azure Portal

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
