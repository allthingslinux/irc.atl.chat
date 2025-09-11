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

# Function to detect and fix permissions automatically
setup_environment() {
    echo "Setting up environment and permissions..."

    # Create required directories
    mkdir -p /home/unrealircd/unrealircd/data /home/unrealircd/unrealircd/logs /home/unrealircd/unrealircd/tmp

    # Detect if we're in rootless Docker by checking if we're root but have a user namespace
    if [ "$(id -u)" = "0" ] && [ -f "/proc/self/uid_map" ]; then
        local container_uid=$(awk 'NR==1 {print $1}' /proc/self/uid_map)
        local host_uid=$(awk 'NR==1 {print $2}' /proc/self/uid_map)

        if [ "$container_uid" = "0" ] && [ "$host_uid" != "0" ]; then
            echo "Detected rootless Docker: container UID 0 maps to host UID $host_uid"
            # Set ownership to the host user so files are accessible
            chown -R "$host_uid:$host_uid" /home/unrealircd/unrealircd/data /home/unrealircd/unrealircd/logs
            # Update USER_ID to match the host user
            USER_ID=$host_uid
            GROUP_ID=$host_uid
        fi
    fi

    # Set proper permissions for directories
    chmod 755 /home/unrealircd/unrealircd/data /home/unrealircd/unrealircd/logs /home/unrealircd/unrealircd/tmp

    # Set umask for readable files
    umask 022

    echo "Environment configured for UID:GID = $USER_ID:$GROUP_ID"
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
    echo "Running as user: $(id)"

    # Execute UnrealIRCd directly (already running as correct user)
    exec "$UNREALIRCD_BIN" -F "$@"
}

# Main execution
case "${1:-start}" in
start)
    setup_environment
    validate_config
    start_unrealircd "$@"
    ;;
*)
    echo "Unknown command: $1"
    echo "Usage: $0 [start]"
    exit 1
    ;;
esac
