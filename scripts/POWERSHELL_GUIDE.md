# PowerShell Database Scripts Guide

This guide explains how to use the PowerShell versions of the database initialization and configuration scripts.

## Available Scripts

1. **initialize-database.ps1** - Creates database schema and sample data
2. **configure-managed-identity.ps1** - Grants managed identity access to the database

## Prerequisites

### 1. Install PowerShell Core (if not already installed)

**Linux (Ubuntu/Debian):**

```bash
# Download the Microsoft repository GPG keys
wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb

# Register the Microsoft repository GPG keys
sudo dpkg -i packages-microsoft-prod.deb

# Update the list of products
sudo apt-get update

# Install PowerShell
sudo apt-get install -y powershell

# Start PowerShell
pwsh
```

**macOS:**

```bash
brew install --cask powershell
```

**Windows:**
PowerShell is pre-installed. Make sure you're using PowerShell 7+ (not Windows PowerShell 5.1).

### 2. Verify PowerShell Installation

```bash
pwsh --version
# Should show PowerShell 7.x or later
```

## Usage

### Basic Usage

The scripts support two authentication methods:

**Option 1: Use existing Azure session (recommended for local development)**

```powershell
# Login to Azure first
Connect-AzAccount

# Run the script - it will use your existing session
pwsh ./scripts/initialize-database.ps1 `
  -ResourceGroup "your-resource-group" `
  -SqlServer "your-sql-server" `
  -DatabaseName "your-database"
```

**Option 2: Use credentials file (for CI/CD or automation)**

```powershell
# No login needed - script reads from azure-credentials.json
pwsh ./scripts/initialize-database.ps1 `
  -ResourceGroup "your-resource-group" `
  -SqlServer "your-sql-server" `
  -DatabaseName "your-database"
```

### Using from Bash Terminal

You can also run PowerShell scripts from bash:

```bash
pwsh -File ./scripts/initialize-database.ps1 \
  -ResourceGroup "your-resource-group" \
  -SqlServer "your-sql-server" \
  -DatabaseName "your-database"
```

### With Custom Credentials File

```powershell
pwsh ./initialize-database.ps1 `
  -ResourceGroup "simple-react-router-rg" `
  -SqlServer "simple-react-router-web-sql" `
  -DatabaseName "UsersDB" `
  -CredentialsFile "/path/to/custom/credentials.json"
```

## How It Works

The script performs these steps automatically:

1. **Check for Existing Azure Session**: Looks for an active Azure login (via `Get-AzContext`)
2. **Flexible Authentication**:
   - If already logged in → Uses your existing session
   - If not logged in → Reads credentials from `azure-credentials.json`
3. **Check Modules**: Verifies required PowerShell modules are installed
   - `Az.Accounts` - For Azure authentication
   - `SqlServer` - For SQL Server operations
3. **Install Missing Modules**: Automatically installs any missing modules
4. **Azure Login**: Authenticates to Azure using the service principal
5. **Get Access Token**: Acquires an Azure AD access token for SQL Database
6. **Execute SQL**: Runs the database initialization SQL script
7. **Create Schema**: Creates the Users table if it doesn't exist
8. **Insert Data**: Adds sample users if the table is empty
9. **Cleanup**: Disconnects from Azure

## Advantages Over Bash Version

### Cross-Platform Support

- ✅ Works on Windows, Linux, and macOS
- ✅ No need for bash-specific tools or workarounds
- ✅ Consistent behavior across all platforms

### Better Error Handling

```powershell
# PowerShell provides structured exception handling
try {
    Invoke-Sqlcmd -ServerInstance $server -Database $db -Query $sql
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Inner Exception: $($_.Exception.InnerException.Message)"
    exit 1
}
```

### Rich Output

- Colored console output for better visibility
- Structured error messages
- Progress indicators
- Verbose logging options

### Official Microsoft Modules

- Uses `SqlServer` module maintained by Microsoft
- Direct integration with Azure PowerShell modules
- No need for external dependencies like Python/pyodbc

### Automatic Dependency Management

- Checks for required modules
- Installs missing modules automatically
- No manual pip install or apt-get commands needed

## Troubleshooting

### Module Installation Issues

If module installation fails due to permissions:

```powershell
# Install modules for current user only
Install-Module -Name Az.Accounts -Scope CurrentUser -Force
Install-Module -Name SqlServer -Scope CurrentUser -Force
```

### Connection Issues

If you get "Cannot open server" errors:

1. **Check firewall rules:**

```bash
az sql server firewall-rule list \
  --resource-group your-rg \
  --server your-server
```

2. **Add your IP address:**

```bash
az sql server firewall-rule create \
  --resource-group your-rg \
  --server your-server \
  --name AllowMyIP \
  --start-ip-address $(curl -s ifconfig.me) \
  --end-ip-address $(curl -s ifconfig.me)
```

### Token Expiration

Access tokens expire after 1 hour. If your script takes longer or you're debugging:

```powershell
# Get a fresh token
$token = (Get-AzAccessToken -ResourceUrl "https://database.windows.net/").Token
```

### Verbose Output

For debugging, run with verbose output:

```powershell
pwsh ./initialize-database.ps1 `
  -ResourceGroup "your-rg" `
  -SqlServer "your-server" `
  -DatabaseName "your-db" `
  -Verbose
```

## Comparison: Bash vs PowerShell

| Feature               | Bash Script                 | PowerShell Script                 |
| --------------------- | --------------------------- | --------------------------------- |
| **Cross-platform**    | ✅ Linux/macOS native       | ✅ All platforms                  |
| **Windows native**    | ❌ Requires WSL/Git Bash    | ✅ Native support                 |
| **Dependencies**      | Python, pyodbc, ODBC Driver | PowerShell modules (auto-install) |
| **Error handling**    | Basic exit codes            | Structured exceptions             |
| **Output formatting** | Plain text                  | Rich, colored output              |
| **Module ecosystem**  | External (pip)              | Native PowerShell Gallery         |
| **Azure integration** | Via Azure CLI               | Native Az modules                 |
| **SQL execution**     | Python/pyodbc               | SqlServer module                  |
| **Learning curve**    | Bash syntax                 | PowerShell syntax                 |

## Integration with GitHub Actions

You can use the PowerShell script in GitHub Actions workflows:

```yaml
- name: Initialize Database with PowerShell
  shell: pwsh
  run: |
    ./scripts/initialize-database.ps1 `
      -ResourceGroup "${{ env.RESOURCE_GROUP }}" `
      -SqlServer "${{ env.SQL_SERVER }}" `
      -DatabaseName "${{ env.DATABASE_NAME }}"
```

## Example Output

```
============================================
Initializing Database Schema
============================================
Resource Group: simple-react-router-rg
SQL Server: simple-react-router-web-sql
Database: UsersDB
============================================

Reading Azure credentials from: /workspaces/simple-react-router/azure-credentials.json
Checking required PowerShell modules...
✓ Az.Accounts module is already installed
✓ SqlServer module is already installed
Importing required modules...

Logging in to Azure with service principal...
✓ Successfully logged in to Azure
Acquiring Azure AD access token for SQL Database authentication...
✓ Successfully acquired access token

Executing database initialization script...

Created Users table
Adding sample users to database...
Sample users added successfully
Database initialization completed

============================================
✓ Database initialized successfully!
============================================

The database schema has been created and sample data has been added.
The application can now connect and use the database.

Script completed successfully.
```

## Additional Resources

- [PowerShell Documentation](https://docs.microsoft.com/powershell/)
- [SqlServer Module Documentation](https://docs.microsoft.com/sql/powershell/sql-server-powershell)
- [Az.Accounts Module](https://docs.microsoft.com/powershell/module/az.accounts/)
- [Az.Websites Module](https://docs.microsoft.com/powershell/module/az.websites/)
- [Azure SQL Database Documentation](https://docs.microsoft.com/azure/sql-database/)

## Configure Managed Identity Script

The `configure-managed-identity.ps1` script is used to grant your Web App's managed identity access to the SQL Database.

### Usage

```powershell
pwsh ./scripts/configure-managed-identity.ps1 `
  -ResourceGroup "simple-react-router-rg" `
  -SqlServer "simple-react-router-web-sql" `
  -DatabaseName "UsersDB" `
  -WebAppName "simple-react-router-web"
```

### What It Does

1. **Retrieves Managed Identity**: Gets the Web App's system-assigned managed identity principal ID
2. **Authenticates**: Logs in to Azure using service principal credentials
3. **Creates Database User**: Creates a user in the database for the managed identity
4. **Grants Permissions**: Assigns database roles:
   - `db_datareader` - Read data from tables
   - `db_datawriter` - Write data to tables
   - `db_ddladmin` - Modify database schema
5. **Verifies**: Confirms the user was created successfully

### Example Output

```
============================================
Configuring Managed Identity Database Access
============================================
Resource Group: simple-react-router-rg
SQL Server: simple-react-router-web-sql
Database: UsersDB
Web App: simple-react-router-web
============================================

Reading Azure credentials from: /workspaces/simple-react-router/azure-credentials.json
Checking required PowerShell modules...
✓ Az.Accounts module is already installed
✓ Az.Websites module is already installed
✓ SqlServer module is already installed
Importing required modules...

Logging in to Azure with service principal...
✓ Successfully logged in to Azure

Retrieving managed identity details...
✓ Managed Identity Principal ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Acquiring Azure AD access token for SQL Database authentication...
✓ Successfully acquired access token

Executing SQL commands to grant managed identity access...

SUCCESS: Created user for managed identity: simple-react-router-web
Principal ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Granted db_datareader role to simple-react-router-web
Granted db_datawriter role to simple-react-router-web
Granted db_ddladmin role to simple-react-router-web
Successfully configured managed identity access for simple-react-router-web

Verifying user creation...
✓ User verified in database: simple-react-router-web

============================================
✓ Managed identity access configured successfully!
============================================

The Web App 'simple-react-router-web' now has the following permissions:
  - db_datareader: Read data from all tables
  - db_datawriter: Write data to all tables
  - db_ddladmin: Create and modify database schema

The application can now connect to the database using its managed identity.

Script completed successfully.
```

### Required Modules

The script automatically installs these modules if missing:

- `Az.Accounts` - Azure authentication
- `Az.Websites` - Web App management
- `SqlServer` - SQL Server operations

### Common Issues

**Error: "Could not retrieve managed identity principal ID"**

- Solution: Ensure the Web App has a system-assigned managed identity enabled

**Error: "Azure AD admin is not configured on SQL Server"**

- Solution: Run the `configure-azuread-admin.sh` script first

**Error: "The managed identity does not exist in Azure AD"**

- Solution: Wait a few minutes for the managed identity to propagate in Azure AD
