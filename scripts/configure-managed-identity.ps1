#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Configure managed identity access to Azure SQL Database using PowerShell
.DESCRIPTION
    This script grants the Web App's system-assigned managed identity the necessary permissions
    to access the SQL Database using Azure AD authentication. It creates a database user for the
    managed identity and grants appropriate roles (db_datareader, db_datawriter, db_ddladmin).
.PARAMETER ResourceGroup
    Azure resource group name
.PARAMETER SqlServer
    SQL Server name (without .database.windows.net)
.PARAMETER DatabaseName
    SQL Database name
.PARAMETER WebAppName
    Web App name (used as the managed identity name)
.PARAMETER CredentialsFile
    Path to azure-credentials.json file (default: ../azure-credentials.json)
.EXAMPLE
    ./configure-managed-identity.ps1 `
        -ResourceGroup "myRG" `
        -SqlServer "myserver" `
        -DatabaseName "mydb" `
        -WebAppName "mywebapp"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory = $true)]
    [string]$SqlServer,
    
    [Parameter(Mandatory = $true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory = $true)]
    [string]$WebAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$CredentialsFile = "$PSScriptRoot/../azure-credentials.json"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Configuring Managed Identity Database Access" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup"
Write-Host "SQL Server: $SqlServer"
Write-Host "Database: $DatabaseName"
Write-Host "Web App: $WebAppName"
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if required modules are installed
Write-Host "Checking required PowerShell modules..."
$requiredModules = @('Az.Accounts', 'Az.Websites', 'SqlServer')

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
Import-Module Az.Websites -ErrorAction Stop
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

# Get the managed identity's principal ID
Write-Host ""
Write-Host "Retrieving managed identity details..."
try {
    $webApp = Get-AzWebApp -ResourceGroupName $ResourceGroup -Name $WebAppName -ErrorAction Stop
    
    if (-not $webApp.Identity -or -not $webApp.Identity.PrincipalId) {
        Write-Host "ERROR: Could not retrieve managed identity principal ID for Web App: $WebAppName" -ForegroundColor Red
        Write-Host "Make sure the Web App has a system-assigned managed identity enabled." -ForegroundColor Red
        exit 1
    }
    
    $principalId = $webApp.Identity.PrincipalId
    Write-Host "✓ Managed Identity Principal ID: $principalId" -ForegroundColor Green
    
}
catch {
    Write-Host "ERROR: Failed to retrieve managed identity: $_" -ForegroundColor Red
    Write-Host "Make sure the Web App '$WebAppName' exists and has a system-assigned managed identity enabled." -ForegroundColor Red
    exit 1
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

# Define SQL script to grant permissions
$sqlScript = @"
SET NOCOUNT ON;
DECLARE @principalId NVARCHAR(128) = N'$principalId';
DECLARE @webAppName NVARCHAR(128) = N'$WebAppName';
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

IF IS_ROLEMEMBER('db_datareader', '$WebAppName') = 0
BEGIN
    ALTER ROLE db_datareader ADD MEMBER [$WebAppName];
    PRINT 'Granted db_datareader role to $WebAppName';
END

IF IS_ROLEMEMBER('db_datawriter', '$WebAppName') = 0
BEGIN
    ALTER ROLE db_datawriter ADD MEMBER [$WebAppName];
    PRINT 'Granted db_datawriter role to $WebAppName';
END

IF IS_ROLEMEMBER('db_ddladmin', '$WebAppName') = 0
BEGIN
    ALTER ROLE db_ddladmin ADD MEMBER [$WebAppName];
    PRINT 'Granted db_ddladmin role to $WebAppName';
END

PRINT 'Successfully configured managed identity access for $WebAppName';
"@

# Execute SQL script
Write-Host ""
Write-Host "Executing SQL commands to grant managed identity access..."
Write-Host ""

try {
    $serverInstance = "$SqlServer.database.windows.net"
    
    # Execute SQL with access token
    Invoke-Sqlcmd -ServerInstance $serverInstance `
        -Database $DatabaseName `
        -AccessToken $accessToken `
        -Query $sqlScript `
        -Verbose `
        -ErrorAction Stop | Out-Null
    
    # Verify the user was created
    Write-Host ""
    Write-Host "Verifying user creation..."
    
    $verifyQuery = @"
SET NOCOUNT ON;
SELECT name FROM sys.database_principals 
WHERE type IN ('E', 'X') AND name = '$WebAppName'
"@
    
    $verifyResult = Invoke-Sqlcmd -ServerInstance $serverInstance `
        -Database $DatabaseName `
        -AccessToken $accessToken `
        -Query $verifyQuery `
        -ErrorAction Stop
    
    if ($verifyResult -and $verifyResult.name) {
        Write-Host "✓ User verified in database: $($verifyResult.name)" -ForegroundColor Green
    }
    else {
        Write-Host "✗ WARNING: User not found in database after creation attempt" -ForegroundColor Yellow
        Write-Host "   This indicates the CREATE USER command may have failed silently" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "✓ Managed identity access configured successfully!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "The Web App '$WebAppName' now has the following permissions:"
    Write-Host "  - db_datareader: Read data from all tables"
    Write-Host "  - db_datawriter: Write data to all tables"
    Write-Host "  - db_ddladmin: Create and modify database schema"
    Write-Host ""
    Write-Host "The application can now connect to the database using its managed identity."
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "✗ ERROR: Failed to configure managed identity access" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Error details: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common causes:" -ForegroundColor Yellow
    Write-Host "  1. Azure AD administrator is not configured on the SQL Server" -ForegroundColor Yellow
    Write-Host "  2. Azure AD configuration has not fully propagated (wait longer)" -ForegroundColor Yellow
    Write-Host "  3. SQL Server cannot reach Azure AD" -ForegroundColor Yellow
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
