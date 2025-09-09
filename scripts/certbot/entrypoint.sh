#!/bin/sh

# ============================================================================
# CERTBOT ENTRYPOINT SCRIPT
# ============================================================================
# Best Practice: Centralized certificate management
# ============================================================================

set -euo pipefail

# Configuration
CERT_DIR="${CERT_DIR:-/etc/letsencrypt}"
DOMAIN="${IRC_DOMAIN:-irc.atl.chat}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@allthingslinux.org}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] CERTBOT: $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] CERTBOT: $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] CERTBOT: $1${NC}"
}

# Function to issue certificates
issue_certificates() {
    log_info "Issuing SSL certificates for ${DOMAIN}..."

    if certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
        --dns-cloudflare-propagation-seconds=60 \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --expand \
        --non-interactive \
        -d "$DOMAIN" \
        -d "*.$DOMAIN"; then

        log_success "SSL certificates issued successfully!"
        return 0
    else
        log_error "Failed to issue SSL certificates"
        return 1
    fi
}

# Function to renew certificates
renew_certificates() {
    log_info "Checking for certificate renewals..."

    if certbot renew --quiet --no-random-sleep-on-renew; then
        log_success "Certificate renewal check completed"
        return 0
    else
        log_error "Certificate renewal failed"
        return 1
    fi
}

# Function to show certificate status
show_status() {
    log_info "Certificate Status:"

    if [ -d "$CERT_DIR/live" ]; then
        for domain_dir in "$CERT_DIR/live"/*; do
            if [ -d "$domain_dir" ]; then
                domain=$(basename "$domain_dir")
                cert_file="$domain_dir/fullchain.pem"

                if [ -f "$cert_file" ]; then
                    expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
                    log_info "Domain: $domain"
                    log_info "  Expires: $expiry"

                    # Check if expiry is within 30 days
                    expiry_seconds=$(date -d "$expiry" +%s 2>/dev/null)
                    current_seconds=$(date +%s)
                    days_left=$(((expiry_seconds - current_seconds) / 86400))

                    if [ $days_left -le 30 ]; then
                        log_warning "  WARNING: Expires in $days_left days - renewal needed!"
                    else
                        log_info "  Days left: $days_left"
                    fi
                fi
            fi
        done
    else
        log_info "No certificates found"
    fi
}

# Function to run continuous monitoring
monitor_continuous() {
    log_info "Starting continuous certificate monitoring..."
    log_info "Check interval: 24 hours"

    while true; do
        log_info "Performing certificate maintenance..."

        # Check for renewals
        renew_certificates

        # Show current status
        show_status

        log_info "Sleeping for 24 hours..."
        sleep 86400
    done
}

# Main function
main() {
    local command="${1:-monitor}"

    case "$command" in
    "issue")
        issue_certificates
        ;;
    "renew")
        renew_certificates
        ;;
    "status")
        show_status
        ;;
    "monitor")
        monitor_continuous
        ;;
    *)
        log_error "Usage: $0 [issue|renew|status|monitor]"
        log_info "Commands:"
        log_info "  issue   - Issue new certificates"
        log_info "  renew   - Renew existing certificates"
        log_info "  status  - Show certificate status"
        log_info "  monitor - Continuous monitoring (default)"
        exit 1
        ;;
    esac
}

# Run main function
main "$@"
