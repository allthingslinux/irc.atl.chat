#!/bin/bash
# Enhanced Certificate Monitoring and Renewal System
# Implements proactive monitoring, automated renewal, and health dashboard

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly CONFIG_FILE="${PROJECT_DIR}/.env"
readonly CERT_CONFIG_FILE="${PROJECT_DIR}/.runtime/cert-monitor.conf"
readonly LOG_FILE="${PROJECT_DIR}/.runtime/logs/cert-monitor.log"
readonly ALERT_LOG_FILE="${PROJECT_DIR}/.runtime/logs/cert-alerts.log"

# Default thresholds (days)
readonly DEFAULT_WARNING_THRESHOLD=30
readonly DEFAULT_CRITICAL_THRESHOLD=7
readonly DEFAULT_RENEWAL_THRESHOLD=30

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# ============================================================================
# LOGGING FUNCTIONS
# ============================================================================

log_info() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
    echo -e "${BLUE}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
}

log_warn() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >> "$ALERT_LOG_FILE"
}

log_error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1"
    echo -e "${RED}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >> "$ALERT_LOG_FILE"
}

log_critical() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [CRITICAL] $1"
    echo -e "${RED}${BOLD}$msg${NC}"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg" >> "$ALERT_LOG_FILE"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Ensure required directories exist
ensure_directories() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$ALERT_LOG_FILE")"
    mkdir -p "$(dirname "$CERT_CONFIG_FILE")"
}

# Load configuration
load_config() {
    # Load environment variables
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi

    # Load certificate monitoring configuration
    if [[ -f "$CERT_CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CERT_CONFIG_FILE"
    fi

    # Set defaults if not configured
    CERT_WARNING_THRESHOLD="${CERT_WARNING_THRESHOLD:-$DEFAULT_WARNING_THRESHOLD}"
    CERT_CRITICAL_THRESHOLD="${CERT_CRITICAL_THRESHOLD:-$DEFAULT_CRITICAL_THRESHOLD}"
    CERT_RENEWAL_THRESHOLD="${CERT_RENEWAL_THRESHOLD:-$DEFAULT_RENEWAL_THRESHOLD}"
    CERT_CHECK_INTERVAL="${CERT_CHECK_INTERVAL:-3600}"  # 1 hour default
    CERT_RENEWAL_RETRY_COUNT="${CERT_RENEWAL_RETRY_COUNT:-3}"
    CERT_RENEWAL_RETRY_DELAY="${CERT_RENEWAL_RETRY_DELAY:-300}"  # 5 minutes
    CERT_ALERT_EMAIL="${CERT_ALERT_EMAIL:-${LETSENCRYPT_EMAIL:-}}"
    CERT_WEBHOOK_URL="${CERT_WEBHOOK_URL:-}"
    PROSODY_DOMAIN="${PROSODY_DOMAIN:-localhost}"
}

# Get container name
get_container_name() {
    # Try different possible container names
    for name in "xmpp-prosody-dev" "xmpp-prosody-1" "xmpp-prosody"; do
        if docker ps --format "{{.Names}}" | grep -q "^${name}$"; then
            echo "$name"
            return 0
        fi
    done

    # Fallback: find any running container with prosody in the name
    local container_name
    container_name=$(docker ps --format "{{.Names}}" | grep prosody | head -1)
    if [[ -n "$container_name" ]]; then
        echo "$container_name"
        return 0
    fi

    echo "xmpp-prosody-1"  # Default fallback
}

# Check if running in container
is_docker_environment() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Run command in container
run_in_container() {
    # Check if we're in test mode
    if [[ "${CERT_TEST_MODE:-false}" == "true" ]]; then
        log_warn "Test mode: Skipping container command: $*" >&2
        # Return mock data for specific commands
        case "$1" in
            "test")
                return 0  # Pretend files exist
                ;;
            "openssl")
                if [[ "$2" == "x509" ]]; then
                    echo "notAfter=Dec 31 23:59:59 2025 GMT"
                fi
                return 0
                ;;
            *)
                return 0
                ;;
        esac
    fi

    if is_docker_environment; then
        "$@"
    else
        if ! docker ps --format "{{.Names}}" 2>/dev/null | grep -q prosody; then
            log_warn "No Prosody container running. Skipping command: $*"
            return 1
        fi
        docker exec "$(get_container_name)" "$@"
    fi
}

# ============================================================================
# CERTIFICATE MONITORING FUNCTIONS
# ============================================================================

# Get certificate expiration date
get_cert_expiry() {
    local cert_file="$1"
    local expiry_date

    if run_in_container test -f "$cert_file" 2>/dev/null; then
        expiry_date=$(run_in_container openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$expiry_date" ]]; then
            date -d "$expiry_date" +%s 2>/dev/null || echo "0"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# Calculate days until expiry
days_until_expiry() {
    local expiry_epoch="$1"
    local current_epoch
    current_epoch=$(date +%s)

    if [[ "$expiry_epoch" -eq 0 ]]; then
        echo "-1"  # Certificate not found or invalid
    else
        echo $(( (expiry_epoch - current_epoch) / 86400 ))
    fi
}

# Check certificate status
check_certificate_status() {
    local domain="$1"
    local cert_file="/etc/prosody/certs/$domain.crt"
    local key_file="/etc/prosody/certs/$domain.key"
    local status="unknown"
    local days_left="-1"
    local expiry_date=""
    local issuer=""
    local subject=""

    log_info "Checking certificate for domain: $domain"

    # Check if certificate files exist
    if ! run_in_container test -f "$cert_file"; then
        log_error "Certificate file not found: $cert_file"
        echo "missing|$days_left|$expiry_date|$issuer|$subject"
        return 1
    fi

    if ! run_in_container test -f "$key_file"; then
        log_error "Private key file not found: $key_file"
        echo "missing_key|$days_left|$expiry_date|$issuer|$subject"
        return 1
    fi

    # Get certificate details
    local expiry_epoch
    expiry_epoch=$(get_cert_expiry "$cert_file")
    days_left=$(days_until_expiry "$expiry_epoch")

    if [[ "$days_left" -eq -1 ]]; then
        log_error "Could not read certificate expiry for $domain"
        echo "invalid|$days_left|$expiry_date|$issuer|$subject"
        return 1
    fi

    # Get additional certificate info
    expiry_date=$(run_in_container openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2 || echo "unknown")
    issuer=$(run_in_container openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/issuer=//' || echo "unknown")
    subject=$(run_in_container openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/subject=//' || echo "unknown")

    # Determine status based on days left
    if [[ "$days_left" -le "$CERT_CRITICAL_THRESHOLD" ]]; then
        status="critical"
        log_critical "Certificate for $domain expires in $days_left days (CRITICAL)"
    elif [[ "$days_left" -le "$CERT_WARNING_THRESHOLD" ]]; then
        status="warning"
        log_warn "Certificate for $domain expires in $days_left days (WARNING)"
    else
        status="ok"
        log_success "Certificate for $domain expires in $days_left days (OK)"
    fi

    echo "$status|$days_left|$expiry_date|$issuer|$subject"
    return 0
}

# Monitor all certificates
monitor_certificates() {
    local domains=("$PROSODY_DOMAIN")
    local overall_status="ok"
    local cert_count=0
    local warning_count=0
    local critical_count=0
    local missing_count=0

    log_info "Starting certificate monitoring for domains: ${domains[*]}"

    # Create status report
    local status_file="${PROJECT_DIR}/.runtime/cert-status.json"
    local timestamp
    timestamp=$(date -Iseconds)

    echo "{" > "$status_file"
    echo "  \"timestamp\": \"$timestamp\"," >> "$status_file"
    echo "  \"thresholds\": {" >> "$status_file"
    echo "    \"warning\": $CERT_WARNING_THRESHOLD," >> "$status_file"
    echo "    \"critical\": $CERT_CRITICAL_THRESHOLD" >> "$status_file"
    echo "  }," >> "$status_file"
    echo "  \"certificates\": [" >> "$status_file"

    local first=true
    for domain in "${domains[@]}"; do
        if [[ "$first" == "false" ]]; then
            echo "," >> "$status_file"
        fi
        first=false

        local cert_info
        cert_info=$(check_certificate_status "$domain")
        local status days_left expiry_date issuer subject
        IFS='|' read -r status days_left expiry_date issuer subject <<< "$cert_info"

        ((cert_count++))

        case "$status" in
            "critical"|"missing"|"missing_key"|"invalid")
                ((critical_count++))
                overall_status="critical"
                ;;
            "warning")
                ((warning_count++))
                if [[ "$overall_status" != "critical" ]]; then
                    overall_status="warning"
                fi
                ;;
        esac

        # Add to JSON report
        echo "    {" >> "$status_file"
        echo "      \"domain\": \"$domain\"," >> "$status_file"
        echo "      \"status\": \"$status\"," >> "$status_file"
        echo "      \"days_until_expiry\": $days_left," >> "$status_file"
        echo "      \"expiry_date\": \"$expiry_date\"," >> "$status_file"
        echo "      \"issuer\": \"$issuer\"," >> "$status_file"
        echo "      \"subject\": \"$subject\"" >> "$status_file"
        echo "    }" >> "$status_file"
    done

    echo "  ]," >> "$status_file"
    echo "  \"summary\": {" >> "$status_file"
    echo "    \"overall_status\": \"$overall_status\"," >> "$status_file"
    echo "    \"total_certificates\": $cert_count," >> "$status_file"
    echo "    \"warning_count\": $warning_count," >> "$status_file"
    echo "    \"critical_count\": $critical_count" >> "$status_file"
    echo "  }" >> "$status_file"
    echo "}" >> "$status_file"

    log_info "Certificate monitoring complete. Status: $overall_status"
    log_info "Total: $cert_count, Warnings: $warning_count, Critical: $critical_count"

    # Send alerts if needed
    if [[ "$critical_count" -gt 0 ]] || [[ "$warning_count" -gt 0 ]]; then
        send_alert "$overall_status" "$cert_count" "$warning_count" "$critical_count"
    fi

    return 0
}

# ============================================================================
# CERTIFICATE RENEWAL FUNCTIONS
# ============================================================================

# Attempt certificate renewal with retry logic
renew_certificate_with_retry() {
    local domain="$1"
    local attempt=1
    local max_attempts="$CERT_RENEWAL_RETRY_COUNT"

    log_info "Starting certificate renewal for $domain (max attempts: $max_attempts)"

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Renewal attempt $attempt/$max_attempts for $domain"

        if renew_certificate_single_attempt "$domain"; then
            log_success "Certificate renewal successful for $domain on attempt $attempt"
            return 0
        else
            log_error "Certificate renewal failed for $domain on attempt $attempt"

            if [[ $attempt -lt $max_attempts ]]; then
                log_info "Waiting ${CERT_RENEWAL_RETRY_DELAY} seconds before retry..."
                sleep "$CERT_RENEWAL_RETRY_DELAY"
            fi
        fi

        ((attempt++))
    done

    log_critical "Certificate renewal failed for $domain after $max_attempts attempts"
    return 1
}

# Single certificate renewal attempt
renew_certificate_single_attempt() {
    local domain="$1"

    log_info "Attempting to renew certificate for $domain"

    # Check if Let's Encrypt certificate exists
    if run_in_container test -f "/etc/letsencrypt/live/$domain/fullchain.pem"; then
        log_info "Found Let's Encrypt certificate, attempting renewal..."

        # Run certbot renewal
        if docker compose -f "$PROJECT_DIR/docker-compose.yml" --profile renewal run --rm xmpp-certbot-renew; then
            log_success "Certbot renewal completed successfully"

            # Copy renewed certificates to Prosody
            if copy_letsencrypt_to_prosody "$domain"; then
                log_success "Certificates copied to Prosody successfully"

                # Reload Prosody configuration
                if reload_prosody_config; then
                    log_success "Prosody configuration reloaded successfully"
                    return 0
                else
                    log_error "Failed to reload Prosody configuration"
                    return 1
                fi
            else
                log_error "Failed to copy certificates to Prosody"
                return 1
            fi
        else
            log_error "Certbot renewal failed"
            return 1
        fi
    else
        log_warn "Let's Encrypt certificate not found for $domain, generating new certificate..."

        # Generate new Let's Encrypt certificate
        if docker compose -f "$PROJECT_DIR/docker-compose.yml" --profile letsencrypt run --rm xmpp-certbot; then
            log_success "New Let's Encrypt certificate generated"

            if copy_letsencrypt_to_prosody "$domain"; then
                log_success "New certificate copied to Prosody successfully"

                if reload_prosody_config; then
                    log_success "Prosody configuration reloaded successfully"
                    return 0
                else
                    log_error "Failed to reload Prosody configuration"
                    return 1
                fi
            else
                log_error "Failed to copy new certificate to Prosody"
                return 1
            fi
        else
            log_error "Failed to generate new Let's Encrypt certificate"
            return 1
        fi
    fi
}

# Copy Let's Encrypt certificates to Prosody
copy_letsencrypt_to_prosody() {
    local domain="$1"
    local container_name
    container_name=$(get_container_name)

    log_info "Copying Let's Encrypt certificates to Prosody for $domain"

    # Copy certificate files
    if docker cp ".runtime/certs/live/$domain/fullchain.pem" "$container_name:/etc/prosody/certs/$domain.crt" && \
       docker cp ".runtime/certs/live/$domain/privkey.pem" "$container_name:/etc/prosody/certs/$domain.key"; then

        # Set proper permissions
        run_in_container chown prosody:prosody "/etc/prosody/certs/$domain.crt" "/etc/prosody/certs/$domain.key"
        run_in_container chmod 644 "/etc/prosody/certs/$domain.crt"
        run_in_container chmod 600 "/etc/prosody/certs/$domain.key"

        log_success "Certificates copied and permissions set"
        return 0
    else
        log_error "Failed to copy certificate files"
        return 1
    fi
}

# Reload Prosody configuration
reload_prosody_config() {
    log_info "Reloading Prosody configuration..."

    if run_in_container prosodyctl reload; then
        log_success "Prosody configuration reloaded"
        return 0
    else
        log_error "Failed to reload Prosody configuration"
        return 1
    fi
}

# Auto-renewal check and execution
auto_renewal_check() {
    local domains=("$PROSODY_DOMAIN")
    local renewal_needed=false

    log_info "Checking if certificate renewal is needed..."

    for domain in "${domains[@]}"; do
        local cert_info
        cert_info=$(check_certificate_status "$domain")
        local status days_left
        IFS='|' read -r status days_left _ _ _ <<< "$cert_info"

        if [[ "$days_left" -le "$CERT_RENEWAL_THRESHOLD" ]] && [[ "$days_left" -gt 0 ]]; then
            log_info "Certificate for $domain needs renewal ($days_left days left, threshold: $CERT_RENEWAL_THRESHOLD)"
            renewal_needed=true

            if renew_certificate_with_retry "$domain"; then
                log_success "Auto-renewal completed successfully for $domain"
            else
                log_critical "Auto-renewal failed for $domain"
            fi
        elif [[ "$days_left" -le 0 ]]; then
            log_critical "Certificate for $domain has already expired!"
            renewal_needed=true

            if renew_certificate_with_retry "$domain"; then
                log_success "Expired certificate renewed successfully for $domain"
            else
                log_critical "Failed to renew expired certificate for $domain"
            fi
        else
            log_info "Certificate for $domain does not need renewal ($days_left days left)"
        fi
    done

    if [[ "$renewal_needed" == "false" ]]; then
        log_info "No certificates need renewal at this time"
    fi
}

# ============================================================================
# ALERTING FUNCTIONS
# ============================================================================

# Send alert notifications
send_alert() {
    local status="$1"
    local total="$2"
    local warnings="$3"
    local critical="$4"

    local subject="Certificate Alert: $status status detected"
    local message="Certificate monitoring alert for $(hostname -f)

Status: $status
Total certificates: $total
Warnings: $warnings
Critical: $critical

Timestamp: $(date)

Please check certificate status and renew if necessary.
"

    log_info "Sending alert notification: $subject"

    # Send email alert if configured
    if [[ -n "$CERT_ALERT_EMAIL" ]] && command -v mail >/dev/null 2>&1; then
        echo "$message" | mail -s "$subject" "$CERT_ALERT_EMAIL"
        log_info "Email alert sent to $CERT_ALERT_EMAIL"
    fi

    # Send webhook alert if configured
    if [[ -n "$CERT_WEBHOOK_URL" ]] && command -v curl >/dev/null 2>&1; then
        local webhook_payload
        webhook_payload=$(cat <<EOF
{
  "text": "$subject",
  "attachments": [
    {
      "color": "$([ "$status" = "critical" ] && echo "danger" || echo "warning")",
      "fields": [
        {"title": "Status", "value": "$status", "short": true},
        {"title": "Total Certificates", "value": "$total", "short": true},
        {"title": "Warnings", "value": "$warnings", "short": true},
        {"title": "Critical", "value": "$critical", "short": true}
      ]
    }
  ]
}
EOF
        )

        if curl -X POST -H 'Content-type: application/json' --data "$webhook_payload" "$CERT_WEBHOOK_URL"; then
            log_info "Webhook alert sent successfully"
        else
            log_error "Failed to send webhook alert"
        fi
    fi
}

# ============================================================================
# DASHBOARD FUNCTIONS
# ============================================================================

# Generate certificate health dashboard
generate_dashboard() {
    local dashboard_file="${PROJECT_DIR}/.runtime/cert-dashboard.html"
    local status_file="${PROJECT_DIR}/.runtime/cert-status.json"

    if [[ ! -f "$status_file" ]]; then
        log_error "Status file not found. Run monitoring first."
        return 1
    fi

    log_info "Generating certificate health dashboard..."

    cat > "$dashboard_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Certificate Health Dashboard</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            border-bottom: 2px solid #eee;
            padding-bottom: 20px;
        }
        .status-overview {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .status-card {
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            color: white;
        }
        .status-ok { background-color: #28a745; }
        .status-warning { background-color: #ffc107; color: #212529; }
        .status-critical { background-color: #dc3545; }
        .cert-table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        .cert-table th,
        .cert-table td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        .cert-table th {
            background-color: #f8f9fa;
            font-weight: 600;
        }
        .status-badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: bold;
            text-transform: uppercase;
        }
        .badge-ok { background-color: #d4edda; color: #155724; }
        .badge-warning { background-color: #fff3cd; color: #856404; }
        .badge-critical { background-color: #f8d7da; color: #721c24; }
        .last-updated {
            text-align: center;
            color: #666;
            font-size: 14px;
            margin-top: 20px;
        }
        .refresh-btn {
            background-color: #007bff;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 14px;
        }
        .refresh-btn:hover {
            background-color: #0056b3;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔒 Certificate Health Dashboard</h1>
            <button class="refresh-btn" onclick="location.reload()">Refresh</button>
        </div>

        <div id="dashboard-content">
            Loading certificate status...
        </div>

        <div class="last-updated" id="last-updated">
        </div>
    </div>

    <script>
        async function loadCertificateStatus() {
            try {
                const response = await fetch('cert-status.json');
                const data = await response.json();
                renderDashboard(data);
            } catch (error) {
                document.getElementById('dashboard-content').innerHTML =
                    '<div style="color: red; text-align: center;">Error loading certificate status</div>';
            }
        }

        function renderDashboard(data) {
            const content = document.getElementById('dashboard-content');
            const lastUpdated = document.getElementById('last-updated');

            // Render overview cards
            const overviewHtml = `
                <div class="status-overview">
                    <div class="status-card status-${data.summary.overall_status}">
                        <h3>Overall Status</h3>
                        <h2>${data.summary.overall_status.toUpperCase()}</h2>
                    </div>
                    <div class="status-card status-ok">
                        <h3>Total Certificates</h3>
                        <h2>${data.summary.total_certificates}</h2>
                    </div>
                    <div class="status-card status-warning">
                        <h3>Warnings</h3>
                        <h2>${data.summary.warning_count}</h2>
                    </div>
                    <div class="status-card status-critical">
                        <h3>Critical</h3>
                        <h2>${data.summary.critical_count}</h2>
                    </div>
                </div>
            `;

            // Render certificate table
            const tableRows = data.certificates.map(cert => `
                <tr>
                    <td>${cert.domain}</td>
                    <td><span class="status-badge badge-${cert.status}">${cert.status}</span></td>
                    <td>${cert.days_until_expiry >= 0 ? cert.days_until_expiry + ' days' : 'Invalid'}</td>
                    <td>${cert.expiry_date}</td>
                    <td title="${cert.issuer}">${cert.issuer.length > 50 ? cert.issuer.substring(0, 50) + '...' : cert.issuer}</td>
                </tr>
            `).join('');

            const tableHtml = `
                <table class="cert-table">
                    <thead>
                        <tr>
                            <th>Domain</th>
                            <th>Status</th>
                            <th>Days Until Expiry</th>
                            <th>Expiry Date</th>
                            <th>Issuer</th>
                        </tr>
                    </thead>
                    <tbody>
                        ${tableRows}
                    </tbody>
                </table>
            `;

            content.innerHTML = overviewHtml + tableHtml;
            lastUpdated.innerHTML = `Last updated: ${new Date(data.timestamp).toLocaleString()}`;
        }

        // Load data on page load
        loadCertificateStatus();

        // Auto-refresh every 5 minutes
        setInterval(loadCertificateStatus, 300000);
    </script>
</body>
</html>
EOF

    log_success "Certificate health dashboard generated: $dashboard_file"
    log_info "Open $dashboard_file in a web browser to view the dashboard"
}

# ============================================================================
# MAIN FUNCTIONS
# ============================================================================

# Show help
show_help() {
    cat << EOF
Certificate Monitoring and Renewal System

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    monitor                 Run certificate monitoring check
    renew <domain>         Renew certificate for specific domain
    auto-renew             Check and auto-renew certificates if needed
    dashboard              Generate certificate health dashboard
    config                 Show current configuration
    help                   Show this help message

CONFIGURATION:
    Configuration is loaded from:
    - $CONFIG_FILE (environment variables)
    - $CERT_CONFIG_FILE (certificate monitoring config)

    Key configuration variables:
    - CERT_WARNING_THRESHOLD: Days before expiry to show warning (default: $DEFAULT_WARNING_THRESHOLD)
    - CERT_CRITICAL_THRESHOLD: Days before expiry to show critical alert (default: $DEFAULT_CRITICAL_THRESHOLD)
    - CERT_RENEWAL_THRESHOLD: Days before expiry to auto-renew (default: $DEFAULT_RENEWAL_THRESHOLD)
    - CERT_ALERT_EMAIL: Email address for alerts
    - CERT_WEBHOOK_URL: Webhook URL for alerts

EXAMPLES:
    $0 monitor                    # Check all certificates
    $0 renew example.com         # Renew specific certificate
    $0 auto-renew                # Auto-renew if needed
    $0 dashboard                 # Generate health dashboard

EOF
}

# Show current configuration
show_config() {
    echo "Certificate Monitoring Configuration:"
    echo "======================================"
    echo "Warning Threshold: $CERT_WARNING_THRESHOLD days"
    echo "Critical Threshold: $CERT_CRITICAL_THRESHOLD days"
    echo "Renewal Threshold: $CERT_RENEWAL_THRESHOLD days"
    echo "Check Interval: $CERT_CHECK_INTERVAL seconds"
    echo "Retry Count: $CERT_RENEWAL_RETRY_COUNT"
    echo "Retry Delay: $CERT_RENEWAL_RETRY_DELAY seconds"
    echo "Alert Email: ${CERT_ALERT_EMAIL:-'Not configured'}"
    echo "Webhook URL: ${CERT_WEBHOOK_URL:-'Not configured'}"
    echo "Primary Domain: $PROSODY_DOMAIN"
    echo ""
    echo "Log Files:"
    echo "Main Log: $LOG_FILE"
    echo "Alert Log: $ALERT_LOG_FILE"
    echo "Status File: ${PROJECT_DIR}/.runtime/cert-status.json"
    echo "Dashboard: ${PROJECT_DIR}/.runtime/cert-dashboard.html"
}

# Main function
main() {
    local command="${1:-help}"

    # Ensure directories exist
    ensure_directories

    # Load configuration
    load_config

    case "$command" in
        "monitor")
            monitor_certificates
            ;;
        "renew")
            if [[ $# -lt 2 ]]; then
                log_error "Domain required for renewal"
                echo "Usage: $0 renew <domain>"
                exit 1
            fi
            renew_certificate_with_retry "$2"
            ;;
        "auto-renew")
            auto_renewal_check
            ;;
        "dashboard")
            # Only run monitoring if no status file exists
            if [[ ! -f "$PROJECT_DIR/.runtime/cert-status.json" ]]; then
                monitor_certificates
            fi
            generate_dashboard
            ;;
        "config")
            show_config
            ;;
        "help"|"--help"|"-h")
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
