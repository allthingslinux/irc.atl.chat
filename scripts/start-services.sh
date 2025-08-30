#!/bin/bash

# IRC Services Startup Script
# Coordinates UnrealIRCd and Atheme services startup
# Based on Atheme's official documentation recommendations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UNREALIRCD_BIN="/usr/local/bin/unrealircd"
ATHEME_BIN="/usr/local/bin/atheme-services"
ATHEME_CONF="${ATHEME_CONF:-/usr/local/atheme/etc/atheme.conf}"
ATHEME_DATA="${ATHEME_DATA:-/usr/local/atheme/data}"
UNREALIRCD_CONF="/usr/local/unrealircd/conf"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if a service is running
is_service_running() {
    local service_name="$1"
    pgrep -f "$service_name" >/dev/null 2>&1
}

# Function to wait for a service to be ready
wait_for_service() {
    local service_name="$1"
    local max_attempts="${2:-30}"
    local attempt=1

    print_status "Waiting for $service_name to be ready..."

    while [ $attempt -le "$max_attempts" ]; do
        if is_service_running "$service_name"; then
            print_success "$service_name is ready!"
            return 0
        fi

        sleep 2
        attempt=$((attempt + 1))
    done

    print_error "$service_name failed to start within $((max_attempts * 2)) seconds"
    return 1
}

# Function to start UnrealIRCd
start_unrealircd() {
    print_status "Starting UnrealIRCd..."

    if is_service_running "unrealircd"; then
        print_warning "UnrealIRCd is already running"
        return 0
    fi

    # Check if configuration exists
    if [ ! -f "$UNREALIRCD_CONF/unrealircd.conf" ]; then
        print_error "UnrealIRCd configuration not found at $UNREALIRCD_CONF/unrealircd.conf"
        return 1
    fi

    # Start UnrealIRCd in foreground mode
    nohup "${UNREALIRCD_BIN}" -F 2>&1 | while read -r line; do
        print_status "$line"
    done
    local unrealircd_pid=$!

    # Wait for UnrealIRCd to start
    if wait_for_service "unrealircd" 30; then
        print_success "UnrealIRCd started successfully (PID: $unrealircd_pid)"
        return 0
    else
        print_error "Failed to start UnrealIRCd"
        return 1
    fi
}

# Function to start Atheme services
start_atheme() {
    print_status "Starting Atheme services..."

    if is_service_running "atheme-services"; then
        print_warning "Atheme services are already running"
        return 0
    fi

    # Check if Atheme configuration exists
    if [ ! -f "$ATHEME_CONF" ]; then
        print_error "Atheme configuration not found at $ATHEME_CONF"
        print_error "Please ensure the configuration file exists before starting services"
        return 1
    fi

    # Check if database exists, if not initialize it
    if [ ! -f "$ATHEME_DATA/atheme.db" ]; then
        print_status "Initializing Atheme database..."
        if "$ATHEME_BIN" -b -c "$ATHEME_CONF"; then
            print_success "Atheme database initialized"
        else
            print_error "Failed to initialize Atheme database"
            return 1
        fi
    fi

    # Start Atheme services
    nohup "$ATHEME_BIN" -c "$ATHEME_CONF" >/dev/null 2>&1 &
    local atheme_pid=$!

    # Wait for Atheme to start
    if wait_for_service "atheme-services" 30; then
        print_success "Atheme services started successfully (PID: $atheme_pid)"
        return 0
    else
        print_error "Failed to start Atheme services"
        return 1
    fi
}

# Function to stop services gracefully
stop_services() {
    print_status "Stopping services gracefully..."

    # Stop Atheme first
    if is_service_running "atheme-services"; then
        print_status "Stopping Atheme services..."
        pkill -f "atheme-services" || true
        sleep 2
    fi

    # Stop UnrealIRCd
    if is_service_running "unrealircd"; then
        print_status "Stopping UnrealIRCd..."
        pkill -f "unrealircd" || true
        sleep 2
    fi

    print_success "Services stopped"
}

# Function to show service status
show_status() {
    echo "=== IRC Services Status ==="

    if is_service_running "unrealircd"; then
        echo -e "UnrealIRCd: ${GREEN}RUNNING${NC}"
    else
        echo -e "UnrealIRCd: ${RED}STOPPED${NC}"
    fi

    if is_service_running "atheme-services"; then
        echo -e "Atheme:      ${GREEN}RUNNING${NC}"
    else
        echo -e "Atheme:      ${RED}STOPPED${NC}"
    fi

    echo "========================="
}

# Function to show usage
show_usage() {
    cat <<EOF
Usage: $0 [COMMAND]

Commands:
    start       Start both UnrealIRCd and Atheme services
    stop        Stop both services gracefully
    restart     Restart both services
    status      Show service status
    help        Show this help message

Environment variables:
    ATHEME_CONF     Path to Atheme configuration file
    ATHEME_DATA     Path to Atheme data directory

Examples:
    $0 start         # Start all services
    $0 stop          # Stop all services
    $0 status        # Check service status
    ATHEME_CONF=/custom/path.conf $0 start  # Use custom config
EOF
}

# Main execution
case "${1:-start}" in
start)
    print_status "Starting IRC services..."
    start_unrealircd
    sleep 5 # Give UnrealIRCd time to fully start
    start_atheme
    print_success "All IRC services started successfully!"
    show_status
    ;;
stop)
    stop_services
    ;;
restart)
    print_status "Restarting IRC services..."
    stop_services
    sleep 3
    start_unrealircd
    sleep 5
    start_atheme
    print_success "All IRC services restarted successfully!"
    show_status
    ;;
status)
    show_status
    ;;
help | --help | -h)
    show_usage
    ;;
*)
    print_error "Unknown command: $1"
    show_usage
    exit 1
    ;;
esac
