#!/bin/bash
# Script to configure Azure AD administrator for SQL Server
# This enables Azure AD authentication for the SQL Server

set -euo pipefail

# Parameters
RESOURCE_GROUP="${1:-}"
SQL_SERVER="${2:-}"
ADMIN_USER="${3:-}"
ADMIN_OBJECT_ID="${4:-}"

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" ]]; then
    echo "Usage: $0 <resource-group> <sql-server> [admin-user] [admin-object-id]"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo "  admin-user:        (Optional) Azure AD admin user email or service principal name"
    echo "  admin-object-id:   (Optional) Object ID of the admin user"
    echo ""
    echo "If admin-user and admin-object-id are not provided, the current logged-in user will be used."
    exit 1
fi

echo "============================================"
echo "Configuring Azure AD Administrator"
echo "============================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER"
echo "============================================"

# If admin user and object ID are not provided, try to get the current user
if [[ -z "$ADMIN_USER" ]] || [[ -z "$ADMIN_OBJECT_ID" ]]; then
    echo ""
    echo "Admin user not specified, attempting to get current logged-in user..."
    
    # Try to get the current user's account info
    CURRENT_USER=$(az account show --query user.name -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$CURRENT_USER" ]]; then
        echo "ERROR: Could not determine current user. Please provide admin-user and admin-object-id parameters."
        exit 1
    fi
    
    # Check if it's a service principal or user account
    CURRENT_USER_TYPE=$(az account show --query user.type -o tsv 2>/dev/null || echo "")
    
    if [[ "$CURRENT_USER_TYPE" == "servicePrincipal" ]]; then
        # For service principal, get the object ID
        ADMIN_USER="$CURRENT_USER"
        ADMIN_OBJECT_ID=$(az ad sp show --id "$CURRENT_USER" --query id -o tsv 2>/dev/null || echo "")
        
        if [[ -z "$ADMIN_OBJECT_ID" ]]; then
            echo "ERROR: Could not get object ID for service principal $CURRENT_USER"
            exit 1
        fi
        
        echo "Using service principal: $ADMIN_USER"
    else
        # For user account
        ADMIN_USER="$CURRENT_USER"
        ADMIN_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
        
        if [[ -z "$ADMIN_OBJECT_ID" ]]; then
            # Try alternative method
            ADMIN_OBJECT_ID=$(az ad user show --id "$ADMIN_USER" --query id -o tsv 2>/dev/null || echo "")
        fi
        
        if [[ -z "$ADMIN_OBJECT_ID" ]]; then
            echo "ERROR: Could not get object ID for user $ADMIN_USER"
            exit 1
        fi
        
        echo "Using user account: $ADMIN_USER"
    fi
fi

echo "Azure AD Admin: $ADMIN_USER"
echo "Object ID: $ADMIN_OBJECT_ID"
echo ""

# Set the Azure AD administrator for the SQL Server
echo "Setting Azure AD administrator for SQL Server..."
az sql server ad-admin create \
    --resource-group "$RESOURCE_GROUP" \
    --server-name "$SQL_SERVER" \
    --display-name "$ADMIN_USER" \
    --object-id "$ADMIN_OBJECT_ID"

echo ""
echo "============================================"
echo "✓ Azure AD administrator configured successfully!"
echo "============================================"
echo ""
echo "Azure AD authentication is now enabled for SQL Server: $SQL_SERVER"
echo "You can now connect using Azure AD credentials via:"
echo "  - Azure Portal Query Editor (select Azure AD authentication)"
echo "  - SSMS or Azure Data Studio (with Azure AD authentication)"
echo "  - Application using Managed Identity"
echo ""
echo "Note: It may take a few minutes for Azure AD authentication to become fully active."
echo ""
