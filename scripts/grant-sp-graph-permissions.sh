#!/bin/bash
# Script to grant Microsoft Graph API permissions to a service principal
# This grants the RoleManagement.ReadWrite.Directory permission needed for the
# grant-sql-directory-reader.sh script to work in CI/CD pipelines

set -euo pipefail

# Parameters
SP_APP_ID="${1:-}"

# Validate required parameters
if [[ -z "$SP_APP_ID" ]]; then
    echo "Usage: $0 <service-principal-app-id>"
    echo ""
    echo "Parameters:"
    echo "  service-principal-app-id:    The application (client) ID of your service principal"
    echo ""
    echo "Example:"
    echo "  $0 66868a16-6798-455c-bb79-f53a52e8fa16"
    echo ""
    echo "This script grants the 'RoleManagement.ReadWrite.Directory' Microsoft Graph"
    echo "API permission to your service principal, which is required for automated"
    echo "Azure AD role assignments in CI/CD pipelines."
    echo ""
    echo "Note: You must be logged in as a Global Administrator or have sufficient"
    echo "      permissions to grant API permissions and admin consent."
    exit 1
fi

echo "============================================"
echo "Grant Graph Permissions to Service Principal"
echo "============================================"
echo "Service Principal App ID: $SP_APP_ID"
echo "============================================"
echo ""

# Check if logged in
echo "Verifying Azure login..."
az account show > /dev/null 2>&1 || {
    echo "ERROR: Not logged in to Azure"
    echo "Please run: az login"
    exit 1
}

CURRENT_USER=$(az account show --query user.name -o tsv)
echo "Logged in as: $CURRENT_USER"
echo ""

# Get the service principal object ID
echo "Looking up service principal..."
SP_OBJECT_ID=$(az ad sp show --id "$SP_APP_ID" --query id -o tsv 2>/dev/null || echo "")

if [[ -z "$SP_OBJECT_ID" ]]; then
    echo "ERROR: Could not find service principal with App ID: $SP_APP_ID"
    echo ""
    echo "Make sure:"
    echo "  1. The App ID is correct"
    echo "  2. You have permission to view the service principal"
    echo "  3. The service principal exists in your tenant"
    exit 1
fi

echo "Service Principal Object ID: $SP_OBJECT_ID"
echo ""

# Get Microsoft Graph service principal ID (well-known App ID: 00000003-0000-0000-c000-000000000000)
echo "Looking up Microsoft Graph service principal..."
GRAPH_SP_ID=$(az ad sp list --filter "appId eq '00000003-0000-0000-c000-000000000000'" --query "[0].id" -o tsv 2>/dev/null || echo "")

if [[ -z "$GRAPH_SP_ID" ]]; then
    echo "ERROR: Could not find Microsoft Graph service principal"
    echo "This is unexpected - Microsoft Graph should always be available"
    exit 1
fi

echo "Microsoft Graph SP ID: $GRAPH_SP_ID"
echo ""

# Get the RoleManagement.ReadWrite.Directory permission ID
echo "Looking up RoleManagement.ReadWrite.Directory permission..."
ROLE_PERMISSION_ID=$(az ad sp show --id "$GRAPH_SP_ID" --query "appRoles[?value=='RoleManagement.ReadWrite.Directory'].id | [0]" -o tsv 2>/dev/null || echo "")

if [[ -z "$ROLE_PERMISSION_ID" ]]; then
    echo "ERROR: Could not find RoleManagement.ReadWrite.Directory permission in Microsoft Graph"
    echo "This is unexpected - this is a standard Microsoft Graph permission"
    exit 1
fi

echo "Permission ID: $ROLE_PERMISSION_ID"
echo ""

# Check if permission is already granted
echo "Checking if permission is already granted..."
EXISTING_GRANT=$(az rest \
    --method GET \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --query "value[?appRoleId=='$ROLE_PERMISSION_ID' && resourceId=='$GRAPH_SP_ID'].id | [0]" \
    --output tsv 2>/dev/null || echo "")

if [[ -n "$EXISTING_GRANT" ]]; then
    echo "✓ Permission is already granted!"
    echo ""
    echo "============================================"
    echo "✓ No action needed - already configured!"
    echo "============================================"
    echo ""
    echo "Your service principal already has the RoleManagement.ReadWrite.Directory permission."
    echo "You can now use it in CI/CD pipelines to grant Directory Readers role to SQL Server."
    exit 0
fi

# Grant the permission
echo "Granting RoleManagement.ReadWrite.Directory permission..."
az rest \
    --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OBJECT_ID/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{
        \"principalId\": \"$SP_OBJECT_ID\",
        \"resourceId\": \"$GRAPH_SP_ID\",
        \"appRoleId\": \"$ROLE_PERMISSION_ID\"
    }" \
    --output none

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "✓ Permission granted successfully!"
    echo "============================================"
    echo ""
    echo "Your service principal now has the RoleManagement.ReadWrite.Directory permission."
    echo ""
    echo "⏱️  Please wait 5-10 minutes for the permission to propagate through Azure AD."
    echo ""
    echo "After waiting, you can:"
    echo "  1. Re-run your GitHub Actions workflow, or"
    echo "  2. Test the permission by running:"
    echo "     ./scripts/grant-sql-directory-reader.sh <resource-group> <sql-server>"
    echo ""
else
    echo ""
    echo "============================================"
    echo "✗ ERROR: Failed to grant permission"
    echo "============================================"
    echo ""
    echo "Common causes:"
    echo "  1. Insufficient permissions - you need Global Administrator or Application Administrator role"
    echo "  2. Your account doesn't have permission to grant API permissions"
    echo "  3. Admin consent is required but not automatically granted"
    echo ""
    echo "Solutions:"
    echo "  1. Ask your Azure AD administrator to run this script"
    echo "  2. Grant the permission manually via Azure Portal:"
    echo "     a. Go to Azure Active Directory → App registrations"
    echo "     b. Find your app (App ID: $SP_APP_ID)"
    echo "     c. Go to API permissions → Add a permission"
    echo "     d. Select Microsoft Graph → Application permissions"
    echo "     e. Add 'RoleManagement.ReadWrite.Directory'"
    echo "     f. Click 'Grant admin consent for [Your Organization]'"
    echo ""
    exit 1
fi
