# PowerShell Scripts Quick Reference

## Authentication Methods

Both `initialize-database.ps1` and `configure-managed-identity.ps1` support flexible authentication:

### Method 1: Use Current Azure Account (Local Development)

```powershell
# 1. Login to Azure
Connect-AzAccount

# 2. Run scripts (they'll use your existing session)
pwsh ./scripts/initialize-database.ps1 -ResourceGroup "rg" -SqlServer "server" -DatabaseName "db"
pwsh ./scripts/configure-managed-identity.ps1 -ResourceGroup "rg" -SqlServer "server" -DatabaseName "db" -WebAppName "app"
```

**Benefits:**

- ✅ No credentials file needed
- ✅ Uses your personal Azure account
- ✅ Great for local testing
- ✅ Scripts won't disconnect you

### Method 2: Use Credentials File (CI/CD)

```powershell
# Just run the scripts - they'll read azure-credentials.json
pwsh ./scripts/initialize-database.ps1 -ResourceGroup "rg" -SqlServer "server" -DatabaseName "db"
pwsh ./scripts/configure-managed-identity.ps1 -ResourceGroup "rg" -SqlServer "server" -DatabaseName "db" -WebAppName "app"
```

**Benefits:**

- ✅ Automated/unattended execution
- ✅ Perfect for CI/CD pipelines
- ✅ Uses service principal credentials
- ✅ No manual login required

## Script Behavior

### When You're Already Logged In

```
============================================
Initializing Database Schema
============================================
...

✓ Found existing Azure session
  Account: user@example.com
  Subscription: My Subscription (xxx-xxx)
  Tenant: xxx-xxx

...
Using existing Azure session
```

### When Not Logged In

```
============================================
Initializing Database Schema
============================================
...

No existing Azure session found. Attempting to login with credentials file...
Reading Azure credentials from: /path/to/azure-credentials.json

...
Logging in to Azure with service principal...
✓ Successfully logged in to Azure
```

### When Neither Works

```
ERROR: Not logged into Azure and credentials file not found at: /path/to/azure-credentials.json

Please either:
  1. Login to Azure first: Connect-AzAccount
  2. Ensure azure-credentials.json exists in the repository root
```

## Common Scenarios

### Scenario 1: Local Development

```powershell
# One-time login
Connect-AzAccount

# Run scripts as many times as you want
pwsh ./scripts/initialize-database.ps1 -ResourceGroup "dev-rg" -SqlServer "dev-server" -DatabaseName "dev-db"
pwsh ./scripts/configure-managed-identity.ps1 -ResourceGroup "dev-rg" -SqlServer "dev-server" -DatabaseName "dev-db" -WebAppName "dev-app"

# Your session stays active for other work
Get-AzResourceGroup
```

### Scenario 2: GitHub Actions

```yaml
- name: Initialize Database
  shell: pwsh
  run: |
    # No Connect-AzAccount needed - uses azure-credentials.json
    ./scripts/initialize-database.ps1 `
      -ResourceGroup "${{ env.RESOURCE_GROUP }}" `
      -SqlServer "${{ env.SQL_SERVER }}" `
      -DatabaseName "${{ env.DATABASE_NAME }}"
```

### Scenario 3: Azure DevOps

```yaml
- task: PowerShell@2
  displayName: "Initialize Database"
  inputs:
    filePath: "scripts/initialize-database.ps1"
    arguments: >
      -ResourceGroup "$(ResourceGroup)"
      -SqlServer "$(SqlServer)"
      -DatabaseName "$(DatabaseName)"
```

### Scenario 4: Manual with Specific Subscription

```powershell
# Login and select subscription
Connect-AzAccount
Set-AzContext -Subscription "My Production Subscription"

# Run scripts
pwsh ./scripts/initialize-database.ps1 -ResourceGroup "prod-rg" -SqlServer "prod-server" -DatabaseName "prod-db"
```

## Comparison with Bash Scripts

| Feature                     | Bash Scripts                     | PowerShell Scripts                     |
| --------------------------- | -------------------------------- | -------------------------------------- |
| **Check existing session**  | Uses `az account show`           | Uses `Get-AzContext`                   |
| **Interactive login**       | `az login`                       | `Connect-AzAccount`                    |
| **Credentials file**        | azure-credentials.json           | azure-credentials.json                 |
| **Service principal login** | `az login --service-principal`   | `Connect-AzAccount -ServicePrincipal`  |
| **Session management**      | Doesn't affect Azure CLI session | Doesn't affect your PowerShell session |

## Tips

### Tip 1: Check Your Current Session

```powershell
# See if you're logged in
Get-AzContext

# See all your Azure sessions
Get-AzContext -ListAvailable

# Switch between subscriptions
Set-AzContext -Subscription "subscription-name"
```

### Tip 2: Login Once, Use Multiple Times

```powershell
# Login at the start of your work session
Connect-AzAccount

# Run multiple scripts without re-authenticating
pwsh ./scripts/initialize-database.ps1 ...
pwsh ./scripts/configure-managed-identity.ps1 ...
pwsh ./scripts/some-other-script.ps1 ...
```

### Tip 3: Override Credentials File Location

```powershell
# Use a different credentials file
pwsh ./scripts/initialize-database.ps1 `
  -ResourceGroup "rg" `
  -SqlServer "server" `
  -DatabaseName "db" `
  -CredentialsFile "/custom/path/credentials.json"
```

### Tip 4: Logout When Done

```powershell
# If scripts logged you in and you're done
Disconnect-AzAccount

# If you were already logged in, you'll stay logged in
# (scripts only disconnect if they logged in themselves)
```

## Error Handling

### Error: "Azure AD admin is not configured"

```bash
# Fix: Run the Azure AD admin configuration first
./scripts/configure-azuread-admin.sh your-rg your-server
```

### Error: "Cannot open server"

```bash
# Fix: Add firewall rule for your IP
az sql server firewall-rule create \
  --resource-group your-rg \
  --server your-server \
  --name AllowMyIP \
  --start-ip-address $(curl -s ifconfig.me) \
  --end-ip-address $(curl -s ifconfig.me)
```

### Error: "Access token has expired"

```powershell
# Fix: Get a fresh token by re-logging in
Disconnect-AzAccount
Connect-AzAccount
# Then run your script again
```

## Best Practices

1. **Local Development**: Use `Connect-AzAccount` for interactive work
2. **CI/CD**: Use `azure-credentials.json` for automated pipelines
3. **Don't Mix**: Either use one method or the other, not both simultaneously
4. **Security**: Never commit `azure-credentials.json` to git
5. **Rotation**: Regularly rotate service principal secrets in production

## Quick Commands

```powershell
# Check if logged in
Get-AzContext

# Login interactively
Connect-AzAccount

# Login with service principal (manual)
$cred = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant "tenant-id"

# Select subscription
Set-AzContext -Subscription "subscription-name"

# Logout
Disconnect-AzAccount

# List available subscriptions
Get-AzSubscription

# Get current subscription
(Get-AzContext).Subscription
```
