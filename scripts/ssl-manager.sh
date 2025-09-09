#!/bin/bash

# ============================================================================
# SIMPLIFIED SSL CERTIFICATE MANAGER
# ============================================================================
# Single script to handle all SSL certificate operations
# ============================================================================

set -euo pipefail

# Configuration
DOMAIN="${IRC_DOMAIN:-irc.atl.chat}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@allthingslinux.org}"
TLS_DIR="./unrealircd/conf/tls"
CREDENTIALS_FILE="./cloudflare-credentials.ini"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] SSL: $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SSL: $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] SSL: $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] SSL: $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if credentials file exists
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Cloudflare credentials file not found: $CREDENTIALS_FILE"
        log_info "Copy cloudflare-credentials.ini.template to cloudflare-credentials.ini and fill in your credentials"
        exit 1
    fi
    
    # Check if TLS directory exists
    if [[ ! -d "$TLS_DIR" ]]; then
        log_info "Creating TLS directory: $TLS_DIR"
        mkdir -p "$TLS_DIR"
    fi
    
    log_success "Prerequisites check passed"
}

# Issue new certificates
issue_certificates() {
    log_info "Issuing SSL certificates for $DOMAIN..."
    
    # Run certbot container to issue certificates
    docker compose run --rm certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
        --dns-cloudflare-propagation-seconds=60 \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --expand \
        --non-interactive \
        -d "$DOMAIN" \
        -d "*.$DOMAIN"
    
    # Copy certificates to UnrealIRCd TLS directory
    copy_certificates
    
    log_success "SSL certificates issued successfully!"
}

# Renew existing certificates
renew_certificates() {
    log_info "Renewing SSL certificates..."
    
    # Run certbot container to renew certificates
    docker compose run --rm certbot renew \
        --quiet \
        --no-random-sleep-on-renew
    
    # Copy renewed certificates
    copy_certificates
    
    log_success "SSL certificates renewed successfully!"
}

# Copy certificates from certbot to UnrealIRCd TLS directory
copy_certificates() {
    log_info "Copying certificates to UnrealIRCd TLS directory..."
    
    # Check if certificates already exist in UnrealIRCd TLS directory
    if [[ -f "$TLS_DIR/server.cert.pem" && -f "$TLS_DIR/server.key.pem" ]]; then
        log_success "Certificates already exist in $TLS_DIR"
        return 0
    fi
    
    # Try to copy from Let's Encrypt directory (if running on host)
    local letsencrypt_dir="/etc/letsencrypt/live/$DOMAIN"
    if [[ -d "$letsencrypt_dir" ]]; then
        cp "$letsencrypt_dir/fullchain.pem" "$TLS_DIR/server.cert.pem"
        cp "$letsencrypt_dir/privkey.pem" "$TLS_DIR/server.key.pem"
        
        # Set proper permissions
        chmod 644 "$TLS_DIR/server.cert.pem"
        chmod 600 "$TLS_DIR/server.key.pem"
        
        log_success "Certificates copied from Let's Encrypt directory to $TLS_DIR"
    else
        log_warn "No certificates found to copy from Let's Encrypt directory"
        log_info "Run 'make ssl-setup' to issue new certificates"
    fi
}

# Check certificate status
check_status() {
    log_info "Checking certificate status..."
    
    local cert_file="$TLS_DIR/server.cert.pem"
    
    if [[ -f "$cert_file" ]]; then
        log_info "Certificate information:"
        openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)" | while read -r line; do
            log_info "  $line"
        done
        
        # Check expiration
        local expiry_date
        expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expiry_timestamp
        expiry_timestamp=$(date -d "$expiry_date" +%s)
        local current_timestamp
        current_timestamp=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [[ $days_until_expiry -lt 30 ]]; then
            log_warn "Certificate expires in $days_until_expiry days - renewal recommended"
        else
            log_success "Certificate is valid for $days_until_expiry more days"
        fi
    else
        log_error "No certificate found at $cert_file"
        return 1
    fi
}

# Restart UnrealIRCd to load new certificates
restart_unrealircd() {
    log_info "Restarting UnrealIRCd to load new certificates..."
    
    if docker compose ps unrealircd | grep -q "Up"; then
        docker compose restart unrealircd
        log_success "UnrealIRCd restarted successfully"
    else
        log_warn "UnrealIRCd is not running - certificates will be loaded on next start"
    fi
}

# Show usage information
show_usage() {
    echo "Simplified SSL Certificate Manager"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  issue     - Issue new SSL certificates"
    echo "  renew     - Renew existing certificates"
    echo "  status    - Check certificate status"
    echo "  copy      - Copy certificates to UnrealIRCd directory"
    echo "  restart   - Restart UnrealIRCd to load certificates"
    echo ""
    echo "Examples:"
    echo "  $0 issue     # Issue new certificates"
    echo "  $0 renew     # Renew existing certificates"
    echo "  $0 status    # Check certificate status"
}

# Main function
main() {
    local command="${1:-help}"
    
    case "$command" in
        "issue")
            check_prerequisites
            issue_certificates
            restart_unrealircd
            ;;
        "renew")
            check_prerequisites
            renew_certificates
            restart_unrealircd
            ;;
        "status")
            check_status
            ;;
        "copy")
            copy_certificates
            ;;
        "restart")
            restart_unrealircd
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"