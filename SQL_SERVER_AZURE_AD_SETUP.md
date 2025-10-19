# SQL Server Azure AD Setup Guide

## The Problem

When trying to use Azure AD authentication with Azure SQL Database, you may encounter this error:

```
Principal 'simple-react-router-web' could not be resolved.
Error message: 'Server identity is not configured. Please follow the steps in
"Assign an Azure AD identity to your server and add Directory Reader permission
to your identity" (https://aka.ms/sqlaadsetup)'
```

This error occurs because the SQL Server itself needs special Azure AD permissions to resolve other Azure AD identities.

## Understanding the Architecture

For a web app to connect to SQL Database using its managed identity, the following setup is required:

1. **Web App** has a system-assigned managed identity ✓ (automatically created by Bicep)
2. **SQL Server** has a system-assigned managed identity ✓ (now added to Bicep)
3. **SQL Server's identity** has Directory Readers role in Azure AD ✗ (requires manual step)
4. **Azure AD admin** is configured on SQL Server ✗ (requires manual step)
5. **Database user** is created for the web app's identity ✗ (requires manual step)

Steps 1-2 are handled by the Bicep template. Steps 3-5 must be done post-deployment.

## Why Directory Reader is Required

The SQL Server needs the **Directory Reader** role in Azure AD to:

- Look up Azure AD principals by their object ID
- Validate Azure AD authentication tokens
- Resolve managed identities when creating database users

Without this role, the SQL Server cannot resolve the web app's managed identity, resulting in the error above.

## Solution: Three-Step Post-Deployment Process

After deploying the infrastructure, follow these steps in order:

### Step 1: Grant Directory Readers Role to SQL Server

This step requires **Global Administrator** or **Privileged Role Administrator** permissions in Azure AD.

```bash
./scripts/grant-sql-directory-reader.sh <resource-group> <sql-server-name>

# Example:
./scripts/grant-sql-directory-reader.sh \
  simple-react-router-rg \
  simple-react-router-abc123-sql
```

What this does:

- Gets the SQL Server's managed identity principal ID
- Grants the "Directory Readers" Azure AD role to that identity
- Enables the SQL Server to resolve other Azure AD principals

**Important:** If you don't have sufficient permissions, you'll see an error. Ask your Azure AD administrator to run this script or manually grant the role.

### Step 2: Configure Azure AD Administrator

This step sets up who can authenticate to the SQL Server using Azure AD.

```bash
./scripts/configure-azuread-admin.sh <resource-group> <sql-server-name> [admin-user] [admin-object-id]

# Example (using current logged-in user):
./scripts/configure-azuread-admin.sh \
  simple-react-router-rg \
  simple-react-router-abc123-sql

# Example (specifying a user):
./scripts/configure-azuread-admin.sh \
  simple-react-router-rg \
  simple-react-router-abc123-sql \
  admin@example.com \
  12345678-1234-1234-1234-123456789012
```

What this does:

- Sets an Azure AD user or service principal as the SQL Server administrator
- Enables Azure AD authentication for the SQL Server
- Allows that user to create database users for other Azure AD principals

### Step 3: Grant Managed Identity Database Access

This step creates a database user for the web app's managed identity and grants permissions.

```bash
./scripts/configure-managed-identity.sh <resource-group> <sql-server-name> <database-name> <web-app-name>

# Example:
./scripts/configure-managed-identity.sh \
  simple-react-router-rg \
  simple-react-router-abc123-sql \
  UsersDB \
  simple-react-router-web
```

What this does:

- Creates a database user for the web app's managed identity
- Grants `db_datareader`, `db_datawriter`, and `db_ddladmin` roles
- Enables the web app to connect using its managed identity

## Complete Example

Here's a complete example of the post-deployment setup:

```bash
# Set your values
RESOURCE_GROUP="simple-react-router-rg"
SQL_SERVER="simple-react-router-abc123-sql"
DATABASE_NAME="UsersDB"
WEB_APP_NAME="simple-react-router-web"

# Step 1: Grant Directory Readers role (requires Azure AD admin permissions)
./scripts/grant-sql-directory-reader.sh "$RESOURCE_GROUP" "$SQL_SERVER"

# Step 2: Configure Azure AD admin (wait a few minutes after step 1)
sleep 60  # Wait for Azure AD changes to propagate
./scripts/configure-azuread-admin.sh "$RESOURCE_GROUP" "$SQL_SERVER"

# Step 3: Grant managed identity access (wait a few minutes after step 2)
sleep 60  # Wait for Azure AD admin configuration to propagate
./scripts/configure-managed-identity.sh "$RESOURCE_GROUP" "$SQL_SERVER" "$DATABASE_NAME" "$WEB_APP_NAME"

# Step 4: Initialize the database schema
./scripts/initialize-database.sh "$RESOURCE_GROUP" "$SQL_SERVER" "$DATABASE_NAME" "$WEB_APP_NAME"
```

## Troubleshooting

### "You do not have permission to grant Directory Readers role"

**Cause:** You don't have sufficient Azure AD permissions.

**Solution:**

- Ask your Global Administrator or Privileged Role Administrator to run the script
- Or have them grant you the "Privileged Role Administrator" role temporarily

### "Principal could not be resolved" (even after granting Directory Readers)

**Cause:** Azure AD changes take time to propagate.

**Solution:**

- Wait 5-10 minutes after granting Directory Readers role
- Then run the configure-azuread-admin.sh script
- If still failing, wait another 5-10 minutes and try again

### "Failed to create user" in configure-managed-identity.sh

**Cause:** Azure AD admin is not configured or hasn't propagated yet.

**Solution:**

- Verify step 2 (configure-azuread-admin.sh) completed successfully
- Wait 5-10 minutes for changes to propagate
- Retry the configure-managed-identity.sh script

### "SQL Server doesn't have a managed identity"

**Cause:** Old Bicep template deployment without SQL Server identity.

**Solution:**

- Re-deploy the infrastructure using the updated Bicep template
- The template now includes `identity: { type: 'SystemAssigned' }` for the SQL Server

## Verifying the Setup

To verify everything is configured correctly:

```bash
# Check SQL Server has managed identity
az sql server show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$SQL_SERVER" \
  --query identity.principalId

# Check Azure AD admin is configured
az sql server ad-admin list \
  --resource-group "$RESOURCE_GROUP" \
  --server-name "$SQL_SERVER"

# Test web app connection (from local machine)
curl https://${WEB_APP_NAME}.azurewebsites.net/api/health
```

## Why Can't This Be Automated?

The **Directory Readers** role assignment cannot be included in the Bicep template because:

1. It requires Azure AD Graph API calls, not Azure Resource Manager (ARM) calls
2. It requires special Azure AD admin permissions beyond typical Azure subscription permissions
3. Microsoft separates Azure resource management from Azure AD management for security

This is why it must be done as a post-deployment step using the Azure CLI or Microsoft Graph API.

## References

- [Azure SQL - Set Azure AD Admin](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)
- [Directory Readers Role](https://learn.microsoft.com/azure/active-directory/roles/permissions-reference#directory-readers)
- [Managed Identity for Azure SQL](https://learn.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)
