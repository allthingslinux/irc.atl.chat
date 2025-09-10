#!/bin/bash

# IRC Services Startup Script
# Ensures permissions and starts UnrealIRCd

set -e

# Ensure binary is executable (fixes permission issues with bind mounts)
echo "Ensuring binary permissions..."
chmod +x /usr/local/bin/unrealircd /usr/local/unrealircd/bin/* 2>/dev/null || echo "Note: Some binaries may not be executable"

# Configuration is prepared by init.sh on host before container starts
echo "Configuration already prepared by init script"

# Start UnrealIRCd
echo "Starting UnrealIRCd..."
exec /usr/local/bin/unrealircd -F
