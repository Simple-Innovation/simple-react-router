#!/bin/bash
# Script to configure managed identity access to Azure SQL Database
# This script grants the Web App's system-assigned managed identity the necessary permissions
# to access the SQL Database using Azure AD authentication.

set -euo pipefail

# Parameters
RESOURCE_GROUP="${1:-}"
SQL_SERVER="${2:-}"
DATABASE_NAME="${3:-}"
WEB_APP_NAME="${4:-}"
SQL_ADMIN_LOGIN="${5:-}"
SQL_ADMIN_PASSWORD="${6:-}"

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" || -z "$DATABASE_NAME" || -z "$WEB_APP_NAME" || -z "$SQL_ADMIN_LOGIN" || -z "$SQL_ADMIN_PASSWORD" ]]; then
    echo "Usage: $0 <resource-group> <sql-server> <database-name> <web-app-name> <sql-admin-login> <sql-admin-password>"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo "  database-name:     SQL Database name"
    echo "  web-app-name:      Web App name (managed identity name)"
    echo "  sql-admin-login:   SQL Server administrator login"
    echo "  sql-admin-password: SQL Server administrator password"
    exit 1
fi

echo "============================================"
echo "Configuring Managed Identity Database Access"
echo "============================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER"
echo "Database: $DATABASE_NAME"
echo "Web App: $WEB_APP_NAME"
echo "============================================"

# Create SQL script to grant permissions
SQL_SCRIPT="
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'${WEB_APP_NAME}')
BEGIN
    CREATE USER [${WEB_APP_NAME}] FROM EXTERNAL PROVIDER;
    PRINT 'Created user for managed identity: ${WEB_APP_NAME}';
END
ELSE
BEGIN
    PRINT 'User already exists for managed identity: ${WEB_APP_NAME}';
END

IF IS_ROLEMEMBER('db_datareader', '${WEB_APP_NAME}') = 0
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [${WEB_APP_NAME}];
    PRINT 'Granted db_datareader role to ${WEB_APP_NAME}';
END

IF IS_ROLEMEMBER('db_datawriter', '${WEB_APP_NAME}') = 0
BEGIN
    ALTER ROLE db_datawriter ADD MEMBER [${WEB_APP_NAME}];
    PRINT 'Granted db_datawriter role to ${WEB_APP_NAME}';
END

IF IS_ROLEMEMBER('db_ddladmin', '${WEB_APP_NAME}') = 0
BEGIN
    ALTER ROLE db_ddladmin ADD MEMBER [${WEB_APP_NAME}];
    PRINT 'Granted db_ddladmin role to ${WEB_APP_NAME}';
END

PRINT 'Successfully configured managed identity access for ${WEB_APP_NAME}';
"

echo ""
echo "Executing SQL commands to grant managed identity access..."
echo ""

# Execute SQL commands using Azure CLI
# Using -u flag to specify admin credentials
az sql db execute \
    --resource-group "$RESOURCE_GROUP" \
    --server "$SQL_SERVER" \
    --name "$DATABASE_NAME" \
    --admin-user "$SQL_ADMIN_LOGIN" \
    --admin-password "$SQL_ADMIN_PASSWORD" \
    --query-text "$SQL_SCRIPT"

echo ""
echo "============================================"
echo "✓ Managed identity access configured successfully!"
echo "============================================"
echo ""
echo "The Web App '$WEB_APP_NAME' now has the following permissions:"
echo "  - db_datareader: Read data from all tables"
echo "  - db_datawriter: Write data to all tables"
echo "  - db_ddladmin: Create and modify database schema"
echo ""
echo "The application can now connect to the database using its managed identity."
