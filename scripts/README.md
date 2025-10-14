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

**Notes:**
- This script is idempotent - safe to run multiple times without creating duplicates
- The script automatically checks if permissions are already granted before applying them
- For local development, follow the instructions in DATABASE_SETUP.md to grant your Azure account access
