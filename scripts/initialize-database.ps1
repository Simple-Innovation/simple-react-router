#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initialize the database schema for Azure SQL Database using PowerShell
.DESCRIPTION
    This script creates the Users table and inserts sample data if needed.
    It uses Azure service principal authentication from azure-credentials.json.
.PARAMETER ResourceGroup
    Azure resource group name
.PARAMETER SqlServer
    SQL Server name (without .database.windows.net)
.PARAMETER DatabaseName
    SQL Database name
.PARAMETER CredentialsFile
    Path to azure-credentials.json file (default: ../azure-credentials.json)
.EXAMPLE
    ./initialize-database.ps1 -ResourceGroup "myRG" -SqlServer "myserver" -DatabaseName "mydb"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$SqlServer,
    
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory = $false)]
    [string]$CredentialsFile = "$PSScriptRoot/../azure-credentials.json"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Initializing Database Schema" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup"
Write-Host "SQL Server: $SqlServer"
Write-Host "Database: $DatabaseName"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if required modules are installed
Write-Host "Checking required PowerShell modules..."
$requiredModules = @('Az.Accounts', 'SqlServer')

foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing $module module..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser -Repository PSGallery
            Write-Host "✓ $module installed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: Failed to install $module module: $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "✓ $module module is already installed" -ForegroundColor Green
    }
}

# Import modules
Write-Host "Importing required modules..."
Import-Module Az.Accounts -ErrorAction Stop
Import-Module SqlServer -ErrorAction Stop

# Check if already logged into Azure (AFTER modules are loaded)
Write-Host ""
Write-Host "Checking Azure authentication..."
$azContext = Get-AzContext -ErrorAction SilentlyContinue
$useExistingSession = $false

if ($azContext) {
    Write-Host "✓ Found existing Azure session" -ForegroundColor Green
    Write-Host "  Account: $($azContext.Account.Id)"
    Write-Host "  Subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))"
    Write-Host "  Tenant: $($azContext.Tenant.Id)"
    $useExistingSession = $true
}
else {
    Write-Host "No existing Azure session found. Attempting to login with credentials file..." -ForegroundColor Yellow
    
    # Check if azure-credentials.json exists
    if (-not (Test-Path $CredentialsFile)) {
        Write-Host ""
        Write-Host "ERROR: Not logged into Azure and credentials file not found at: $CredentialsFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please either:" -ForegroundColor Yellow
        Write-Host "  1. Login to Azure first: Connect-AzAccount" -ForegroundColor Yellow
        Write-Host "  2. Ensure azure-credentials.json exists in the repository root" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    # Read Azure credentials
    Write-Host "Reading Azure credentials from: $CredentialsFile"
    try {
        $credentials = Get-Content $CredentialsFile -Raw | ConvertFrom-Json
        $clientId = $credentials.clientId
        $clientSecret = $credentials.clientSecret
        $tenantId = $credentials.tenantId
        $subscriptionId = $credentials.subscriptionId
    }
    catch {
        Write-Host "ERROR: Failed to read credentials file: $_" -ForegroundColor Red
        exit 1
    }
}

# Login to Azure with service principal (only if not already logged in)
if (-not $useExistingSession) {
    Write-Host ""
    Write-Host "Logging in to Azure with service principal..."
    try {
        $securePassword = ConvertTo-SecureString $clientSecret -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($clientId, $securePassword)
        
        Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $tenantId -Subscription $subscriptionId | Out-Null
        Write-Host "✓ Successfully logged in to Azure" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to login to Azure: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host ""
    Write-Host "Using existing Azure session" -ForegroundColor Green
}

# Get access token for SQL Database
Write-Host "Acquiring Azure AD access token for SQL Database authentication..."
try {
    $tokenResponse = Get-AzAccessToken -ResourceUrl "https://database.windows.net/"
    $accessToken = $tokenResponse.Token
    Write-Host "✓ Successfully acquired access token" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to acquire access token: $_" -ForegroundColor Red
    exit 1
}

# Define SQL script for database initialization
$sqlScript = @"
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
"@

# Execute SQL script
Write-Host ""
Write-Host "Executing database initialization script..."
Write-Host ""

try {
    $serverInstance = "$SqlServer.database.windows.net"
    
    # Execute SQL with access token
    $result = Invoke-Sqlcmd -ServerInstance $serverInstance `
        -Database $DatabaseName `
        -AccessToken $accessToken `
        -Query $sqlScript `
        -Verbose `
        -ErrorAction Stop
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "✓ Database initialized successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The database schema has been created and sample data has been added."
    Write-Host "The application can now connect and use the database."
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "✗ ERROR: Failed to initialize database" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host ""
    
    # Try to get more detailed error information
    if ($_.Exception.InnerException) {
        Write-Host "Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    
    exit 1
}

# Disconnect from Azure (only if we logged in with service principal)
if (-not $useExistingSession) {
    Disconnect-AzAccount | Out-Null
}

Write-Host "Script completed successfully." -ForegroundColor Green
