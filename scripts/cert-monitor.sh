#!/bin/bash

# ============================================================================
# CERTIFICATE MONITORING SCRIPT
# ============================================================================
# Monitors SSL/TLS certificates and handles automatic renewal
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
CERT_DIR="${CERT_DIR:-${PROJECT_ROOT}/.runtime/certs}"
CERT_FILE="${CERT_FILE:-server.cert.pem}"
KEY_FILE="${KEY_FILE:-server.key.pem}"
RENEWAL_THRESHOLD_DAYS="${RENEWAL_THRESHOLD_DAYS:-30}"
CHECK_INTERVAL="${CHECK_INTERVAL:-86400}"  # 24 hours in seconds
LOG_FILE="${LOG_FILE:-${PROJECT_ROOT}/.runtime/logs/cert-monitor.log}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: $1" >> "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: $1" >> "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: WARNING: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: WARNING: $1" >> "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: ERROR: $1${NC}"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] CERT-MONITOR: ERROR: $1" >> "$LOG_FILE"
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function to check certificate validity
check_certificate() {
    local cert_path="$CERT_DIR/live/${IRC_DOMAIN:-irc.atl.chat}/fullchain.pem"
    local key_path="$CERT_DIR/live/${IRC_DOMAIN:-irc.atl.chat}/privkey.pem"

    # Check if certificate files exist
    if [[ ! -f "$cert_path" ]] || [[ ! -f "$key_path" ]]; then
        log_warning "Certificate files not found. Using self-signed certificates."
        return 1
    fi

    # Get certificate expiry date
    local expiry_date
    expiry_date=$(openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | cut -d= -f2)

    if [[ -z "$expiry_date" ]]; then
        log_error "Failed to read certificate expiry date"
        return 1
    fi

    # Convert expiry date to seconds since epoch
    local expiry_seconds
    expiry_seconds=$(date -d "$expiry_date" +%s 2>/dev/null)

    if [[ -z "$expiry_seconds" ]]; then
        log_error "Failed to parse certificate expiry date: $expiry_date"
        return 1
    fi

    # Get current date in seconds
    local current_seconds
    current_seconds=$(date +%s)

    # Calculate days until expiry
    local seconds_until_expiry=$((expiry_seconds - current_seconds))
    local days_until_expiry=$((seconds_until_expiry / 86400))

    log_info "Certificate expires on: $expiry_date"
    log_info "Days until expiry: $days_until_expiry"

    # Check if renewal is needed
    if [[ $days_until_expiry -le $RENEWAL_THRESHOLD_DAYS ]]; then
        log_warning "Certificate expires in $days_until_expiry days. Renewal needed."
        return 0  # Needs renewal
    else
        log_info "Certificate is valid for $days_until_expiry days. No action needed."
        return 2  # Still valid
    fi
}

# Function to renew certificate
renew_certificate() {
    log_info "Starting certificate renewal process..."

    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        log_error "Docker command not found. Cannot renew certificates."
        return 1
    fi

    # Check if certbot-renew container is running or can be started
    if docker ps --format "{{.Names}}" | grep -q "^unrealircd-certbot-renew$"; then
        log_info "Certbot renewal container is running"
    else
        log_info "Starting certbot renewal container..."
        cd "$PROJECT_ROOT"

        if docker compose up -d unrealircd-certbot-renew; then
            log_success "Certbot renewal container started successfully"

            # Wait for renewal to complete
            log_info "Waiting for certificate renewal to complete..."
            sleep 30

            # Check if renewal was successful
            if check_certificate; then
                case $? in
                    0)
                        log_success "Certificate renewed successfully!"
                        # Copy certificates to UnrealIRCd directory
                        copy_certificates
                        # Reload UnrealIRCd configuration
                        reload_unrealircd
                        ;;
                    1)
                        log_error "Certificate renewal failed - no certificates found"
                        ;;
                    2)
                        log_info "Certificate renewal completed but still has time remaining"
                        ;;
                esac
            fi

            # Stop the renewal container
            docker compose stop unrealircd-certbot-renew
        else
            log_error "Failed to start certbot renewal container"
            return 1
        fi
    fi
}

# Function to copy certificates to UnrealIRCd directory
copy_certificates() {
    local letsencrypt_cert="$CERT_DIR/live/${IRC_DOMAIN:-irc.atl.chat}/fullchain.pem"
    local letsencrypt_key="$CERT_DIR/live/${IRC_DOMAIN:-irc.atl.chat}/privkey.pem"
    local unrealircd_cert="$CERT_DIR/server.cert.pem"
    local unrealircd_key="$CERT_DIR/server.key.pem"

    if [[ -f "$letsencrypt_cert" ]] && [[ -f "$letsencrypt_key" ]]; then
        log_info "Copying Let's Encrypt certificates to UnrealIRCd directory..."
        cp "$letsencrypt_cert" "$unrealircd_cert"
        cp "$letsencrypt_key" "$unrealircd_key"
        log_success "Certificates copied successfully"
    else
        log_warning "Let's Encrypt certificates not found"
    fi
}

# Function to reload UnrealIRCd configuration
reload_unrealircd() {
    log_info "Reloading UnrealIRCd configuration..."

    if docker ps --format "{{.Names}}" | grep -q "^unrealircd$"; then
        if docker compose exec -T unrealircd /usr/local/unrealircd/bin/unrealircd rehash; then
            log_success "UnrealIRCd configuration reloaded successfully"
        else
            log_error "Failed to reload UnrealIRCd configuration"
        fi
    else
        log_warning "UnrealIRCd container is not running"
    fi
}

# Function to issue new certificate
issue_certificate() {
    log_info "Issuing new certificate..."

    cd "$PROJECT_ROOT"

    if docker compose --profile cert-issue up unrealircd-certbot; then
        log_success "Certificate issued successfully!"

        # Copy certificates to UnrealIRCd directory
        copy_certificates

        # Reload UnrealIRCd configuration
        reload_unrealircd
    else
        log_error "Failed to issue certificate"
        return 1
    fi
}

# Function to show certificate status
show_status() {
    log_info "=== Certificate Status ==="

    # Check Let's Encrypt certificates
    local letsencrypt_cert="$CERT_DIR/live/${IRC_DOMAIN:-irc.atl.chat}/fullchain.pem"
    if [[ -f "$letsencrypt_cert" ]]; then
        openssl x509 -in "$letsencrypt_cert" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)" | while read -r line; do
            log_info "$line"
        done
    else
        log_info "No Let's Encrypt certificate found"
    fi

    # Check UnrealIRCd certificates
    local unrealircd_cert="$CERT_DIR/server.cert.pem"
    if [[ -f "$unrealircd_cert" ]]; then
        log_info "UnrealIRCd certificate found"
        openssl x509 -in "$unrealircd_cert" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)" | while read -r line; do
            log_info "IRC: $line"
        done
    else
        log_info "No UnrealIRCd certificate found"
    fi
}

# Function to run continuous monitoring
monitor_continuous() {
    log_info "Starting continuous certificate monitoring..."
    log_info "Check interval: ${CHECK_INTERVAL} seconds"

    while true; do
        log_info "Checking certificate status..."

        if check_certificate; then
            case $? in
                0)
                    log_info "Certificate renewal needed"
                    renew_certificate
                    ;;
                1)
                    log_info "No certificates found - attempting to issue new certificate"
                    issue_certificate
                    ;;
                2)
                    log_info "Certificate is still valid"
                    ;;
            esac
        fi

        log_info "Sleeping for ${CHECK_INTERVAL} seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Function to show usage
show_usage() {
    echo "Certificate Monitoring Script"
    echo "============================"
    echo
    echo "Usage:"
    echo "  $0 [command]"
    echo
    echo "Commands:"
    echo "  monitor    - Start continuous monitoring (default)"
    echo "  check      - Check certificate status once"
    echo "  renew      - Renew certificate if needed"
    echo "  issue      - Issue new certificate"
    echo "  status     - Show detailed certificate status"
    echo "  help       - Show this help message"
    echo
    echo "Environment Variables:"
    echo "  CERT_DIR                 - Certificate directory (default: .runtime/certs)"
    echo "  RENEWAL_THRESHOLD_DAYS  - Days before expiry to renew (default: 30)"
    echo "  CHECK_INTERVAL          - Monitoring interval in seconds (default: 86400)"
    echo "  IRC_DOMAIN              - IRC domain for certificates (default: irc.atl.chat)"
    echo
    echo "Examples:"
    echo "  $0 monitor     # Start monitoring"
    echo "  $0 check       # Check once"
    echo "  $0 renew       # Force renewal"
    echo "  $0 status      # Show status"
}

# Main function
main() {
    local command="${1:-monitor}"

    case "$command" in
        "monitor")
            monitor_continuous
            ;;
        "check")
            check_certificate
            ;;
        "renew")
            renew_certificate
            ;;
        "issue")
            issue_certificate
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
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
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
