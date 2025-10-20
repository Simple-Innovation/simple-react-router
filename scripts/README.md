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
  <database-name>
```

**Parameters:**

- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)
- `database-name`: SQL Database name

**Example:**

```bash
./scripts/initialize-database.sh \
  simple-react-router-rg \
  simple-react-router-web-sql \
  UsersDB
```

**What it does:**

- Uses Azure AD authentication (reads from `azure-credentials.json` or uses current Azure CLI login)
- Creates the `Users` table if it doesn't exist
- Inserts sample user data if the table is empty
- Uses idempotent SQL commands (safe to run multiple times)

**When to use:**

- **Automatic**: This script runs automatically during GitHub Actions deployment (after managed identity configuration)
- **Manual deployments**: Run manually after deploying infrastructure with Bicep
- **Database reset**: Use to recreate the schema if needed

**Requirements:**

- Azure CLI must be installed and authenticated (`az login`)
- Python 3 with pyodbc package (automatically installed if missing)
- ODBC Driver 18 for SQL Server (automatically installed if missing)

### initialize-database.ps1

PowerShell version of the database initialization script. Provides better cross-platform support and richer error handling.

**Usage:**

```powershell
./scripts/initialize-database.ps1 `
  -ResourceGroup <resource-group> `
  -SqlServer <sql-server-name> `
  -DatabaseName <database-name>
```

**Parameters:**

- `-ResourceGroup`: Azure resource group name
- `-SqlServer`: SQL Server name (without .database.windows.net)
- `-DatabaseName`: SQL Database name
- `-CredentialsFile`: (Optional) Path to azure-credentials.json (default: ../azure-credentials.json)

**Example:**

```powershell
./scripts/initialize-database.ps1 `
  -ResourceGroup "simple-react-router-rg" `
  -SqlServer "simple-react-router-web-sql" `
  -DatabaseName "UsersDB"
```

**What it does:**

- Reads service principal credentials from `azure-credentials.json`
- Authenticates to Azure using the service principal
- Acquires Azure AD access token for SQL Database
- Executes SQL commands using PowerShell's SqlServer module
- Creates the `Users` table if it doesn't exist
- Inserts sample user data if the table is empty

**Advantages over Bash version:**

- Native cross-platform support (Windows, Linux, macOS)
- Better structured error handling
- Rich object output and formatting
- Uses official Microsoft SqlServer module
- Automatic module installation

**When to use:**

- **Windows environments**: Preferred on Windows systems
- **Cross-platform**: Works on any system with PowerShell Core
- **CI/CD**: Alternative to Bash script in Azure DevOps or GitHub Actions
- **Local development**: Easier to debug and test locally

**Requirements:**

- PowerShell 7+ (PowerShell Core)
- Az.Accounts module (automatically installed if missing)
- SqlServer module (automatically installed if missing)
- `azure-credentials.json` file in repository root

### configure-azuread-admin.sh

Configures Azure AD administrator for SQL Server to enable Azure AD authentication.

**⚠️ IMPORTANT:** Before running this script, you **must** first run `grant-sql-directory-reader.sh` to grant the SQL Server's identity Directory Readers permissions.

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

- **Step 2** in the post-deployment Azure AD setup process (after `grant-sql-directory-reader.sh`)
- Run this 5-10 minutes after granting Directory Readers role to allow Azure AD changes to propagate

**Requirements:**

- Azure CLI must be installed and authenticated (`az login`)
- SQL Server must have Directory Readers role (run `grant-sql-directory-reader.sh` first)
- User running the script needs sufficient permissions to modify SQL Server settings

### grant-sp-graph-permissions.sh

**NEW**: Grants Microsoft Graph API permissions to a service principal, specifically the `RoleManagement.ReadWrite.Directory` permission needed for automated Azure AD role assignments in CI/CD pipelines.

**⚠️ CRITICAL:** This is a **prerequisite for automated deployment**. The service principal used by GitHub Actions needs this permission to automatically grant the Directory Readers role to SQL Server during deployment.

**Usage:**

```bash
./scripts/grant-sp-graph-permissions.sh <service-principal-app-id>
```

**Parameters:**

- `service-principal-app-id`: The application (client) ID of your service principal

**Example:**

```bash
./scripts/grant-sp-graph-permissions.sh 66868a16-6798-455c-bb79-f53a52e8fa16
```

**What it does:**

- Looks up your service principal by App ID
- Retrieves the Microsoft Graph service principal and the RoleManagement.ReadWrite.Directory permission ID
- Checks if the permission is already granted
- Grants the permission if not already present
- Provides verification commands to confirm the grant

**When to use:**

- **During initial setup** before running GitHub Actions deployment workflow
- When you want to enable fully automated deployment without manual intervention
- If you see errors about insufficient permissions to grant Directory Readers role

**Requirements:**

- Azure CLI must be installed and authenticated (`az login`)
- **Global Administrator** or **Application Administrator** role in Azure AD
- Permission to grant admin consent for API permissions

**Alternative methods:**

If you don't have sufficient permissions or prefer a different method, see the detailed guide:

- **[GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md](../GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md)** - Complete guide with Azure Portal and PowerShell methods

**Why is this needed?**

This permission allows the service principal (used by GitHub Actions) to:

- Read directory roles and role templates
- Activate directory role templates (like "Directory Readers")
- Assign managed identities to directory roles
- Automate the Azure AD setup that would otherwise require manual intervention

Without this permission, the GitHub Actions workflow will fail when trying to grant the Directory Readers role to SQL Server, and you'll need to run `grant-sql-directory-reader.sh` manually as an administrator.

### grant-sql-directory-reader.sh

**NEW**: Grants the SQL Server's managed identity the "Directory Readers" role in Azure AD, which is **required** for the SQL Server to resolve other Azure AD principals.

**⚠️ CRITICAL:** This is the **first step** in configuring Azure AD authentication. Without this, you will get the error: `Principal could not be resolved. Error message: 'Server identity is not configured...'`

**Usage:**

```bash
./scripts/grant-sql-directory-reader.sh \
  <resource-group> \
  <sql-server-name>
```

**Parameters:**

- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)

**Example:**

```bash
./scripts/grant-sql-directory-reader.sh \
  simple-react-router-rg \
  simple-react-router-web-sql
```

**What it does:**

- Retrieves the SQL Server's system-assigned managed identity principal ID
- Checks if the identity already has Directory Readers role
- Grants the "Directory Readers" Azure AD role to the SQL Server's identity
- Enables the SQL Server to look up and resolve other Azure AD principals

**When to use:**

- **Step 1** in the post-deployment Azure AD setup process
- **Required before** running `configure-azuread-admin.sh`
- Run immediately after infrastructure deployment

**Requirements:**

- Azure CLI must be installed and authenticated (`az login`)
- **Global Administrator** or **Privileged Role Administrator** role in Azure AD
- SQL Server must have a system-assigned managed identity (automatically created by Bicep)

**If you don't have sufficient permissions:**

Ask your Azure AD administrator to either:

- Run this script for you
- Manually grant the "Directory Readers" role to your SQL Server's managed identity principal ID
- Temporarily grant you the "Privileged Role Administrator" role

**Why is this needed?**

Azure SQL Server needs Directory Readers permissions to:

- Look up Azure AD principals by their object ID
- Validate Azure AD authentication tokens
- Create database users from external providers (managed identities)

This cannot be automated in the Bicep template because it requires Azure AD Graph API calls and special Azure AD admin permissions.

### configure-managed-identity.sh

Automatically configures managed identity access to Azure SQL Database by granting the Web App's system-assigned identity the necessary database permissions.

**⚠️ IMPORTANT:** Before running this script, you must complete Steps 1 and 2:

1. Run `grant-sql-directory-reader.sh` (requires Azure AD admin)
2. Run `configure-azuread-admin.sh` (wait 5-10 minutes after Step 1)
3. Then run this script (wait 5-10 minutes after Step 2)

**Usage:**

```bash
./scripts/configure-managed-identity.sh \
  <resource-group> \
  <sql-server-name> \
  <database-name> \
  <web-app-name>
```

**Parameters:**

- `resource-group`: Azure resource group name
- `sql-server-name`: SQL Server name (without .database.windows.net)
- `database-name`: SQL Database name
- `web-app-name`: Web App name (used as the managed identity name)

**Example:**

```bash
./scripts/configure-managed-identity.sh \
  simple-react-router-rg \
  simple-react-router-web-sql \
  UsersDB \
  simple-react-router-web
```

**What it does:**

- Uses Azure AD authentication (requires current Azure CLI login)
- Retrieves the Web App's managed identity principal ID
- Creates a database user for the managed identity
- Grants `db_datareader` role (read data from all tables)
- Grants `db_datawriter` role (write data to all tables)
- Grants `db_ddladmin` role (create and modify database schema)
- Uses idempotent SQL commands (safe to run multiple times)

**When to use:**

- **Step 3** in the post-deployment Azure AD setup process

- **Local development**: Use to grant your Azure account access to the database (replace web-app-name with your email)

**Requirements:**

- Azure CLI must be installed and authenticated (`az login`)
- SQL Server must have Azure AD authentication enabled
- The Web App must have a system-assigned managed identity enabled
- Python 3 with pyodbc package (automatically installed if missing)
- ODBC Driver 18 for SQL Server (automatically installed if missing)

**Notes:**

- This script is idempotent - safe to run multiple times without creating duplicates
- The script automatically checks if permissions are already granted before applying them
- For local development, follow the instructions in DATABASE_SETUP.md to grant your Azure account access

### configure-managed-identity.ps1

PowerShell version of the managed identity configuration script. Provides better cross-platform support and richer error handling.

**Usage:**

```powershell
./scripts/configure-managed-identity.ps1 `
  -ResourceGroup <resource-group> `
  -SqlServer <sql-server-name> `
  -DatabaseName <database-name> `
  -WebAppName <web-app-name>
```

**Parameters:**

- `-ResourceGroup`: Azure resource group name
- `-SqlServer`: SQL Server name (without .database.windows.net)
- `-DatabaseName`: SQL Database name
- `-WebAppName`: Web App name (used as the managed identity name)
- `-CredentialsFile`: (Optional) Path to azure-credentials.json (default: ../azure-credentials.json)

**Example:**

```powershell
./scripts/configure-managed-identity.ps1 `
  -ResourceGroup "simple-react-router-rg" `
  -SqlServer "simple-react-router-web-sql" `
  -DatabaseName "UsersDB" `
  -WebAppName "simple-react-router-web"
```

**What it does:**

- Reads service principal credentials from `azure-credentials.json`
- Authenticates to Azure using the service principal
- Retrieves the Web App's managed identity principal ID
- Acquires Azure AD access token for SQL Database
- Creates a database user for the managed identity
- Grants database roles (db_datareader, db_datawriter, db_ddladmin)
- Verifies the user was created successfully

**Advantages over Bash version:**

- Native cross-platform support (Windows, Linux, macOS)
- Better structured error handling with detailed messages
- Uses official Microsoft SqlServer and Az.Websites modules
- Automatic module installation
- Richer verification and validation

**When to use:**

- **Windows environments**: Preferred on Windows systems
- **Cross-platform**: Works on any system with PowerShell Core
- **CI/CD**: Alternative to Bash script in Azure DevOps or GitHub Actions
- **Local development**: Easier to debug and test locally

**Requirements:**

- PowerShell 7+ (PowerShell Core)
- Az.Accounts module (automatically installed if missing)
- Az.Websites module (automatically installed if missing)
- SqlServer module (automatically installed if missing)
- `azure-credentials.json` file in repository root
