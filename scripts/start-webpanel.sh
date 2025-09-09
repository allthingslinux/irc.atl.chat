#!/bin/bash
# UnrealIRCd WebPanel Startup Script
# Waits for UnrealIRCd to be ready and starts PHP-FPM + Nginx

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print functions
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

# Configuration
UNREALIRCD_HOST="${UNREALIRCD_HOST:-ircd}"
UNREALIRCD_PORT="${UNREALIRCD_PORT:-8600}"
MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}" # 5 minutes max wait
WAIT_INTERVAL="${WAIT_INTERVAL:-5}"   # 5 seconds between checks

print_status "Starting UnrealIRCd WebPanel..."

# Skip JSON-RPC API check for now - start WebPanel directly
print_status "Starting WebPanel without JSON-RPC API check..."
print_warning "Note: WebPanel may need manual configuration to connect to UnrealIRCd"

# Start PHP-FPM
print_status "Starting PHP-FPM..."
php-fpm -D
print_success "PHP-FPM started successfully!"

# Start Nginx in foreground
print_status "Starting Nginx..."
print_success "WebPanel is ready! Access at http://localhost:8080"
exec nginx -g "daemon off;"
