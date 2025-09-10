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

    # Use host user UID/GID for mounted volumes to avoid permission issues
    # In rootless Docker, we need to use the actual host UID that maps to our container UID
    local host_uid=${PUID:-1000}
    local host_gid=${PGID:-1000}

    # For rootless Docker, we need to find the actual UID that maps to our container UID
    # This is a workaround for rootless Docker UID mapping
    if [ -f "/proc/self/uid_map" ]; then
        local mapped_uid=$(cat /proc/self/uid_map | awk '{print $2}')
        if [ -n "$mapped_uid" ] && [ "$mapped_uid" != "0" ]; then
            host_uid=$mapped_uid
            host_gid=$mapped_uid
        fi
    fi

    # Fix ownership of mounted volumes to host user
    chown -R ${host_uid}:${host_gid} /home/unrealircd/unrealircd/logs 2>/dev/null || true
    chown -R ${host_uid}:${host_gid} /home/unrealircd/unrealircd/data 2>/dev/null || true
    chown -R ${host_uid}:${host_gid} /home/unrealircd/unrealircd/cache 2>/dev/null || true
    chown -R ${host_uid}:${host_gid} /home/unrealircd/unrealircd/tmp 2>/dev/null || true

    # Fix conf directory if it exists and is writable
    # Skip conf directory ownership changes to avoid rootless Docker UID mapping issues
    # The conf directory should be owned by the host user for editing
    if [ -d "/home/unrealircd/unrealircd/conf" ]; then
        echo "Skipping conf directory ownership changes (managed by host)"
        # Only set permissions, not ownership
        chmod -R 755 /home/unrealircd/unrealircd/conf 2>/dev/null || true
        if [ -f "/home/unrealircd/unrealircd/conf/unrealircd.conf" ]; then
            chmod 644 /home/unrealircd/unrealircd/conf/unrealircd.conf 2>/dev/null || true
        fi
    fi

    # Ensure data directory is writable
    chmod 755 /home/unrealircd/unrealircd/data 2>/dev/null || true

    # Ensure data directory exists and is writable for control socket
    mkdir -p /home/unrealircd/unrealircd/data 2>/dev/null || true
    chown -R ${host_uid}:${host_gid} /home/unrealircd/unrealircd/data 2>/dev/null || true
    chmod 755 /home/unrealircd/unrealircd/data 2>/dev/null || true

    # Create control socket file with proper permissions
    # Remove existing socket if it exists
    rm -f /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
    # Create the socket file
    touch /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
    chown ${host_uid}:${host_gid} /home/unrealircd/unrealircd/data/unrealircd.ctl 2>/dev/null || true
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
