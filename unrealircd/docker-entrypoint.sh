#!/bin/sh
set -e

# Simple UnrealIRCd entrypoint for normal Docker
# No permission complexity needed!

echo "=== UnrealIRCd Starting ==="

# Create directories (normal Docker = no permission issues)
mkdir -p /home/unrealircd/unrealircd/{data,logs,tmp}

# Validate config exists
if [ ! -f "/home/unrealircd/unrealircd/conf/unrealircd.conf" ]; then
    echo "ERROR: Configuration file not found!"
    exit 1
fi

# Start UnrealIRCd
echo "Starting UnrealIRCd..."
exec /home/unrealircd/unrealircd/bin/unrealircd -F "$@"
