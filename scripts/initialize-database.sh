#!/bin/bash
# Script to initialize the database schema for Azure SQL Database
# This script creates the Users table and inserts sample data if needed

set -euo pipefail

# Parameters
RESOURCE_GROUP="${1:-}"
SQL_SERVER="${2:-}"
DATABASE_NAME="${3:-}"

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" || -z "$DATABASE_NAME" ]]; then
    echo "Usage: $0 <resource-group> <sql-server> <database-name>"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo "  database-name:     SQL Database name"
    echo ""
    echo "Note: This script uses Azure AD authentication. Make sure you are logged in with 'az login'"
    echo "      and have the necessary permissions to manage the SQL Database."
    exit 1
fi

echo "============================================"
echo "Initializing Database Schema"
echo "============================================"
echo "Resource Group: $RESOURCE_GROUP"
echo "SQL Server: $SQL_SERVER"
echo "Database: $DATABASE_NAME"
echo "============================================"

# Create SQL script to initialize database
SQL_SCRIPT="
-- Create Users table if it doesn't exist
IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Users' AND xtype='U')
BEGIN
    CREATE TABLE Users (
        Id INT PRIMARY KEY IDENTITY(1,1),
        Name NVARCHAR(100) NOT NULL,
        Email NVARCHAR(100) NOT NULL UNIQUE,
        CreatedAt DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Created Users table';
END
ELSE
BEGIN
    PRINT 'Users table already exists';
END

-- Check if table is empty and add sample data
DECLARE @count INT;
SELECT @count = COUNT(*) FROM Users;

IF @count = 0
BEGIN
    PRINT 'Adding sample users to database...';
    INSERT INTO Users (Name, Email) VALUES
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com'),
    ('Bob Johnson', 'bob.johnson@example.com'),
    ('Alice Williams', 'alice.williams@example.com'),
    ('Charlie Brown', 'charlie.brown@example.com');
    PRINT 'Sample users added successfully';
END
ELSE
BEGIN
    PRINT 'Sample data already exists (found ' + CAST(@count AS NVARCHAR(10)) + ' users)';
END

PRINT 'Database initialization completed';
"

echo ""
echo "Executing database initialization script..."
echo ""

# Get Azure AD access token for SQL Database
echo "Acquiring Azure AD access token for SQL Database authentication..."
ACCESS_TOKEN=$(az account get-access-token --resource https://database.windows.net/ --query accessToken --output tsv 2>/dev/null)

if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == *"ERROR"* || "$ACCESS_TOKEN" == *"WARNING"* ]]; then
    echo "ERROR: Failed to acquire Azure AD access token"
    echo "Make sure you are logged in with 'az login' and have access to the SQL Server"
    exit 1
fi

echo "Successfully acquired access token"

# Execute SQL commands using Python with pyodbc
# This is the most reliable method for using Azure AD access tokens with SQL Server
echo "Executing SQL script with Azure AD authentication using Python..."
echo ""

# Use set +e temporarily to prevent script from exiting on error
set +e

# Create Python script to execute SQL with access token
python3 << PYTHON_SCRIPT
import struct
import sys

try:
    import pyodbc
except ImportError:
    print("Installing pyodbc...")
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pyodbc"])
    import pyodbc

# Access token from environment
access_token = """$ACCESS_TOKEN"""

# Convert token to bytes for ODBC
token_bytes = access_token.encode("utf-16-le")
token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

# Connection string with access token
conn_str = (
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER=${SQL_SERVER}.database.windows.net;"
    f"DATABASE=$DATABASE_NAME;"
    f"Encrypt=yes;"
    f"TrustServerCertificate=no;"
)

try:
    # Connect using access token
    conn = pyodbc.connect(conn_str, attrs_before={1256: token_struct})
    cursor = conn.cursor()
    
    # Execute SQL script
    sql_script = """$SQL_SCRIPT"""
    
    # Execute each statement (split by GO if present)
    statements = [s.strip() for s in sql_script.split('GO') if s.strip()]
    
    for statement in statements:
        try:
            cursor.execute(statement)
            # Print messages from SQL Server (like PRINT statements)
            while cursor.nextset():
                pass
            conn.commit()
        except pyodbc.Error as e:
            print(f"Error executing statement: {e}")
            sys.exit(1)
    
    cursor.close()
    conn.close()
    print("✓ SUCCESS: SQL script executed successfully")
    sys.exit(0)
    
except Exception as e:
    print(f"ERROR: Failed to execute SQL script: {e}")
    sys.exit(1)
PYTHON_SCRIPT

SQL_EXIT_CODE=$?

set -e

if [ $SQL_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "============================================"
    echo "✗ ERROR: Failed to initialize database"
    echo "============================================"
    echo "SQL command failed with exit code: $SQL_EXIT_CODE"
    exit 1
fi

echo ""
echo "============================================"
echo "✓ Database initialized successfully!"
echo "============================================"
echo ""
echo "The database schema has been created and sample data has been added."
echo "The application can now connect and use the database."
echo ""
