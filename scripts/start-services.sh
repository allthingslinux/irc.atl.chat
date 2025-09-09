#!/bin/bash

# Simple IRC Services Startup Script
# Just starts UnrealIRCd - Atheme runs in separate container

set -e

# Prepare configuration with environment variables
echo "Preparing configuration..."
/opt/irc/scripts/prepare-config.sh

# Simple startup - just run UnrealIRCd
echo "Starting UnrealIRCd..."
exec /usr/local/bin/unrealircd -F
