#!/bin/bash
# Script to grant Directory Reader role to SQL Server's managed identity
# This is required for SQL Server to resolve Azure AD principals (like the web app's managed identity)

set -euo pipefail

# Parameters
RESOURCE_GROUP="${1:-}"
SQL_SERVER="${2:-}"

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" ]]; then
    echo "Usage: $0 <resource-group> <sql-server>"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo ""
    echo "This script grants the SQL Server's managed identity the 'Directory Readers' role"
    echo "in Azure AD, which is required for the SQL Server to resolve other Azure AD principals."
    echo ""
    echo "Note: You must be logged in as a Global Administrator or Privileged Role Administrator"
    echo "      to grant Directory Readers role."
    exit 1
fi

echo "============================================"
echo "Granting Directory Readers Role to SQL Server"
echo "============================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER"
echo "============================================"
echo ""

# Check if user has sufficient permissions
echo "Checking your Azure AD role permissions..."
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

if [[ -z "$CURRENT_USER_ID" ]]; then
    echo "ERROR: Could not determine current user ID"
    echo "Make sure you are logged in with 'az login'"
    exit 1
fi

echo "Current user ID: $CURRENT_USER_ID"

# Get the SQL Server's managed identity principal ID
echo ""
echo "Retrieving SQL Server's managed identity..."
SQL_PRINCIPAL_ID=$(az sql server show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$SQL_SERVER" \
    --query identity.principalId \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$SQL_PRINCIPAL_ID" ]]; then
    echo "ERROR: Could not retrieve SQL Server's managed identity principal ID"
    echo "Make sure the SQL Server has a system-assigned managed identity enabled."
    echo ""
    echo "You can enable it with:"
    echo "  az sql server update --resource-group $RESOURCE_GROUP --name $SQL_SERVER --identity-type SystemAssigned"
    exit 1
fi

echo "SQL Server Principal ID: $SQL_PRINCIPAL_ID"

# Get the Directory Readers role ID
echo ""
echo "Looking up Directory Readers role..."
DIRECTORY_READERS_ROLE_ID=$(az rest \
    --method GET \
    --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
    --headers "Content-Type=application/json" \
    --query "value[?displayName=='Directory Readers'].id | [0]" \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$DIRECTORY_READERS_ROLE_ID" ]]; then
    echo "WARNING: Directory Readers role not found in active roles"
    echo "Attempting to activate the Directory Readers role template..."
    
    # Get the Directory Readers role template ID
    ROLE_TEMPLATE_ID=$(az rest \
        --method GET \
        --uri "https://graph.microsoft.com/v1.0/directoryRoleTemplates" \
        --headers "Content-Type=application/json" \
        --query "value[?displayName=='Directory Readers'].id | [0]" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$ROLE_TEMPLATE_ID" ]]; then
        echo "ERROR: Could not find Directory Readers role template"
        exit 1
    fi
    
    echo "Directory Readers template ID: $ROLE_TEMPLATE_ID"
    echo "Activating Directory Readers role..."
    
    # Activate the role
    az rest \
        --method POST \
        --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
        --headers "Content-Type=application/json" \
        --body "{\"roleTemplateId\": \"$ROLE_TEMPLATE_ID\"}" \
        --output none 2>/dev/null || {
            echo "WARNING: Could not activate Directory Readers role (it may already be active)"
        }
    
    # Try to get the role ID again
    DIRECTORY_READERS_ROLE_ID=$(az rest \
        --method GET \
        --uri "https://graph.microsoft.com/v1.0/directoryRoles" \
        --headers "Content-Type=application/json" \
        --query "value[?displayName=='Directory Readers'].id | [0]" \
        --output tsv 2>/dev/null || echo "")
    
    if [[ -z "$DIRECTORY_READERS_ROLE_ID" ]]; then
        echo "ERROR: Could not get Directory Readers role ID even after activation attempt"
        exit 1
    fi
fi

echo "Directory Readers role ID: $DIRECTORY_READERS_ROLE_ID"

# Check if the SQL Server is already a member of Directory Readers
echo ""
echo "Checking if SQL Server is already a Directory Reader..."
IS_MEMBER=$(az rest \
    --method GET \
    --uri "https://graph.microsoft.com/v1.0/directoryRoles/${DIRECTORY_READERS_ROLE_ID}/members" \
    --headers "Content-Type=application/json" \
    --query "value[?id=='$SQL_PRINCIPAL_ID'].id | [0]" \
    --output tsv 2>/dev/null || echo "")

if [[ -n "$IS_MEMBER" ]]; then
    echo "✓ SQL Server is already a member of Directory Readers role"
    echo ""
    echo "============================================"
    echo "✓ No action needed - already configured!"
    echo "============================================"
    exit 0
fi

# Grant Directory Readers role to SQL Server
echo ""
echo "Granting Directory Readers role to SQL Server..."
az rest \
    --method POST \
    --uri "https://graph.microsoft.com/v1.0/directoryRoles/${DIRECTORY_READERS_ROLE_ID}/members/\$ref" \
    --headers "Content-Type=application/json" \
    --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/${SQL_PRINCIPAL_ID}\"}" \
    --output none

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================"
    echo "✓ Directory Readers role granted successfully!"
    echo "============================================"
    echo ""
    echo "The SQL Server can now resolve Azure AD principals."
    echo "You can proceed with configuring the managed identity access."
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./scripts/configure-azuread-admin.sh $RESOURCE_GROUP $SQL_SERVER"
    echo "  2. Run: ./scripts/configure-managed-identity.sh $RESOURCE_GROUP $SQL_SERVER <database-name> <web-app-name>"
else
    echo ""
    echo "============================================"
    echo "✗ ERROR: Failed to grant Directory Readers role"
    echo "============================================"
    echo ""
    echo "Common causes:"
    echo "  1. Insufficient permissions - you need Global Administrator or Privileged Role Administrator"
    echo "  2. Your account doesn't have permission to manage directory roles"
    echo ""
    echo "Ask your Azure AD administrator to either:"
    echo "  - Grant you the 'Privileged Role Administrator' role temporarily"
    echo "  - Run this script for you"
    echo "  - Grant the Directory Readers role manually to principal ID: $SQL_PRINCIPAL_ID"
    echo ""
    exit 1
fi
