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

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" || -z "$DATABASE_NAME" || -z "$WEB_APP_NAME" ]]; then
    echo "Usage: $0 <resource-group> <sql-server> <database-name> <web-app-name>"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo "  database-name:     SQL Database name"
    echo "  web-app-name:      Web App name (managed identity name)"
    echo ""
    echo "Note: This script uses Azure AD authentication. Make sure you are logged in with 'az login'"
    echo "      and have the necessary permissions to manage the SQL Database."
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

# Check if sqlcmd is installed
if ! command -v sqlcmd &> /dev/null; then
    echo "ERROR: sqlcmd is not installed"
    echo "Please run: ./scripts/install-sqlcmd.sh"
    exit 1
fi

# Get Azure AD access token for SQL Database
echo "Acquiring Azure AD access token for SQL Database authentication..."
ACCESS_TOKEN=$(az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv 2>/dev/null)

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == *"ERROR"* || "$ACCESS_TOKEN" == *"WARNING"* ]]; then
    echo "ERROR: Failed to acquire Azure AD access token"
    echo "Make sure you are logged in with 'az login' and have access to the SQL Server"
    exit 1
fi

echo "Successfully acquired access token"
SQLCMDPASSWORD="$ACCESS_TOKEN"

# Execute SQL commands using sqlcmd with Azure AD authentication
echo "Executing SQL script with Azure AD authentication using sqlcmd..."
echo ""

# Create temporary SQL file
TEMP_SQL_FILE=$(mktemp)
echo "$SQL_SCRIPT" > "$TEMP_SQL_FILE"

# Use set +e temporarily to prevent script from exiting on error
set +e

# Execute SQL script with sqlcmd
# -S: Server name
# -d: Database name
# -G: Use Azure Active Directory authentication
# -P: Access token (when used with -G)
# -N: Encrypt connection
# -C: Trust server certificate
# -i: Input file
# -b: Terminate batch job if there is an error
sqlcmd -S "${SQL_SERVER}.database.windows.net" \
       -d "$DATABASE_NAME" \
       -G \
       -P "$ACCESS_TOKEN" \
       -N \
       -C \
       -i "$TEMP_SQL_FILE" \
       -b

SQL_EXIT_CODE=$?

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

# Use sqlcmd for verification as well (consistent with main execution)
USER_CHECK=$(sqlcmd -S "${SQL_SERVER}.database.windows.net" \
                    -d "$DATABASE_NAME" \
                    -G \
                    -P "$ACCESS_TOKEN" \
                    -N \
                    -C \
                    -h -1 \
                    -W \
                    -Q "SET NOCOUNT ON; SELECT name FROM sys.database_principals WHERE type IN ('E', 'X') AND name = '$WEB_APP_NAME'" \
                    2>/dev/null | tr -d '[:space:]')

VERIFY_EXIT_CODE=$?

if [ $VERIFY_EXIT_CODE -eq 0 ] && [ -n "$USER_CHECK" ]; then
    echo "✓ User verified in database: $USER_CHECK"
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
