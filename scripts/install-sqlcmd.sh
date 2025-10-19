#!/bin/bash
# Script to install SQL Server command-line tools (sqlcmd)
# This script detects the Ubuntu version and installs the appropriate version of mssql-tools

set -euo pipefail

echo "============================================"
echo "Installing SQL Server Command-Line Tools"
echo "============================================"

# Check if sqlcmd is already installed
if command -v sqlcmd &> /dev/null; then
    SQLCMD_VERSION=$(sqlcmd -? 2>&1 | head -n 1 || echo "unknown")
    echo "sqlcmd is already installed: $SQLCMD_VERSION"
    echo "Skipping installation."
    exit 0
fi

echo "sqlcmd not found, installing..."

# Clean up any existing conflicting configurations
echo "Cleaning up any existing Microsoft repository configurations..."
sudo rm -f /etc/apt/sources.list.d/mssql-release.list
sudo rm -f /etc/apt/sources.list.d/microsoft-prod.list

# Add Microsoft repository and install sqlcmd
# Using modern signed-by method instead of deprecated apt-key
echo "Adding Microsoft package repository..."

# Download and install the GPG key
sudo mkdir -p /usr/share/keyrings
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | \
    gpg --dearmor | \
    sudo tee /usr/share/keyrings/microsoft-prod.gpg > /dev/null

# Detect Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "22.04")
echo "Detected Ubuntu version: $UBUNTU_VERSION"

# Add the repository based on Ubuntu version with proper signed-by
if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    echo "Configuring repository for Ubuntu 24.04..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
elif [[ "$UBUNTU_VERSION" == "22.04" ]]; then
    echo "Configuring repository for Ubuntu 22.04..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
elif [[ "$UBUNTU_VERSION" == "20.04" ]]; then
    echo "Configuring repository for Ubuntu 20.04..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/20.04/prod focal main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
else
    # Default to 22.04 for newer versions
    echo "Unknown Ubuntu version, defaulting to 22.04 repository..."
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" | sudo tee /etc/apt/sources.list.d/mssql-release.list
fi

# Update package lists and install sqlcmd
echo "Updating package lists..."
sudo apt-get update -qq

echo "Installing mssql-tools18 and unixodbc-dev..."
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev

# Add sqlcmd to PATH for this session
export PATH="$PATH:/opt/mssql-tools18/bin"

# Verify installation
if command -v sqlcmd &> /dev/null; then
    SQLCMD_VERSION=$(sqlcmd -? 2>&1 | head -n 1 || echo "installed")
    echo ""
    echo "============================================"
    echo "✓ sqlcmd installed successfully!"
    echo "============================================"
    echo "Version: $SQLCMD_VERSION"
    echo "Location: $(which sqlcmd)"
    echo ""
    echo "Note: Add /opt/mssql-tools18/bin to your PATH to use sqlcmd in future sessions:"
    echo "  export PATH=\"\$PATH:/opt/mssql-tools18/bin\""
else
    echo ""
    echo "============================================"
    echo "✗ ERROR: sqlcmd installation failed"
    echo "============================================"
    exit 1
fi
