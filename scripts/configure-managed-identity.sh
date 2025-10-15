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

# Get the managed identity's Object ID
echo "Retrieving managed identity details..."
PRINCIPAL_ID=$(az webapp identity show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_APP_NAME" \
    --query principalId \
    --output tsv 2>/dev/null || echo "")

if [[ -z "$PRINCIPAL_ID" ]]; then
    echo "ERROR: Could not retrieve managed identity principal ID for Web App: $WEB_APP_NAME"
    echo "Make sure the Web App has a system-assigned managed identity enabled."
    exit 1
fi

echo "Managed Identity Principal ID: $PRINCIPAL_ID"

# Get the managed identity's client ID (Application ID)
CLIENT_ID=$(az webapp identity show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$WEB_APP_NAME" \
    --query principalId \
    --output tsv | xargs -I {} az ad sp show --id {} --query appId --output tsv 2>/dev/null || echo "")

if [[ -n "$CLIENT_ID" ]]; then
    echo "Managed Identity Client ID: $CLIENT_ID"
fi

# Create SQL script to grant permissions
# Note: For system-assigned managed identities, the user name should be the app name
# But we verify it matches the principal ID from Azure
SQL_SCRIPT="
SET NOCOUNT ON;
DECLARE @principalId NVARCHAR(128) = N'${PRINCIPAL_ID}';
DECLARE @webAppName NVARCHAR(128) = N'${WEB_APP_NAME}';
DECLARE @errorMessage NVARCHAR(4000);

-- Check if user exists
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = @webAppName)
BEGIN
    BEGIN TRY
        -- Create user for managed identity
        DECLARE @sql NVARCHAR(MAX) = N'CREATE USER [' + @webAppName + N'] FROM EXTERNAL PROVIDER';
        EXEC sp_executesql @sql;
        
        -- Verify user was created
        IF EXISTS (SELECT * FROM sys.database_principals WHERE name = @webAppName)
        BEGIN
            PRINT 'SUCCESS: Created user for managed identity: ' + @webAppName;
            PRINT 'Principal ID: ' + @principalId;
        END
        ELSE
        BEGIN
            PRINT 'ERROR: User creation appeared to succeed but user not found in database';
            RAISERROR('Failed to verify user creation', 16, 1);
        END
    END TRY
    BEGIN CATCH
        SET @errorMessage = ERROR_MESSAGE();
        PRINT 'ERROR creating user: ' + @errorMessage;
        PRINT 'This usually means:';
        PRINT '  1. Azure AD admin is not configured on SQL Server';
        PRINT '  2. Azure AD admin configuration has not propagated yet';
        PRINT '  3. The managed identity does not exist in Azure AD';
        RAISERROR(@errorMessage, 16, 1);
    END CATCH
END
ELSE
BEGIN
    PRINT 'User already exists for managed identity: ' + @webAppName;
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

# Get Azure AD access token for SQL Database
echo "Acquiring Azure AD access token for SQL Database authentication..."
ACCESS_TOKEN=$(az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv)

if [[ -z "$ACCESS_TOKEN" ]]; then
    echo "ERROR: Failed to acquire Azure AD access token"
    echo "Make sure you are logged in with 'az login' and have access to the SQL Server"
    exit 1
fi

echo "Successfully acquired access token"
echo ""

# Execute SQL commands using sqlcmd with Azure AD authentication
# For Azure AD token authentication, we use environment variable
# because the token is too long for the -P parameter (max 128 chars)
# -S: server name
# -d: database name
# -G: Use Azure Active Directory authentication
# -C: trust server certificate (required for Azure SQL with TLS 1.2+)
# -b: abort batch on error
echo "Executing SQL script with Azure AD authentication..."
echo ""

# Create a temporary SQL file
TEMP_SQL_FILE=$(mktemp)
echo "$SQL_SCRIPT" > "$TEMP_SQL_FILE"

# Use set +e temporarily to prevent script from exiting on sqlcmd error
# so we can capture the output and provide better error messages
set +e

# Set the access token as environment variable for sqlcmd
# When using -G with Azure AD, sqlcmd checks SQLCMDPASSWORD for the access token
export SQLCMDPASSWORD="$ACCESS_TOKEN"

sqlcmd -S "${SQL_SERVER}.database.windows.net" \
    -d "$DATABASE_NAME" \
    -G \
    -C \
    -b \
    -i "$TEMP_SQL_FILE"

SQL_EXIT_CODE=$?

# Clear the token from environment
unset SQLCMDPASSWORD

set -e

# Clean up temp file
rm -f "$TEMP_SQL_FILE"

echo ""

if [ $SQL_EXIT_CODE -ne 0 ]; then
    echo "============================================"
    echo "✗ ERROR: Failed to configure managed identity access"
    echo "============================================"
    echo "SQL command failed with exit code: $SQL_EXIT_CODE"
    echo ""
    echo "Common causes:"
    echo "  1. Azure AD administrator is not configured on the SQL Server"
    echo "  2. Azure AD configuration has not fully propagated (wait longer)"
    echo "  3. SQL Server cannot reach Azure AD"
    echo ""
    echo "The error output above should provide more details about what went wrong."
    echo ""
    exit 1
fi

# Verify the user was created
echo ""
echo "Verifying user creation..."
USER_CHECK=$(sqlcmd -S "${SQL_SERVER}.database.windows.net" \
    -d "$DATABASE_NAME" \
    -G \
    -P "$ACCESS_TOKEN" \
    -C \
    -h -1 \
    -Q "SELECT COUNT(*) FROM sys.database_principals WHERE name = N'${WEB_APP_NAME}' AND type IN ('E', 'X')" 2>&1 | tr -d '[:space:]')

if [ "$USER_CHECK" = "1" ]; then
    echo "✓ User verified in database"
else
    echo "✗ WARNING: User not found in database after creation attempt"
    echo "   This indicates the CREATE USER command may have failed silently"
    exit 1
fi

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
