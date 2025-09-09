#!/bin/bash

# Configuration Preparation Script
# Substitutes environment variables in UnrealIRCd configuration files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to prepare configuration
prepare_config() {
    local config_file="$PROJECT_ROOT/unrealircd/conf/unrealircd.conf"
    local temp_file="/tmp/unrealircd.conf.tmp"
    
    if [ ! -f "$config_file" ]; then
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    log_info "Preparing UnrealIRCd configuration with environment variables..."
    
    # Check if envsubst is available
    if ! command -v envsubst >/dev/null 2>&1; then
        log_error "envsubst command not found. Please install gettext package."
        exit 1
    fi
    
    # Load environment variables from .env.local if it exists
    if [ -f "$PROJECT_ROOT/.env.local" ]; then
        log_info "Loading environment variables from .env.local"
        # Use set -a to automatically export all variables
        set -a
        source "$PROJECT_ROOT/.env.local"
        set +a
        log_info "Environment variables loaded"
    fi
    
    # Substitute environment variables
    envsubst < "$config_file" > "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$config_file"
    
    log_success "Configuration prepared successfully"
    
    # Show substituted values for verification
    log_info "Substituted values:"
    echo "  IRC_DOMAIN: ${IRC_DOMAIN:-'not set'}"
    echo "  IRC_NETWORK_NAME: ${IRC_NETWORK_NAME:-'not set'}"
    echo "  IRC_CLOAK_PREFIX: ${IRC_CLOAK_PREFIX:-'not set'}"
    echo "  IRC_ADMIN_NAME: ${IRC_ADMIN_NAME:-'not set'}"
    echo "  IRC_ADMIN_EMAIL: ${IRC_ADMIN_EMAIL:-'not set'}"
}

# Main function
main() {
    log_info "IRC Configuration Preparation"
    
    # Check if we're in a container environment
    if [ -f /.dockerenv ]; then
        log_info "Running in container environment"
    fi
    
    prepare_config
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi