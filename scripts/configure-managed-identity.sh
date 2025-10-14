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

# Check if sqlcmd is installed, if not install it
if ! command -v sqlcmd &> /dev/null; then
    echo "sqlcmd not found, installing..."
    
    # Add Microsoft repository and install sqlcmd
    # Using non-interactive mode for CI/CD environments
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - 2>/dev/null || true
    
    # Detect Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "22.04")
    
    # Add the repository based on Ubuntu version
    if [[ "$UBUNTU_VERSION" == "22.04" ]]; then
        echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
    elif [[ "$UBUNTU_VERSION" == "20.04" ]]; then
        echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/20.04/prod focal main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
    else
        # Default to 22.04 for newer versions
        echo "deb [arch=amd64] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
    fi
    
    # Update package lists and install sqlcmd
    sudo apt-get update -qq
    sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
    
    # Add sqlcmd to PATH for this session
    export PATH="$PATH:/opt/mssql-tools18/bin"
    
    echo "sqlcmd installed successfully"
fi

# Execute SQL commands using sqlcmd
# -S: server name
# -d: database name
# -U: username
# -P: password
# -C: trust server certificate (required for Azure SQL with TLS 1.2+)
# -Q: query to execute
sqlcmd -S "${SQL_SERVER}.database.windows.net" \
    -d "$DATABASE_NAME" \
    -U "$SQL_ADMIN_LOGIN" \
    -P "$SQL_ADMIN_PASSWORD" \
    -C \
    -Q "$SQL_SCRIPT"

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
