#!/bin/bash
# Script to initialize the database schema for Azure SQL Database
# This script creates the Users table and inserts sample data if needed

set -euo pipefail

# Parameters
RESOURCE_GROUP="${1:-}"
SQL_SERVER="${2:-}"
DATABASE_NAME="${3:-}"
SQL_ADMIN_LOGIN="${4:-}"
SQL_ADMIN_PASSWORD="${5:-}"

# Validate required parameters
if [[ -z "$RESOURCE_GROUP" || -z "$SQL_SERVER" || -z "$DATABASE_NAME" || -z "$SQL_ADMIN_LOGIN" || -z "$SQL_ADMIN_PASSWORD" ]]; then
    echo "Usage: $0 <resource-group> <sql-server> <database-name> <sql-admin-login> <sql-admin-password>"
    echo ""
    echo "Parameters:"
    echo "  resource-group:    Azure resource group name"
    echo "  sql-server:        SQL Server name (without .database.windows.net)"
    echo "  database-name:     SQL Database name"
    echo "  sql-admin-login:   SQL Server administrator login"
    echo "  sql-admin-password: SQL Server administrator password"
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
echo "✓ Database initialized successfully!"
echo "============================================"
echo ""
echo "The database schema has been created and sample data has been added."
echo "The application can now connect and use the database."
echo ""
