# Microsoft Graph API Permission Prerequisite - Summary

## What Changed

Added documentation and tooling to make the **Microsoft Graph API permission** (`RoleManagement.ReadWrite.Directory`) a clear prerequisite for automated deployment.

## Files Updated

### 1. New Files Created

- **`GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md`** - Comprehensive guide showing 3 methods to grant the permission:

  - Azure Portal (visual, step-by-step)
  - Azure CLI (automated commands)
  - PowerShell (using Microsoft Graph SDK)
  - Includes troubleshooting and security considerations

- **`scripts/grant-sp-graph-permissions.sh`** - Automated script to grant the permission via CLI
  - Takes service principal App ID as parameter
  - Checks if permission already granted
  - Provides clear success/failure messages
  - Includes verification steps

### 2. Documentation Updates

#### `DEPLOYMENT.md`

**Before:** Mentioned granting "Directory Readers role" to service principal (which is less secure and not the actual requirement)

**After:**

- Clear section: "Grant Microsoft Graph API Permissions to Service Principal (REQUIRED)"
- Explains the specific permission needed: `RoleManagement.ReadWrite.Directory`
- Provides 3 options (automated script, portal, CLI)
- Links to detailed guide
- Explains why it's needed and what it allows

#### `README.md`

**Before:** Quick setup with 3 steps (create SP, configure secrets, deploy)

**After:** Added step 2:

- "Grant Microsoft Graph API Permissions (REQUIRED)"
- Links to automated script
- Links to detailed guide for manual methods

#### `INTEGRATION_COMPLETE.md`

**Before:** Listed "Directory Readers role" as prerequisite for Option A

**After:**

- Updated to specify `RoleManagement.ReadWrite.Directory` Microsoft Graph API permission
- Added link to grant script
- Added link to detailed guide

#### `scripts/README.md`

**Before:** No mention of Microsoft Graph API permissions

**After:** Added new section for `grant-sp-graph-permissions.sh`:

- Full usage documentation
- Explanation of what it does
- When to use it
- Requirements
- Why it's needed
- Links to alternative methods

### 3. Script Improvements

#### `scripts/grant-sql-directory-reader.sh`

**Before:**

- Only checked for interactive user login (`az ad signed-in-user show`)
- Failed immediately when used with service principal authentication

**After:**

- Checks for both user and service principal authentication
- Gracefully handles service principal login (GitHub Actions)
- Better error messages
- Improved diagnostics

## What This Solves

### Problem

When deploying via GitHub Actions, the workflow would fail with:

```
ERROR: Could not determine current user ID
Make sure you are logged in with 'az login'
```

This was misleading because:

1. The service principal WAS logged in (via `az login --service-principal`)
2. The real issue was the script couldn't detect service principal authentication
3. Even if detected, the service principal lacked the necessary Graph API permissions

### Solution

Now users have:

1. **Clear prerequisite**: Must grant `RoleManagement.ReadWrite.Directory` permission
2. **Automated tooling**: `grant-sp-graph-permissions.sh` script
3. **Multiple methods**: Portal, CLI, PowerShell - choose what works best
4. **Comprehensive guide**: Step-by-step instructions with troubleshooting
5. **Better detection**: Script works with both user and service principal auth

## Required Permission Details

**Permission:** `RoleManagement.ReadWrite.Directory` (Application permission)

**Microsoft Graph API Actions:**

- `GET /directoryRoles` - List active directory roles
- `GET /directoryRoleTemplates` - List role templates
- `POST /directoryRoles` - Activate role templates
- `GET /directoryRoles/{id}/members` - Check role membership
- `POST /directoryRoles/{id}/members/$ref` - Add members to roles

**Why Needed:**
The GitHub Actions workflow needs to automatically grant the SQL Server's managed identity the "Directory Readers" role. Without this permission, the deployment would fail at that step and require manual intervention by an Azure AD administrator.

**Security Considerations:**

- This is a powerful permission (can manage directory roles)
- Alternative: Run the setup manually once with admin privileges
- Alternative: Use separate, highly-privileged SP just for infrastructure setup
- Monitor usage via Azure AD audit logs

## User Flow

### Before

1. Create service principal ✓
2. Configure GitHub secrets ✓
3. Push to main → **DEPLOYMENT FAILS** ❌
4. Search documentation for error message
5. Find `grant-sql-directory-reader.sh` script
6. Try to run it → **FAILS** (insufficient permissions) ❌
7. Contact Azure AD admin for help
8. Admin manually grants Directory Readers role
9. Re-run workflow → Success ✓

**Result:** 9 steps, 2 failures, requires admin intervention mid-deployment

### After

1. Create service principal ✓
2. **Grant Microsoft Graph API permission** (new step) ✓
   - Run: `./scripts/grant-sp-graph-permissions.sh <app-id>`
   - Or follow: `GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md`
3. Configure GitHub secrets ✓
4. Push to main → **DEPLOYMENT SUCCEEDS** ✓

**Result:** 4 steps, 0 failures, fully automated deployment

## Quick Start for Users

```bash
# 1. Create service principal
az ad sp create-for-rbac \
  --name "simple-react-router-deploy" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth

# 2. Grant Microsoft Graph API permission (NEW!)
./scripts/grant-sp-graph-permissions.sh <service-principal-app-id>

# 3. Wait 5-10 minutes for propagation
# 4. Configure GitHub secrets (AZURE_CREDENTIALS, SQL_ADMIN_PASSWORD, etc.)
# 5. Deploy
git push origin main
```

## Files Reference

- **[GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md](../GRANT_SERVICE_PRINCIPAL_PERMISSIONS.md)** - Detailed guide
- **[scripts/grant-sp-graph-permissions.sh](../scripts/grant-sp-graph-permissions.sh)** - Automated script
- **[DEPLOYMENT.md](../DEPLOYMENT.md)** - Full deployment guide
- **[README.md](../README.md)** - Quick start guide
