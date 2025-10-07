#!/usr/bin/env bash
# Simple script to verify the modern az CLI is available and print version
set -euo pipefail

if ! command -v az >/dev/null 2>&1; then
  echo "az CLI not found on PATH. Please install the official Azure CLI in the environment."
  exit 2
fi

echo "az found: $(command -v az)"
az --version
exit 0
