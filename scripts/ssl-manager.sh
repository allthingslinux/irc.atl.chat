#!/bin/bash

# ============================================================================
# SIMPLE SSL CERTIFICATE MANAGER
# ============================================================================
# Just the essentials - automatic renewal, monitoring, and service restart
# ============================================================================

set -euo pipefail

# Simple configuration
DOMAIN="${IRC_ROOT_DOMAIN:-irc.atl.chat}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@allthingslinux.org}"
TLS_DIR="/tls"
LETSENCRYPT_DIR="/letsencrypt"
CREDENTIALS_FILE="./cloudflare-credentials.ini"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[$(date)] SSL: $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date)] SSL WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date)] SSL ERROR: $1${NC}"
}

# Check if certificates exist and are valid
check_certificates() {
    local cert_file="$TLS_DIR/server.cert.pem"

    if [[ ! -f "$cert_file" ]]; then
        log_warn "No SSL certificate found at $cert_file"
        return 1
    fi

    # Check expiry
    local expiry_date
    local days_until_expiry

    if ! expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2); then
        log_error "Certificate file is corrupted"
        return 1
    fi

    local expiry_timestamp
    local current_timestamp

    expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
    current_timestamp=$(date +%s)
    days_until_expiry=$(((expiry_timestamp - current_timestamp) / 86400))

    if [[ $days_until_expiry -le 0 ]]; then
        log_error "Certificate expired $((-days_until_expiry)) days ago"
        return 1
    elif [[ $days_until_expiry -le 7 ]]; then
        log_warn "Certificate expires in $days_until_expiry days - renewal needed"
        return 1
    elif [[ $days_until_expiry -le 30 ]]; then
        log_warn "Certificate expires in $days_until_expiry days"
        return 0
    else
        log_info "Certificate is valid for $days_until_expiry more days"
        return 0
    fi
}

# Issue new certificates
issue_certificates() {
    log_info "Issuing new SSL certificates for $DOMAIN..."

    # Check if credentials exist
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log_error "Cloudflare credentials not found at $CREDENTIALS_FILE"
        log_info "Please create cloudflare-credentials.ini with your API token"
        return 1
    fi

    # Run certbot
    if docker run --rm \
        -v "$LETSENCRYPT_DIR:/etc/letsencrypt" \
        -v "$CREDENTIALS_FILE:/etc/letsencrypt/cloudflare-credentials.ini:ro" \
        certbot/dns-cloudflare:latest \
        certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        -d "$DOMAIN" \
        -d "*.$DOMAIN" 2>/dev/null; then

        log_info "Certificates issued successfully"
        copy_certificates
        return 0
    else
        log_error "Failed to issue certificates"
        return 1
    fi
}

# Renew existing certificates
renew_certificates() {
    log_info "Checking for certificate renewal..."

    if ! check_certificates; then
        log_info "Certificates need renewal - attempting renewal..."

        if docker run --rm \
            -v "$LETSENCRYPT_DIR:/etc/letsencrypt" \
            -v "$CREDENTIALS_FILE:/etc/letsencrypt/cloudflare-credentials.ini:ro" \
            certbot/dns-cloudflare:latest \
            certbot renew \
            --dns-cloudflare \
            --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
            --quiet \
            --no-random-sleep-on-renew 2>/dev/null; then

            log_info "Certificates renewed successfully"
            copy_certificates
            restart_services
            return 0
        else
            log_error "Certificate renewal failed"
            return 1
        fi
    else
        log_info "Certificates are still valid - no renewal needed"
        return 0
    fi
}

# Copy certificates to UnrealIRCd
copy_certificates() {
    log_info "Copying certificates to UnrealIRCd..."

    # Create directory if it doesn't exist
    mkdir -p "$TLS_DIR"

    # Copy certificates
    if [[ -f "$LETSENCRYPT_DIR/live/$DOMAIN/fullchain.pem" ]]; then
        cp "$LETSENCRYPT_DIR/live/$DOMAIN/fullchain.pem" "$TLS_DIR/server.cert.pem"
        cp "$LETSENCRYPT_DIR/live/$DOMAIN/privkey.pem" "$TLS_DIR/server.key.pem"

        # Set permissions
        chmod 644 "$TLS_DIR/server.cert.pem" "$TLS_DIR/server.key.pem" 2>/dev/null || true
        chmod 755 "$TLS_DIR" 2>/dev/null || true

        log_info "Certificates copied successfully"
        return 0
    else
        log_error "Certificate files not found in Let's Encrypt directory"
        return 1
    fi
}

# Restart services that use certificates
restart_services() {
    log_info "Restarting services that use certificates..."

    # Try to restart services using Docker socket if available
    if [[ -S /var/run/docker.sock ]]; then
        # Restart UnrealIRCd
        if docker restart unrealircd >/dev/null 2>&1; then
            log_info "UnrealIRCd restarted"
        fi

        # Restart WebPanel
        if docker restart unrealircd-webpanel >/dev/null 2>&1; then
            log_info "WebPanel restarted"
        fi
    else
        log_warn "Docker socket not available - services may need manual restart"
    fi
}

# Main command handler
main() {
    local command="${1:-check}"

    case "$command" in
    "check")
        if check_certificates; then
            echo "OK"
            exit 0
        else
            echo "NEEDS_RENEWAL"
            exit 1
        fi
        ;;
    "issue")
        if issue_certificates; then
            log_info "Certificate setup completed successfully"
            exit 0
        else
            log_error "Certificate setup failed"
            exit 1
        fi
        ;;
    "renew")
        if renew_certificates; then
            log_info "Certificate renewal completed successfully"
            exit 0
        else
            log_error "Certificate renewal failed"
            exit 1
        fi
        ;;
    "copy")
        copy_certificates
        ;;
    "restart")
        restart_services
        ;;
    *)
        echo "Usage: $0 [check|issue|renew|copy|restart]"
        exit 1
        ;;
    esac
}

main "$@"
