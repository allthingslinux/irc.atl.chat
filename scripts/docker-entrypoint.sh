#!/bin/sh
set -e

# Enable debug mode if requested
if [ "${DEBUG:-0}" = "1" ]; then
    set -x
    echo "=== DEBUG MODE ENABLED ==="
fi

# Configuration
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}
UNREALIRCD_BIN="/home/unrealircd/unrealircd/bin/unrealircd"
CONFIG_FILE="/home/unrealircd/unrealircd/conf/unrealircd.conf"

echo "=== UnrealIRCd Docker Entrypoint ==="
echo "User mapping: UID=$USER_ID, GID=$GROUP_ID"
echo "Command: $*"

# Function to fix permissions
fix_permissions() {
    echo "Fixing permissions on mounted directories..."

    # Fix ownership of mounted volumes
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/logs 2>/dev/null || true
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/data 2>/dev/null || true
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/cache 2>/dev/null || true
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/tmp 2>/dev/null || true

    # Fix conf directory if it exists and is writable
    if [ -d "/home/unrealircd/unrealircd/conf" ]; then
        chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/conf 2>/dev/null || true
    fi

    # Ensure data directory is writable
    chmod 755 /home/unrealircd/unrealircd/data 2>/dev/null || true

    # Ensure data directory exists and is writable for control socket
    mkdir -p /home/unrealircd/unrealircd/data 2>/dev/null || true
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd/data 2>/dev/null || true
    chmod 755 /home/unrealircd/unrealircd/data 2>/dev/null || true

    # Create control socket file with proper permissions
    # Remove existing socket if it exists
    rm -f /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
    # Create the socket file
    touch /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
    chown unrealircd:unrealircd /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
    chmod 666 /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true

    echo "Permissions fixed"
}

# Function to validate configuration
validate_config() {
    echo "Validating configuration..."

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Configuration file not found at $CONFIG_FILE"
        echo "Please ensure the configuration is properly mounted"
        exit 1
    fi

    # Check if config file is readable
    if [ ! -r "$CONFIG_FILE" ]; then
        echo "ERROR: Configuration file is not readable"
        exit 1
    fi

    echo "Configuration validation passed"
}

# Function to start UnrealIRCd
start_unrealircd() {
    echo "Starting UnrealIRCd with args: $*"

    # Change to UnrealIRCd directory
    cd /home/unrealircd/unrealircd

    # Check if binary exists and is executable
    if [ ! -f "$UNREALIRCD_BIN" ] || [ ! -x "$UNREALIRCD_BIN" ]; then
        echo "ERROR: UnrealIRCd binary not found or not executable at $UNREALIRCD_BIN"
        exit 1
    fi

    echo "Found UnrealIRCd binary: $UNREALIRCD_BIN"
    echo "Configuration file: $CONFIG_FILE"
    echo "Working directory: $(pwd)"

    # Drop privileges and execute
    if [ "$(id -u)" = '0' ]; then
        echo "Dropping privileges to run as 'unrealircd' user"
        exec su-exec unrealircd "$UNREALIRCD_BIN" -F "$@"
    else
        echo "Running as current user: $(id)"
        exec "$UNREALIRCD_BIN" -F "$@"
    fi
}

# Main execution
case "${1:-start}" in
start)
    fix_permissions
    validate_config
    start_unrealircd "$@"
    ;;
*)
    echo "Unknown command: $1"
    echo "Usage: $0 [start]"
    exit 1
    ;;
esac
