#!/bin/sh

# Use the data directory for database storage, not the config directory
DATADIR=/usr/local/atheme/data

# Set up environment and detect rootless Docker
setup_environment() {
    echo "Setting up Atheme environment and permissions..."

    # Create required directories
    mkdir -p "$DATADIR" /usr/local/atheme/logs /usr/local/atheme/var

    # Detect if we're in rootless Docker by checking if we're root but have a user namespace
    if [ "$(id -u)" = "0" ] && [ -f "/proc/self/uid_map" ]; then
        local container_uid=$(awk 'NR==1 {print $1}' /proc/self/uid_map)
        local host_uid=$(awk 'NR==1 {print $2}' /proc/self/uid_map)

        if [ "$container_uid" = "0" ] && [ "$host_uid" != "0" ]; then
            echo "Detected rootless Docker: container UID 0 maps to host UID $host_uid"
            # Set ownership to the host user so files are accessible
            chown -R "$host_uid:$host_uid" "$DATADIR" /usr/local/atheme/logs /usr/local/atheme/var
        fi
    fi

    # Set proper permissions for directories
    chmod 755 "$DATADIR" /usr/local/atheme/logs /usr/local/atheme/var

    # Set umask so new files are group-readable
    umask 022

    echo "Environment configured"
}

# Set up environment
setup_environment

# Verify data directory is accessible
if ! test -w "$DATADIR/"; then
    echo "ERROR: $DATADIR is not writable"
    exit 1
fi

# Clean up any stale PID file
rm -f /usr/local/atheme/var/atheme.pid

# Start Atheme services with correct data directory
exec /usr/local/atheme/bin/atheme-services -n -c /usr/local/atheme/etc/atheme.conf -D "$DATADIR" "$@"
