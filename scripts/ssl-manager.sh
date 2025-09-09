#!/bin/bash

# ============================================================================
# SIMPLIFIED SSL CERTIFICATE MANAGER
# ============================================================================
# Single script to handle all SSL certificate operations
# ============================================================================

# find .env in current or parent dirs
find_env_file() {
  dir="$PWD"
  while true; do
    if [ -f "$dir/.env" ]; then
      echo "$dir/.env"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

if envfile=$(find_env_file); then
  # automatically export all vars
  set -o allexport
  source "$envfile"
  set +o allexport
else
  echo "warning: .env not found" >&2
fi

set -euo pipefail

# Configuration
DOMAIN="${IRC_ROOT_DOMAIN:-atl.dev}"
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
        log_info "Copy cloudflare-credentials.ini.template to cloudflare-credentials.ini and add your API token"
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
    log_info "Checking if certificates already exist..."
    
    # Check if certificates already exist and are valid
    if check_status >/dev/null 2>&1; then
        log_info "Valid certificates already exist for $DOMAIN"
        log_info "Use 'make ssl-renew' if you need to renew them"
        return 0
    fi
    
    log_info "Issuing SSL certificates for $DOMAIN..."
    
    # Run certbot container to issue certificates
    if docker compose run --rm certbot certonly \
        --config-dir /etc/letsencrypt \
        --work-dir /etc/letsencrypt \
        --logs-dir /etc/letsencrypt \
        --dns-cloudflare \
        --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
        --dns-cloudflare-propagation-seconds=60 \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --expand \
        --non-interactive \
        -d "$DOMAIN" \
        -d "*.$DOMAIN" 2>&1 | tee /tmp/certbot_output.log; then
        
        # Copy certificates to UnrealIRCd TLS directory
        copy_certificates
        log_success "SSL certificates issued successfully!"
    else
        # Check if we hit the rate limit
        if grep -q "too many certificates" /tmp/certbot_output.log; then
            log_warn "Let's Encrypt rate limit reached!"
            log_info "Automatically generating self-signed certificate as fallback..."
            generate_self_signed_certificate
        else
            log_error "Failed to issue SSL certificates"
            log_info "Check the error above and try again"
            return 1
        fi
    fi
}

# Renew existing certificates
renew_certificates() {
    log_info "Checking certificate status before renewal..."
    
    # Check if certificates exist
    if ! check_status >/dev/null 2>&1; then
        log_error "No valid certificates found to renew"
        log_info "Use 'make ssl-setup' to issue new certificates first"
        return 1
    fi
    
    log_info "Renewing SSL certificates..."
    
    # Run certbot container to renew certificates
    if docker compose run --rm certbot renew \
        --config-dir /etc/letsencrypt \
        --work-dir /etc/letsencrypt \
        --logs-dir /etc/letsencrypt \
        --quiet \
        --no-random-sleep-on-renew 2>&1 | tee /tmp/certbot_renew_output.log; then
        
        # Copy renewed certificates
        copy_certificates
        log_success "SSL certificates renewed successfully!"
    else
        # Check if we hit the rate limit
        if grep -q "too many certificates" /tmp/certbot_renew_output.log; then
            log_warn "Let's Encrypt rate limit reached!"
            log_info "Current certificates will remain valid until they expire"
            log_info "Run 'make ssl-renew' after the rate limit resets to renew"
        else
            log_warn "SSL certificate renewal failed!"
            log_info "Automatically generating self-signed certificate as fallback..."
            generate_self_signed_certificate
        fi
    fi
}

# Generate self-signed certificate as fallback
generate_self_signed_certificate() {
    log_info "Generating self-signed certificate for $DOMAIN..."
    
    # Create TLS directory if it doesn't exist
    mkdir -p "$TLS_DIR"
    
    # Generate self-signed certificate
    openssl req -x509 -newkey rsa:4096 -keyout "$TLS_DIR/server.key.pem" -out "$TLS_DIR/server.cert.pem" -days 365 -nodes -subj "/CN=$DOMAIN" 2>/dev/null
    
    # Set proper permissions and ownership
    chmod 644 "$TLS_DIR/server.cert.pem"
    chmod 644 "$TLS_DIR/server.key.pem"  # Make readable by container user
    chmod 755 "$TLS_DIR"  # Make directory accessible
    # Try to set ownership, but don't fail if we can't
    chown 1001:1001 "$TLS_DIR/server.cert.pem" "$TLS_DIR/server.key.pem" 2>/dev/null || true
    
    log_success "Self-signed certificate generated successfully!"
    log_warn "This is a self-signed certificate - browsers will show security warnings"
    log_info "Run 'make ssl-renew' after the Let's Encrypt rate limit resets to get a trusted certificate"
}

# Copy certificates from certbot to UnrealIRCd TLS directory
copy_certificates() {
    log_info "Copying certificates to UnrealIRCd TLS directory..."
    
    # Check if certificates already exist in UnrealIRCd TLS directory
    if [[ -f "$TLS_DIR/server.cert.pem" && -f "$TLS_DIR/server.key.pem" ]]; then
        log_success "Certificates already exist in $TLS_DIR"
        return 0
    fi
    
    # Try to copy from Docker container first
    log_info "Looking for certificates in certbot container..."
    if docker compose run --rm --entrypoint="" certbot ls "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" >/dev/null 2>&1; then
        log_info "Found certificates in certbot container, copying..."
        
        # Copy certificate from container
        docker compose run --rm --entrypoint="" certbot cat "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" > "$TLS_DIR/server.cert.pem"
        docker compose run --rm --entrypoint="" certbot cat "/etc/letsencrypt/live/$DOMAIN/privkey.pem" > "$TLS_DIR/server.key.pem"
        
        # Set proper permissions and ownership
        chmod 644 "$TLS_DIR/server.cert.pem"
        chmod 644 "$TLS_DIR/server.key.pem"  # Make readable by container user
        chmod 755 "$TLS_DIR"  # Make directory accessible
        # Try to set ownership, but don't fail if we can't
        chown 1001:1001 "$TLS_DIR/server.cert.pem" "$TLS_DIR/server.key.pem" 2>/dev/null || true
        
        log_success "Certificates copied from certbot container to $TLS_DIR"
    else
        # Try to copy from Let's Encrypt directory (if running on host)
        local letsencrypt_dir="/etc/letsencrypt/live/$DOMAIN"
        if [[ -d "$letsencrypt_dir" ]]; then
            cp "$letsencrypt_dir/fullchain.pem" "$TLS_DIR/server.cert.pem"
            cp "$letsencrypt_dir/privkey.pem" "$TLS_DIR/server.key.pem"
            
            # Set proper permissions and ownership
            chmod 644 "$TLS_DIR/server.cert.pem"
            chmod 644 "$TLS_DIR/server.key.pem"  # Make readable by container user
            chmod 755 "$TLS_DIR"  # Make directory accessible
            # Try to set ownership, but don't fail if we can't
            chown 1001:1001 "$TLS_DIR/server.cert.pem" "$TLS_DIR/server.key.pem" 2>/dev/null || true
            
            log_success "Certificates copied from Let's Encrypt directory to $TLS_DIR"
        else
            log_warn "No certificates found to copy"
            log_info "Certificates may have been issued but not accessible for copying"
        fi
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
    echo "  self-signed - Generate self-signed certificate (fallback)"
    echo ""
    echo "Examples:"
    echo "  $0 issue     # Issue new certificates"
    echo "  $0 renew     # Renew existing certificates"
    echo "  $0 status    # Check certificate status"
    echo "  $0 self-signed # Generate self-signed certificate"
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
        "self-signed")
            generate_self_signed_certificate
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
