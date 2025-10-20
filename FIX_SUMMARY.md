# Fix Summary: SQL Server Azure AD Authentication

## Problem

When deploying the application, users encountered the following error:

```
Principal 'simple-react-router-web' could not be resolved.
Error message: 'Server identity is not configured. Please follow the steps in
"Assign an Azure AD identity to your server and add Directory Reader permission
to your identity" (https://aka.ms/sqlaadsetup)'
```

This error prevented the web app from connecting to the SQL Database using its managed identity.

## Root Cause

The SQL Server itself needs:

1. A system-assigned managed identity
2. The "Directory Readers" role in Azure AD

Without these, the SQL Server cannot resolve other Azure AD principals (like the web app's managed identity), which is required for:

- Creating database users from external providers (`CREATE USER ... FROM EXTERNAL PROVIDER`)
- Validating Azure AD authentication tokens
- Looking up managed identities by their object ID

## Changes Made

### 1. Infrastructure Changes (main.bicep)

**Added system-assigned managed identity to SQL Server:**

```bicep
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  identity: {
    type: 'SystemAssigned'  // <-- ADDED
  }
  properties: {
    // ... existing properties
  }
}
```

**Added output for SQL Server principal ID:**

```bicep
output sqlServerPrincipalId string = sqlServer.identity.principalId
```

This allows scripts to programmatically retrieve the SQL Server's identity.

### 2. New Script: grant-sql-directory-reader.sh

Created a new script to grant the SQL Server's managed identity the Directory Readers role in Azure AD.

**Location:** `/workspaces/simple-react-router/scripts/grant-sql-directory-reader.sh`

**What it does:**

- Retrieves the SQL Server's managed identity principal ID
- Grants the "Directory Readers" Azure AD role
- Validates the role was successfully assigned

**Requirements:**

- Global Administrator or Privileged Role Administrator role in Azure AD
- Must be run **before** configuring Azure AD admin

### 3. Documentation Updates

**Created SQL_SERVER_AZURE_AD_SETUP.md:**

- Detailed explanation of the problem
- Step-by-step setup instructions
- Troubleshooting guide
- Architecture explanation

**Updated DEPLOYMENT.md:**

- Added critical warning about post-deployment steps
- Included complete setup process with proper sequencing
- Added wait times between steps (for Azure AD propagation)
- Included error handling guidance

**Updated scripts/README.md:**

- Added documentation for `grant-sql-directory-reader.sh`
- Added warnings about prerequisite steps
- Clarified the sequence: Step 1 → Step 2 → Step 3

## Post-Deployment Process (The Fix)

After deploying infrastructure, users must now follow these steps **in order**:

### Step 1: Grant Directory Readers Role (NEW - Requires Azure AD Admin)

```bash
./scripts/grant-sql-directory-reader.sh <resource-group> <sql-server>
```

**Who can run this:** Global Administrator or Privileged Role Administrator

**What it fixes:** Enables SQL Server to resolve Azure AD principals

### Step 2: Configure Azure AD Admin (Wait 5-10 minutes after Step 1)

```bash
./scripts/configure-azuread-admin.sh <resource-group> <sql-server>
```

**What it does:** Enables Azure AD authentication on the SQL Server

### Step 3: Grant Managed Identity Access (Wait 5-10 minutes after Step 2)

```bash
./scripts/configure-managed-identity.sh <resource-group> <sql-server> <database> <web-app>
```

**What it does:** Creates database user for web app's managed identity

### Step 4: Initialize Database

```bash
./scripts/initialize-database.sh <resource-group> <sql-server> <database> <web-app>
```

**What it does:** Creates the Users table

## Why These Changes Are Necessary

### Why can't this be automated in Bicep?

The Directory Readers role assignment:

- Requires Azure AD Graph API calls (not Azure Resource Manager)
- Requires special Azure AD admin permissions
- Is separate from Azure subscription resource management

Microsoft intentionally separates:

- **Azure Resource Management** (handled by Bicep/ARM templates)
- **Azure AD Management** (requires separate permissions and APIs)

### Why the wait times between steps?

Azure AD changes take time to propagate globally. Typical propagation times:

- Directory role assignments: 5-10 minutes
- Azure AD admin configuration: 5-10 minutes

Running steps too quickly can result in errors like:

- "Principal could not be resolved"
- "Server is not currently configured to accept this token"

## Testing the Fix

To verify the fix works:

1. Deploy infrastructure (includes SQL Server with managed identity)
2. Run Step 1: `grant-sql-directory-reader.sh`
3. Wait 5-10 minutes
4. Run Step 2: `configure-azuread-admin.sh`
5. Wait 5-10 minutes
6. Run Step 3: `configure-managed-identity.sh`
7. Run Step 4: `initialize-database.sh`
8. Test the API: `curl https://<web-app>.azurewebsites.net/api/health`

Expected result: No more "Principal could not be resolved" errors.

## Impact on Existing Deployments

**For new deployments:**

- Follow the complete 4-step process after infrastructure deployment
- All scripts are ready to use

**For existing deployments (already deployed without SQL Server identity):**

1. Re-deploy infrastructure (updates SQL Server to have managed identity)
2. Follow the 4-step post-deployment process

**Breaking changes:** None - this is purely additive

## Files Modified

1. `infrastructure/main.bicep` - Added SQL Server identity and output
2. `scripts/grant-sql-directory-reader.sh` - New script (created)
3. `SQL_SERVER_AZURE_AD_SETUP.md` - New documentation (created)
4. `DEPLOYMENT.md` - Updated with new post-deployment process
5. `scripts/README.md` - Added documentation for new script

## References

- [Azure SQL - Configure Azure AD Authentication](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)
- [Azure AD Directory Readers Role](https://learn.microsoft.com/azure/active-directory/roles/permissions-reference#directory-readers)
- [Managed Identity for Azure SQL](https://learn.microsoft.com/azure/app-service/tutorial-connect-msi-sql-database)
- [Microsoft Documentation - SQL Server Identity Setup](https://aka.ms/sqlaadsetup)
