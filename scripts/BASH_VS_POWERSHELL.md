# Bash vs PowerShell Scripts Comparison

This document compares the Bash and PowerShell versions of the database configuration scripts.

## Scripts Overview

| Script                      | Bash Version                    | PowerShell Version               |
| --------------------------- | ------------------------------- | -------------------------------- |
| **Database Initialization** | `initialize-database.sh`        | `initialize-database.ps1`        |
| **Managed Identity Config** | `configure-managed-identity.sh` | `configure-managed-identity.ps1` |

## Feature Comparison

### initialize-database Scripts

| Feature                       | Bash (.sh)                                  | PowerShell (.ps1)                        |
| ----------------------------- | ------------------------------------------- | ---------------------------------------- |
| **Platform Support**          | Linux/macOS (WSL on Windows)                | Windows/Linux/macOS (native)             |
| **Authentication**            | Azure CLI + Python                          | Az.Accounts module                       |
| **SQL Execution**             | Python + pyodbc                             | SqlServer module                         |
| **Dependencies**              | Azure CLI, Python 3, pyodbc, ODBC Driver 18 | PowerShell 7+, Az/SqlServer modules      |
| **Auto-install Dependencies** | Yes (via apt/pip)                           | Yes (via PowerShell Gallery)             |
| **Credentials Source**        | Azure CLI login or azure-credentials.json   | azure-credentials.json                   |
| **Error Handling**            | Exit codes, basic messages                  | Structured exceptions, detailed messages |
| **Output Format**             | Plain text                                  | Colored, formatted                       |
| **Module Installation**       | System-wide (requires sudo)                 | User-scope (no sudo needed)              |

### configure-managed-identity Scripts

| Feature                        | Bash (.sh)                        | PowerShell (.ps1)                        |
| ------------------------------ | --------------------------------- | ---------------------------------------- |
| **Platform Support**           | Linux/macOS (WSL on Windows)      | Windows/Linux/macOS (native)             |
| **Authentication**             | Azure CLI + sqlcmd                | Az.Accounts + SqlServer module           |
| **Managed Identity Retrieval** | `az webapp identity show`         | `Get-AzWebApp`                           |
| **SQL Execution**              | sqlcmd with access token          | `Invoke-Sqlcmd`                          |
| **Dependencies**               | Azure CLI, sqlcmd, ODBC Driver 18 | PowerShell 7+, Az modules, SqlServer     |
| **Auto-install Dependencies**  | Yes (via install-sqlcmd.sh)       | Yes (via PowerShell Gallery)             |
| **Credentials Source**         | Azure CLI login                   | azure-credentials.json                   |
| **Error Handling**             | Exit codes, basic messages        | Structured exceptions, detailed messages |
| **Output Format**              | Plain text                        | Colored, formatted                       |
| **User Verification**          | sqlcmd query                      | `Invoke-Sqlcmd` with object output       |

## When to Use Each

### Use Bash Scripts When

✅ **Linux-first environments**: Running primarily on Linux servers or containers
✅ **Azure CLI workflows**: Already using Azure CLI for other tasks
✅ **Minimal dependencies**: Want to avoid installing PowerShell
✅ **CI/CD on Linux**: GitHub Actions or GitLab CI with Linux runners
✅ **Shell scripting expertise**: Team is more comfortable with Bash

### Use PowerShell Scripts When

✅ **Windows environments**: Developing or deploying on Windows
✅ **Cross-platform needs**: Need to run on Windows, Linux, and macOS
✅ **Better tooling**: Want IntelliSense, debugging, and IDE support
✅ **Structured output**: Need rich error messages and object manipulation
✅ **Azure DevOps**: Using Azure Pipelines (native PowerShell support)
✅ **Microsoft ecosystem**: Already using PowerShell for other Azure tasks
✅ **No sudo access**: Can't install system-wide packages

## Authentication Methods

### Bash Scripts

```bash
# Option 1: Azure CLI interactive login
az login

# Option 2: Service principal via environment variables
export AZURE_CLIENT_ID="xxx"
export AZURE_CLIENT_SECRET="xxx"
export AZURE_TENANT_ID="xxx"
az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID

# Scripts then use:
az account get-access-token --resource https://database.windows.net/
```

### PowerShell Scripts

```powershell
# Reads from azure-credentials.json automatically
# No manual login required

# Credentials file:
{
  "clientId": "xxx",
  "clientSecret": "xxx",
  "tenantId": "xxx",
  "subscriptionId": "xxx"
}

# Script handles authentication internally
```

## Installation Requirements

### Bash Scripts

```bash
# System packages (requires sudo)
sudo apt-get update
sudo apt-get install -y curl gnupg apt-transport-https

# ODBC Driver and sqlcmd
./scripts/install-sqlcmd.sh

# Python dependencies
pip3 install pyodbc

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### PowerShell Scripts

```powershell
# Install PowerShell (one-time)
# Linux: sudo apt-get install -y powershell
# macOS: brew install --cask powershell
# Windows: Already installed

# Modules (auto-installed by scripts)
Install-Module -Name Az.Accounts -Scope CurrentUser
Install-Module -Name Az.Websites -Scope CurrentUser
Install-Module -Name SqlServer -Scope CurrentUser
```

## Error Handling Examples

### Bash Script Error

```bash
ERROR: Failed to acquire Azure AD access token
Make sure you are logged in with 'az login' and have access to the SQL Server
Exit code: 1
```

### PowerShell Script Error

```powershell
ERROR: Failed to acquire access token:
The client 'xxx' with object id 'xxx' does not have authorization
to perform action 'Microsoft.Resources/subscriptions/read' over scope
'/subscriptions/xxx' or the scope is invalid.

Inner exception: Authorization failed.

Common causes:
  1. Service principal does not have the required permissions
  2. Subscription ID is incorrect
  3. Service principal credentials have expired
```

## Performance

Both scripts have similar performance characteristics:

| Metric             | Bash          | PowerShell              |
| ------------------ | ------------- | ----------------------- |
| **Startup Time**   | ~100ms        | ~500ms (module loading) |
| **Execution Time** | Similar       | Similar                 |
| **Memory Usage**   | Lower (~50MB) | Higher (~150MB)         |
| **Network Calls**  | Same          | Same                    |

**Note**: PowerShell has a higher initial overhead due to module loading, but for long-running operations (like database initialization), the difference is negligible.

## Code Maintainability

### Bash

**Pros:**

- Simple, straightforward syntax
- Widely understood by DevOps engineers
- Easy to debug with set -x

**Cons:**

- String manipulation can be error-prone
- Limited error handling (mainly exit codes)
- Hard to work with complex data structures

### PowerShell

**Pros:**

- Object-oriented approach
- Rich error handling (try/catch/finally)
- Strong typing and parameter validation
- Better IDE support (IntelliSense, debugging)
- Native JSON parsing

**Cons:**

- More verbose syntax
- Steeper learning curve for Bash experts
- Requires PowerShell 7+ for full cross-platform support

## Migration Path

If you're currently using Bash scripts and want to migrate to PowerShell:

1. **Test Both**: Run both versions side-by-side in development
2. **Validate Output**: Ensure both produce identical database configurations
3. **Update CI/CD**: Switch pipeline to use PowerShell scripts
4. **Train Team**: Provide PowerShell training if needed
5. **Deprecate Bash**: Remove Bash scripts once PowerShell is stable

**Recommendation**: Keep both versions available. Use Bash for Linux-heavy environments and PowerShell for cross-platform or Windows-centric deployments.

## CI/CD Integration

### GitHub Actions

**Bash:**

```yaml
- name: Initialize Database
  run: |
    ./scripts/initialize-database.sh \
      "${{ env.RESOURCE_GROUP }}" \
      "${{ env.SQL_SERVER }}" \
      "${{ env.DATABASE_NAME }}"
```

**PowerShell:**

```yaml
- name: Initialize Database
  shell: pwsh
  run: |
    ./scripts/initialize-database.ps1 `
      -ResourceGroup "${{ env.RESOURCE_GROUP }}" `
      -SqlServer "${{ env.SQL_SERVER }}" `
      -DatabaseName "${{ env.DATABASE_NAME }}"
```

### Azure DevOps

**Bash:**

```yaml
- task: Bash@3
  inputs:
    filePath: "scripts/initialize-database.sh"
    arguments: "$(ResourceGroup) $(SqlServer) $(DatabaseName)"
```

**PowerShell:**

```yaml
- task: PowerShell@2
  inputs:
    filePath: "scripts/initialize-database.ps1"
    arguments: "-ResourceGroup $(ResourceGroup) -SqlServer $(SqlServer) -DatabaseName $(DatabaseName)"
```

## Conclusion

Both script versions are fully functional and production-ready. Choose based on:

- **Bash**: Linux-first, minimal dependencies, shell scripting expertise
- **PowerShell**: Cross-platform, Windows support, better tooling, structured output

For maximum flexibility, keep both versions and use whichever fits your environment best.
