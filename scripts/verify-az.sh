#!/usr/bin/env bash
# Simple script to verify az (modern Azure CLI) or the legacy node-based `azure` CLI is available
set -euo pipefail

found=""
if command -v az >/dev/null 2>&1; then
  found="az"
elif command -v azure >/dev/null 2>&1; then
  found="azure"
fi

if [ -z "$found" ]; then
  echo "Neither 'az' (Microsoft Azure CLI v2+) nor 'azure' (legacy node azure-cli) were found on PATH."
  echo "Options:"
  echo "  - Install the official Microsoft CLI (recommended): curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  echo "  - Or install the community npm package (legacy): npm install -g azure-cli"
  exit 2
fi

echo "$found found: $(command -v $found)"
echo
if [ "$found" = "az" ]; then
  az --version
  exit 0
fi

# If we found the legacy `azure` command, show version and warn
echo "Detected legacy Node-based 'azure' CLI (azure-xplat-cli). This is not the modern 'az' CLI." 
azure --version || true
echo
echo "If you need the modern 'az' CLI (recommended), install it with the official installer:" 
echo "  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
echo "Or use pip user install: python3 -m pip install --user azure-cli" 
exit 0
