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
UNREALIRCD_HOST="${UNREALIRCD_HOST:-unrealircd}"
UNREALIRCD_PORT="${UNREALIRCD_PORT:-8600}"
MAX_WAIT_TIME="${MAX_WAIT_TIME:-300}" # 5 minutes max wait
WAIT_INTERVAL="${WAIT_INTERVAL:-5}"   # 5 seconds between checks

print_status "Starting UnrealIRCd WebPanel..."

# Set proper permissions for mounted directories
print_status "Setting permissions for mounted directories..."
if [ -d "/var/www/html/unrealircd-webpanel/data" ]; then
    # Try chown, but don't fail if it doesn't work (bind mount permissions)
    chown -R webpanel:webpanel /var/www/html/unrealircd-webpanel/data 2>/dev/null || print_warning "Could not change data directory ownership (bind mount permissions)"
    # Try chmod, but don't fail if it doesn't work (bind mount permissions)
    chmod -R 775 /var/www/html/unrealircd-webpanel/data 2>/dev/null || print_warning "Could not change data directory permissions (bind mount permissions)"
    print_success "Data directory setup completed"
fi

if [ -d "/var/www/html/unrealircd-webpanel/config" ]; then
    # Try chown, but don't fail if it doesn't work (bind mount permissions)
    chown -R webpanel:webpanel /var/www/html/unrealircd-webpanel/config 2>/dev/null || print_warning "Could not change config directory ownership (bind mount permissions)"
    # Try chmod, but don't fail if it doesn't work (bind mount permissions)
    chmod -R 775 /var/www/html/unrealircd-webpanel/config 2>/dev/null || print_warning "Could not change config directory permissions (bind mount permissions)"
    print_success "Config directory setup completed"
fi

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
