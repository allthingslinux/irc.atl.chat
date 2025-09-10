#!/bin/bash

# IRC Infrastructure Initialization Script
# Creates required directory structure on host system

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

# Function to create directory structure
create_directories() {
    log_info "Creating required directory structure..."

    # Data directories
    local data_dirs=(
        "$PROJECT_ROOT/data/unrealircd"
        "$PROJECT_ROOT/data/atheme"
        "$PROJECT_ROOT/data/webpanel"
        "$PROJECT_ROOT/data/letsencrypt"
    )

    # Log directories
    local log_dirs=(
        "$PROJECT_ROOT/logs/unrealircd"
        "$PROJECT_ROOT/logs/atheme"
    )

    # SSL directories
    local ssl_dirs=(
        "$PROJECT_ROOT/unrealircd/conf/tls"
    )

    # Create all directories
    for dir in "${data_dirs[@]}" "${log_dirs[@]}" "${ssl_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_info "Created directory: $dir"
        else
            log_info "Directory already exists: $dir"
        fi
    done

    log_success "Directory structure created successfully"
}

# Function to set proper permissions
set_permissions() {
    log_info "Setting proper permissions..."

    # Get current user ID and group ID
    local current_uid=$(id -u)
    local current_gid=$(id -g)

    log_info "Current user: $current_uid:$current_gid"

    # Set ownership for data directories (if they exist)
    if [ -d "$PROJECT_ROOT/data" ]; then
        chown -R "$current_uid:$current_gid" "$PROJECT_ROOT/data"
        log_info "Set ownership for data directory"
    fi

    # Set ownership for log directories (if they exist)
    if [ -d "$PROJECT_ROOT/logs" ]; then
        chown -R "$current_uid:$current_gid" "$PROJECT_ROOT/logs"
        log_info "Set ownership for logs directory"
    fi

    # Set permissions for SSL certificates
    if [ -d "$PROJECT_ROOT/unrealircd/conf/tls" ]; then
        chmod 755 "$PROJECT_ROOT/unrealircd/conf/tls"
        log_info "Set permissions for SSL directory"
    fi

    # Make sure data directories are writable
    find "$PROJECT_ROOT/data" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$PROJECT_ROOT/logs" -type d -exec chmod 755 {} \; 2>/dev/null || true

    log_success "Permissions set successfully"
}

# Function to create .env template if it doesn't exist
create_env_template() {
    local env_file="$PROJECT_ROOT/.env"
    local env_example="$PROJECT_ROOT/env.example"

    if [ ! -f "$env_file" ] && [ -f "$env_example" ]; then
        cp "$env_example" "$env_file"
        log_info "Created .env file from template"
        log_warning "Please edit .env file with your configuration before starting services"
    elif [ -f "$env_file" ]; then
        log_info ".env file already exists"
    else
        log_warning "No .env template found. You may need to create environment variables manually"
    fi
}

# Function to check Docker availability
check_docker() {
    log_info "Checking Docker availability..."

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available"
        exit 1
    fi

    log_success "Docker is available"
}

# Function to show next steps
show_next_steps() {
    echo ""
    log_info "Next steps:"
    echo "  1. Edit .env file with your configuration (optional)"
    echo "  2. Run: make quick-start"
    echo "  3. Or run: docker compose up -d"
    echo ""
    log_info "Data will be stored in:"
    echo "  - $PROJECT_ROOT/data/ (persistent data)"
    echo "  - $PROJECT_ROOT/logs/ (log files)"
}

# Main function
main() {
    log_info "IRC Infrastructure Initialization"
    log_info "=================================="

    # Check if we're running as root (for permission info)
    if [ "$(id -u)" = "0" ]; then
        log_warning "Running as root - this is fine for initial setup"
    fi

    # Check Docker availability
    check_docker

    # Create directory structure
    create_directories

    # Set permissions
    set_permissions

    # Create .env if needed
    create_env_template

    # Show next steps
    show_next_steps

    log_success "Initialization completed successfully!"
}

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
