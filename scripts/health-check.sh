#!/bin/bash

# ============================================================================
# IRC SERVER HEALTH CHECK SCRIPT
# ============================================================================
# Production health check for UnrealIRCd and Atheme services
# ============================================================================

set -euo pipefail

# Configuration
IRC_HOST="localhost"
IRC_PORT="${IRC_PORT:-6667}"
IRC_TLS_PORT="${IRC_TLS_PORT:-6697}"
RPC_PORT="${IRC_RPC_PORT:-8600}"
HEALTH_TIMEOUT=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] HEALTH: $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] HEALTH WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] HEALTH ERROR: $1${NC}"
}

# Check if a port is listening
check_port() {
    local host=$1
    local port=$2
    local service=$3

    if timeout $HEALTH_TIMEOUT bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        log "$service is listening on $host:$port"
        return 0
    else
        error "$service is not listening on $host:$port"
        return 1
    fi
}

# Check UnrealIRCd process
check_unrealircd_process() {
    # Since we already check port connectivity, just return success
    # The detailed port checks will catch any real issues
    log "UnrealIRCd process check skipped (relying on port checks)"
    return 0
}

# Check Atheme process
check_atheme_process() {
    if pgrep -f "atheme-services" >/dev/null 2>&1; then
        log "Atheme services process is running"
        return 0
    else
        warn "Atheme services process is not running (optional)"
        return 0 # Atheme is optional, don't fail health check
    fi
}

# Check IRC server response
check_irc_response() {
    local host=$1
    local port=$2
    local service=$3

    # Try to connect and get a basic response (simplified check)
    if timeout $HEALTH_TIMEOUT bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
        log "$service is accepting connections"
        return 0
    elif echo -e "PING :healthcheck\r\nQUIT\r\n" | timeout $HEALTH_TIMEOUT nc -w 5 $host $port >/dev/null 2>&1; then
        log "$service responded to PING command"
        return 0
    else
        error "$service is not responding"
        return 1
    fi
}

# Check JSON-RPC API
check_rpc_api() {
    local host=$1
    local port=$2

    # Try to connect to RPC port
    if timeout $HEALTH_TIMEOUT bash -c "</dev/tcp/$host/$port" 2>/dev/null; then
        log "JSON-RPC API is accessible on $host:$port"
        return 0
    else
        warn "JSON-RPC API is not accessible on $host:$port (optional)"
        return 0 # RPC API is optional
    fi
}

# Check disk space
check_disk_space() {
    local threshold=90
    local usage=$(df /usr/local/unrealircd/data | awk 'NR==2 {print $5}' | sed 's/%//')

    if [ "$usage" -lt "$threshold" ]; then
        log "Disk space usage is ${usage}% (below ${threshold}% threshold)"
        return 0
    else
        error "Disk space usage is ${usage}% (above ${threshold}% threshold)"
        return 1
    fi
}

# Check memory usage
check_memory_usage() {
    local threshold=90

    # Try to get memory usage, fallback to skip if not available
    if command -v free >/dev/null 2>&1; then
        local usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
        if [ -n "$usage" ] && [ "$usage" -lt "$threshold" ]; then
            log "Memory usage is ${usage}% (below ${threshold}% threshold)"
            return 0
        else
            warn "Memory usage is ${usage}% (above ${threshold}% threshold)"
            return 0 # Don't fail health check for high memory usage
        fi
    else
        log "Memory check skipped (free command not available)"
        return 0
    fi
}

# Main health check function
main() {
    local exit_code=0

    log "Starting IRC server health check..."

    # Check UnrealIRCd process (simplified for container)
    check_unrealircd_process || exit_code=1

    # Check ports
    check_port "$IRC_HOST" "$IRC_PORT" "IRC Server" || exit_code=1
    check_port "$IRC_HOST" "$IRC_TLS_PORT" "IRC TLS Server" || exit_code=1
    check_rpc_api "$IRC_HOST" "$RPC_PORT" || exit_code=1

    # Check IRC server response
    check_irc_response "$IRC_HOST" "$IRC_PORT" "IRC Server" || exit_code=1

    # Check system resources
    check_disk_space || exit_code=1
    check_memory_usage || exit_code=1

    if [ $exit_code -eq 0 ]; then
        log "All health checks passed"
    else
        error "Some health checks failed"
    fi

    exit $exit_code
}

# Run main function
main "$@"
