# Integrated Deployment Solution

This document explains how the SQL Server Azure AD authentication setup is integrated into the GitHub Actions workflow.

## Overview

The deployment is now **mostly automated** through the GitHub Actions workflow, with minimal manual steps required only for initial service principal setup.

## What's Automated (GitHub Actions)

The workflow automatically handles:

1. ✅ **Infrastructure Deployment** (Bicep)

   - Creates SQL Server with system-assigned managed identity
   - Creates Web App with system-assigned managed identity
   - Creates SQL Database
   - Configures firewall rules

2. ✅ **SQL Server Directory Readers Grant** (Post-deployment script)

   - Attempts to grant SQL Server's managed identity the Directory Readers role
   - Falls back gracefully if permissions are insufficient
   - Provides clear error messages for manual intervention

3. ✅ **Azure AD Admin Configuration** (Post-deployment script)

   - Configures Azure AD administrator for SQL Server
   - Enables Azure AD authentication

4. ✅ **Managed Identity Database Access** (Post-deployment script)

   - Creates database user for web app's managed identity
   - Grants necessary permissions (db_datareader, db_datawriter, db_ddladmin)

5. ✅ **Database Schema Initialization** (Post-deployment script)
   - Creates Users table
   - Inserts sample data

## What Requires Manual Setup (One-Time)

### Step 1: Create Service Principal

```bash
az ad sp create-for-rbac \
  --name "simple-react-router-deploy" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

### Step 2: Grant Directory Readers Role

**This is the critical step for automation to work!**

```bash
# Get service principal object ID
SP_OBJECT_ID=$(az ad sp list --display-name "simple-react-router-deploy" --query "[0].id" -o tsv)

# Get Directory Readers role ID
ROLE_ID=$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
  --query "value[?displayName=='Directory Readers'].id | [0]" -o tsv)

# Grant the role
az rest --method POST \
  --uri "https://graph.microsoft.com/v1.0/directoryRoles/${ROLE_ID}/members/\$ref" \
  --headers "Content-Type=application/json" \
  --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/${SP_OBJECT_ID}\"}"
```

**Why?** This allows the service principal to grant Directory Readers role to the SQL Server's managed identity during deployment.

### Step 3: Configure GitHub Secrets

Set these in GitHub repository settings:

- `AZURE_CREDENTIALS` (secret) - Service principal JSON
- `SQL_ADMIN_PASSWORD` (secret) - SQL admin password
- `AZURE_SUBSCRIPTION_ID` (variable) - Azure subscription ID
- `AZURE_RESOURCE_GROUP_NAME` (variable) - Resource group name

## How It Works

### Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. GitHub Actions Workflow Starts                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Deploy Infrastructure (Bicep)                           │
│    • SQL Server + Managed Identity ✅                      │
│    • Web App + Managed Identity ✅                         │
│    • SQL Database ✅                                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Grant SQL Server Directory Readers Role (Script)        │
│    • Uses service principal's Directory Readers permission │
│    • Grants SQL Server's identity Directory Readers        │
│    • IF FAILS: Provides manual fallback instructions       │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    Wait 60 seconds
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Configure Azure AD Admin (Script)                       │
│    • Sets Azure AD admin for SQL Server                    │
│    • Enables Azure AD authentication                       │
└─────────────────────────────────────────────────────────────┘
                          ↓
                    Wait 60 seconds
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Configure Managed Identity Access (Script)              │
│    • Creates database user for web app's managed identity  │
│    • Grants db_datareader, db_datawriter, db_ddladmin     │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Initialize Database Schema (Script)                     │
│    • Creates Users table                                   │
│    • Inserts sample data                                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Build & Deploy Application                              │
└─────────────────────────────────────────────────────────────┘
```

### Error Handling

The workflow includes intelligent error handling:

#### Scenario 1: Service Principal Has Directory Readers Permission ✅

```
Grant SQL Server Directory Readers Role
├─ Execute grant-sql-directory-reader.sh
├─ ✓ Successfully granted Directory Readers role
└─ Continue to next step
```

#### Scenario 2: Service Principal Lacks Permission ⚠️

```
Grant SQL Server Directory Readers Role
├─ Execute grant-sql-directory-reader.sh
├─ ✗ Failed: Insufficient permissions
├─ Check if SQL Server already has Directory Readers
│  └─ If YES: ✓ Continue (already configured)
│  └─ If NO: ✗ Exit with error and instructions
└─ Provide manual command to run with admin permissions
```

## What Can't Be Done in Bicep

These steps **cannot** be automated in Bicep and require post-deployment scripts:

1. ❌ **Directory Readers Role Assignment**

   - Reason: Uses Microsoft Graph API, not ARM API
   - Requires: Azure AD permissions (not subscription permissions)
   - Solution: Post-deployment script with service principal that has Directory Readers

2. ❌ **Azure AD Admin Configuration**

   - Reason: Requires Directory Readers to be granted first
   - Requires: Wait time for Azure AD propagation
   - Solution: Post-deployment script with wait times

3. ❌ **Database User Creation**
   - Reason: Requires SQL commands, not ARM resources
   - Requires: Azure AD authentication to database
   - Solution: Post-deployment script with Azure AD token

See [WHY_NOT_BICEP.md](WHY_NOT_BICEP.md) for detailed technical explanation.

## Comparison: Before vs After

### Before (Manual Process)

```bash
# Deploy infrastructure
az deployment group create ...

# Wait...
sleep 60

# Manually grant Directory Readers
./scripts/grant-sql-directory-reader.sh rg server

# Wait...
sleep 60

# Manually configure AD admin
./scripts/configure-azuread-admin.sh rg server

# Wait...
sleep 60

# Manually configure managed identity
./scripts/configure-managed-identity.sh rg server db app

# Manually initialize database
./scripts/initialize-database.sh rg server db
```

**Total time:** ~5 minutes + manual intervention

### After (Automated Process)

```bash
# Just push to GitHub!
git push origin main
```

**Total time:** ~3-5 minutes, fully automated (if service principal has permissions)

## Benefits of Integrated Solution

### For DevOps Teams

✅ **Fully automated deployments** once service principal is configured
✅ **Consistent deployments** - no manual steps to forget
✅ **Clear error messages** when permissions are insufficient
✅ **Graceful degradation** - provides fallback instructions

### For Security Teams

✅ **Controlled permissions** - service principal only needs Directory Readers
✅ **Audit trail** - all actions logged in GitHub Actions
✅ **Separation of concerns** - initial setup requires admin, deployments don't
✅ **No credentials in code** - uses Azure AD authentication

### For Developers

✅ **Push to deploy** - no manual Azure portal navigation
✅ **Automatic database setup** - schema and sample data
✅ **Fast feedback** - workflow completes in 3-5 minutes
✅ **Easy troubleshooting** - clear workflow logs

## Troubleshooting

### "Failed to grant Directory Readers role"

**Cause:** Service principal doesn't have Directory Readers permission in Azure AD.

**Solution:**

1. Ask Azure AD admin to grant Directory Readers to service principal (one-time setup)
2. OR manually run: `./scripts/grant-sql-directory-reader.sh <rg> <server>`
3. Then re-run the workflow

### "Principal could not be resolved"

**Cause:** Directory Readers role not granted to SQL Server.

**Solution:**

1. Check workflow logs for error in "Grant SQL Server Directory Readers Role" step
2. Follow instructions in workflow output
3. May need to wait for Azure AD propagation (5-10 minutes)

### "Failed to create user"

**Cause:** Azure AD admin not configured or changes haven't propagated.

**Solution:**

1. Verify "Configure Azure AD Administrator" step succeeded
2. Wait 5-10 minutes for propagation
3. Re-run workflow or manually run: `./scripts/configure-managed-identity.sh ...`

## Cost Considerations

The automated workflow:

- ✅ Uses serverless Azure AD authentication (free)
- ✅ No additional Azure resources for automation
- ✅ Minimal GitHub Actions minutes (~3-5 minutes per deployment)
- ✅ No persistent runners or self-hosted agents needed

**Estimated cost per deployment:** < $0.01 in GitHub Actions minutes

## Next Steps

1. **Complete initial setup** (one-time):

   - Create service principal
   - Grant Directory Readers role
   - Configure GitHub secrets

2. **Deploy automatically**:

   - Push to main branch
   - Or manually trigger workflow

3. **Monitor deployments**:

   - Check GitHub Actions logs
   - Verify deployment in Azure Portal

4. **Iterate**:
   - Make code changes
   - Push to trigger redeployment
   - Workflow handles everything

## References

- [GitHub Actions Workflow](../.github/workflows/azure-webapp-deploy.yml)
- [Bicep Template](../infrastructure/main.bicep)
- [Post-Deployment Scripts](../scripts/)
- [Why Not Bicep?](WHY_NOT_BICEP.md)
- [SQL Server Azure AD Setup Guide](SQL_SERVER_AZURE_AD_SETUP.md)
