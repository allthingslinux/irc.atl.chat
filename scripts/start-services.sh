#!/bin/bash

# IRC Services Startup Script
# Just starts UnrealIRCd - directories created on host

set -e

# Prepare configuration with environment variables
echo "Preparing configuration..."
/opt/irc/scripts/prepare-config.sh

# Start UnrealIRCd
echo "Starting UnrealIRCd..."
exec /usr/local/bin/unrealircd -F
