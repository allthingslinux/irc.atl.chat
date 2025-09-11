#!/bin/sh
set -e

# Simple Atheme entrypoint for normal Docker  
# No permission complexity needed!

echo "=== Atheme Starting ==="

# Create directories (normal Docker = no permission issues)
mkdir -p /usr/local/atheme/{data,logs,var}

# Validate config exists
if [ ! -f "/usr/local/atheme/etc/atheme.conf" ]; then
    echo "ERROR: Configuration file not found!"
    exit 1
fi

# Clean up stale PID
rm -f /usr/local/atheme/var/atheme.pid

# Start Atheme
echo "Starting Atheme services..."
exec /usr/local/atheme/bin/atheme-services -n -c /usr/local/atheme/etc/atheme.conf -D /usr/local/atheme/data "$@"
