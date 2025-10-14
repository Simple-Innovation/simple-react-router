# Scripts

This directory contains utility scripts for managing the Simple React Router infrastructure and deployment.

## Available Scripts

### create-service-principal.sh

Creates an Azure service principal for GitHub Actions deployment.

**Usage:**
```bash
./scripts/create-service-principal.sh [options]
```

**Options:**
- `--subscription-id ID`: Azure subscription ID (defaults to active subscription)
- `--name NAME`: Service principal name (default: `simple-react-router-deploy`)
- `--role ROLE`: Role for the service principal (default: `contributor`)
- `--output FILE`: File to write the JSON credentials to (default: `azure-credentials.json`)
- `--set-secrets`: Automatically set secrets in GitHub using the gh CLI
- `--yes`: Skip confirmation prompt

**Example:**
```bash
./scripts/create-service-principal.sh \
  --subscription-id $(az account show --query id -o tsv) \
  --name my-sp \
  --output my-creds.json
```

### initialize-database.sh

Initializes the database schema by creating the Users table and inserting sample data if needed.

**Usage:**
```bash
./scripts/initialize-database.sh \
  <resource-group> \
  <sql-server-name> \
  <database-name> \
  <sql-admin-login> \
  <sql-admin-password>
```

**Parameters:**
- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)
- `database-name`: SQL Database name
- `sql-admin-login`: SQL Server administrator login
- `sql-admin-password`: SQL Server administrator password

**Example:**
```bash
./scripts/initialize-database.sh \
  simple-react-router-rg \
  simple-react-router-web-sql \
  UsersDB \
  sqladmin \
  'YourSecurePassword123!'
```

**What it does:**
- Creates the `Users` table if it doesn't exist
- Inserts sample user data if the table is empty
- Uses idempotent SQL commands (safe to run multiple times)

**When to use:**
- **Automatic**: This script runs automatically during GitHub Actions deployment (after managed identity configuration)
- **Manual deployments**: Run manually after deploying infrastructure with Bicep
- **Database reset**: Use to recreate the schema if needed

**Requirements:**
- `sqlcmd` utility (automatically installed by the script if not present)
- `sudo` access for installing `sqlcmd` (required in CI/CD environments)
- SQL Server administrator credentials

### configure-azuread-admin.sh

Configures Azure AD administrator for SQL Server to enable Azure AD authentication.

**Usage:**
```bash
./scripts/configure-azuread-admin.sh \
  <resource-group> \
  <sql-server-name> \
  [admin-user] \
  [admin-object-id]
```

**Parameters:**
- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)
- `admin-user`: (Optional) Azure AD admin user email or service principal name
- `admin-object-id`: (Optional) Object ID of the admin user

**Example:**
```bash
# Use current logged-in user as admin
./scripts/configure-azuread-admin.sh \
  simple-react-router-rg \
  simple-react-router-web-sql

# Specify a specific Azure AD user
./scripts/configure-azuread-admin.sh \
  simple-react-router-rg \
  simple-react-router-web-sql \
  user@example.com \
  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

**What it does:**
- Enables Azure AD authentication on the SQL Server
- Sets an Azure AD administrator for the SQL Server
- Allows users to connect using Azure AD credentials (via Portal Query Editor, SSMS, etc.)
- Required for CREATE USER ... FROM EXTERNAL PROVIDER to work

**When to use:**
- **Automatic**: This script runs automatically during GitHub Actions deployment (after infrastructure deployment)
- **Manual deployments**: Run manually after deploying infrastructure with Bicep
- **Troubleshooting**: Run if you get "The server is not currently configured to accept this token" error

**GitHub Actions Integration:**
When running in GitHub Actions, you can optionally specify the Azure AD admin via repository variables:
- `SQL_AZUREAD_ADMIN_USER`: Azure AD admin user email or service principal name
- `SQL_AZUREAD_ADMIN_OBJECT_ID`: Object ID of the admin user

If these variables are not set, the workflow will automatically use the current logged-in user (service principal).

**Requirements:**
- Azure CLI must be installed and authenticated (`az login`)
- User running the script needs sufficient permissions to modify SQL Server settings
- If not specifying admin-user/admin-object-id, script will use current logged-in user

### configure-managed-identity.sh

Automatically configures managed identity access to Azure SQL Database by granting the Web App's system-assigned identity the necessary database permissions.

**Usage:**
```bash
./scripts/configure-managed-identity.sh \
  <resource-group> \
  <sql-server-name> \
  <database-name> \
  <web-app-name> \
  <sql-admin-login> \
  <sql-admin-password>
```

**Parameters:**
- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)
- `database-name`: SQL Database name
- `web-app-name`: Web App name (used as the managed identity name)
- `sql-admin-login`: SQL Server administrator login
- `sql-admin-password`: SQL Server administrator password

**Example:**
```bash
./scripts/configure-managed-identity.sh \
  simple-react-router-rg \
  simple-react-router-web-sql \
  UsersDB \
  simple-react-router-web \
  sqladmin \
  'YourSecurePassword123!'
```

**What it does:**
- Creates a database user for the Web App's managed identity
- Grants `db_datareader` role (read data from all tables)
- Grants `db_datawriter` role (write data to all tables)
- Grants `db_ddladmin` role (create and modify database schema)
- Uses idempotent SQL commands (safe to run multiple times)

**When to use:**
- **Automatic**: This script runs automatically during GitHub Actions deployment
- **Manual deployments**: Run manually after deploying infrastructure with Bicep
- **Local development**: Use to grant your Azure account access to the database (replace web-app-name with your email)

**Requirements:**
- Azure CLI must be installed and authenticated (`az login`)
- SQL Server must have Azure AD authentication enabled
- The Web App must have a system-assigned managed identity enabled
- You must have the SQL admin credentials from deployment
- `sqlcmd` utility (automatically installed by the script if not present)
- `sudo` access for installing `sqlcmd` (required in CI/CD environments)

**Notes:**
- This script is idempotent - safe to run multiple times without creating duplicates
- The script automatically checks if permissions are already granted before applying them
- For local development, follow the instructions in DATABASE_SETUP.md to grant your Azure account access
