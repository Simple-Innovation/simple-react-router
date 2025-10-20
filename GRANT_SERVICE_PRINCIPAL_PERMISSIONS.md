# Grant Service Principal Microsoft Graph Permissions

This guide shows how to grant your service principal the necessary Microsoft Graph API permissions to manage Azure AD directory roles (specifically to grant the Directory Readers role to SQL Server).

## Service Principal Details

From your `azure-credentials.json`:

- **Client ID (App ID)**: `66868a16-6798-455c-bb79-f53a52e8fa16`
- **Tenant ID**: `021c3eef-3ec2-4db9-999b-7c0e8303c3d3`

---

## Option 1: Using Azure Portal (Recommended for most users)

### Step 1: Navigate to App Registration

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Azure Active Directory** → **App registrations**
3. Find your app with Client ID: `66868a16-6798-455c-bb79-f53a52e8fa16`
4. Click on it to open the app registration

### Step 2: Add API Permissions

1. In the left menu, click **API permissions**
2. Click **+ Add a permission**
3. Select **Microsoft Graph**
4. Select **Application permissions** (not Delegated)
5. Search for and select:
   - **`RoleManagement.ReadWrite.Directory`**
6. Click **Add permissions**

### Step 3: Grant Admin Consent

⚠️ **Important**: This step requires Azure AD Administrator privileges.

1. In the API permissions page, click **Grant admin consent for [Your Organization]**
2. Click **Yes** to confirm

The permission should now show a green checkmark under "Status".

---

## Option 2: Using Azure CLI

### Prerequisites

- You must be logged in as a user with Azure AD Administrator privileges
- Run: `az login`

### Grant the Permission

```bash
# Your service principal details
SP_APP_ID="66868a16-6798-455c-bb79-f53a52e8fa16"
TENANT_ID="021c3eef-3ec2-4db9-999b-7c0e8303c3d3"

# Get the Microsoft Graph Service Principal ID
GRAPH_SP_ID=$(az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv)

# Get the RoleManagement.ReadWrite.Directory permission ID
ROLE_PERMISSION_ID=$(az ad sp show --id $GRAPH_SP_ID --query "appRoles[?value=='RoleManagement.ReadWrite.Directory'].id" -o tsv)

# Get your service principal's object ID
SP_OBJECT_ID=$(az ad sp show --id $SP_APP_ID --query id -o tsv)

# Grant the permission
az rest \
  --method POST \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --headers "Content-Type=application/json" \
  --body "{
    \"principalId\": \"$SP_OBJECT_ID\",
    \"resourceId\": \"$GRAPH_SP_ID\",
    \"appRoleId\": \"$ROLE_PERMISSION_ID\"
  }"
```

---

## Option 3: Using PowerShell (Microsoft Graph PowerShell SDK)

```powershell
# Install the module if not already installed
Install-Module Microsoft.Graph -Scope CurrentUser

# Connect (requires admin privileges)
Connect-MgGraph -TenantId "021c3eef-3ec2-4db9-999b-7c0e8303c3d3" -Scopes "Application.ReadWrite.All", "AppRoleAssignment.ReadWrite.All"

# Your service principal details
$spAppId = "66868a16-6798-455c-bb79-f53a52e8fa16"

# Get the service principal object
$sp = Get-MgServicePrincipal -Filter "appId eq '$spAppId'"

# Get Microsoft Graph service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '00000003-0000-0000-c000-000000000000'"

# Find the RoleManagement.ReadWrite.Directory app role
$appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq "RoleManagement.ReadWrite.Directory" }

# Grant the permission
New-MgServicePrincipalAppRoleAssignment `
  -ServicePrincipalId $sp.Id `
  -PrincipalId $sp.Id `
  -ResourceId $graphSp.Id `
  -AppRoleId $appRole.Id
```

---

## Verify the Permission

After granting the permission, verify it:

### Using Azure Portal

1. Go to your app registration
2. Click **API permissions**
3. You should see:
   - **Microsoft Graph** → **RoleManagement.ReadWrite.Directory** (Application)
   - Status: **Granted for [Your Organization]** (green checkmark)

### Using Azure CLI

```bash
SP_APP_ID="66868a16-6798-455c-bb79-f53a52e8fa16"
SP_OBJECT_ID=$(az ad sp show --id $SP_APP_ID --query id -o tsv)

az rest \
  --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
  --query "value[?resourceDisplayName=='Microsoft Graph'].{Permission:appRoleId, ResourceId:resourceId}"
```

---

## Security Considerations

⚠️ **Important Security Notes:**

1. **Least Privilege**: The `RoleManagement.ReadWrite.Directory` permission is powerful. It allows the service principal to:

   - Read all directory roles
   - Assign users/apps to directory roles
   - Activate directory role templates

2. **Alternative Approach**: If you're concerned about granting this permission to your CI/CD service principal, consider:

   - **Manual Setup**: Have an Azure AD admin run the `grant-sql-directory-reader.sh` script manually once during initial setup
   - **Separate Admin SP**: Create a separate service principal with elevated permissions just for infrastructure setup
   - **Just-in-Time Access**: Use Azure AD Privileged Identity Management (PIM) to grant temporary elevated access

3. **Audit**: Monitor the usage of this service principal in Azure AD audit logs

---

## Troubleshooting

### Permission Not Working After Granting

Wait 5-10 minutes for the permission grant to propagate through Azure AD.

### "Insufficient privileges" Error

- Make sure you clicked "Grant admin consent"
- Verify the permission shows as "Granted" with a green checkmark
- The permission must be an **Application** permission, not a **Delegated** permission

### Cannot Grant Admin Consent

You need one of these Azure AD roles:

- **Global Administrator**
- **Privileged Role Administrator**
- **Application Administrator** (for some permissions)

Ask someone with these roles to grant consent for you.

---

## Next Steps

After granting the permission:

1. **Wait 5-10 minutes** for propagation
2. **Re-run your GitHub Actions workflow**, or
3. **Run the script manually**:
   ```bash
   ./scripts/grant-sql-directory-reader.sh simple-react-router-rg simple-react-router-web-sql
   ```

The script should now be able to:

- ✅ Read directory roles
- ✅ Read and activate role templates
- ✅ Grant the Directory Readers role to your SQL Server
