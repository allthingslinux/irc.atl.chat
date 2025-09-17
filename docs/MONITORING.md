# Monitoring & Alerting

This guide covers monitoring, health checks, metrics collection, logging, and alerting for IRC.atl.chat infrastructure.

## Overview

### Monitoring Philosophy

IRC.atl.chat implements comprehensive monitoring with:

- **Multi-layer monitoring**: Infrastructure, application, and user experience
- **Real-time alerting**: Immediate notification of issues
- **Historical analysis**: Trend analysis and capacity planning
- **Automated remediation**: Self-healing where possible
- **User impact assessment**: Business impact of incidents

### Monitoring Architecture

```
Monitoring Stack:
├── Health Checks     - Service availability
├── Metrics Collection - Performance data
├── Log Aggregation   - Centralized logging
├── Alerting          - Notification system
├── Dashboards        - Visualization
└── Incident Response - Automated and manual procedures
```

## Health Checks

### Service Health Monitoring

#### Container Health Checks

```yaml
# Docker Compose health checks
services:
  unrealircd:
    healthcheck:
      test: ['CMD', 'nc', '-z', 'localhost', '6697']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  atheme:
    healthcheck:
      test: ['CMD', 'pgrep', '-f', 'atheme-services']
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  unrealircd-webpanel:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

#### Application Health Checks

```bash
# UnrealIRCd health check
check_unrealircd_health() {
    local host=${1:-localhost}
    local port=${2:-6697}

    # Test TCP connection
    if ! timeout 5 bash -c "</dev/null nc -z $host $port"; then
        echo "CRITICAL: Cannot connect to UnrealIRCd on $host:$port"
        return 2
    fi

    # Test IRC handshake
    if echo -e "NICK healthcheck\r\nUSER healthcheck 0 * :Health Check\r\nQUIT\r\n" | \
       timeout 10 nc "$host" "$port" | grep -q "001"; then
        echo "OK: UnrealIRCd responding correctly"
        return 0
    else
        echo "WARNING: UnrealIRCd not responding to IRC commands"
        return 1
    fi
}

# Atheme health check
check_atheme_health() {
    # Check if Atheme processes are running
    if pgrep -f atheme-services >/dev/null; then
        echo "OK: Atheme services running"
        return 0
    else
        echo "CRITICAL: Atheme services not running"
        return 2
    fi
}

# WebPanel health check
check_webpanel_health() {
    local url=${1:-http://localhost:8080}

    if curl -f -s "$url" >/dev/null; then
        echo "OK: WebPanel responding"
        return 0
    else
        echo "CRITICAL: WebPanel not responding"
        return 2
    fi
}
```

### Comprehensive Health Check Script

```bash
#!/bin/bash
# comprehensive-health-check.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Health check results
OVERALL_STATUS=0
ISSUES=()

log() {
    echo -e "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

check_service() {
    local service_name="$1"
    local check_command="$2"
    local critical="${3:-true}"

    log "Checking $service_name..."

    if eval "$check_command" 2>/dev/null; then
        echo -e "${GREEN}✓ $service_name: OK${NC}"
        return 0
    else
        local status=$?
        if [[ $critical == "true" ]] || [[ $status -eq 2 ]]; then
            echo -e "${RED}✗ $service_name: FAILED${NC}"
            OVERALL_STATUS=1
            ISSUES+=("$service_name failed")
            return 1
        else
            echo -e "${YELLOW}⚠ $service_name: WARNING${NC}"
            return 1
        fi
    fi
}

# Service availability checks
check_service "Docker" "docker ps >/dev/null"
check_service "UnrealIRCd Container" "docker ps --filter name=unrealircd --filter status=running | grep -q unrealircd"
check_service "Atheme Container" "docker ps --filter name=atheme --filter status=running | grep -q atheme"
check_service "WebPanel Container" "docker ps --filter name=unrealircd-webpanel --filter status=running | grep -q unrealircd-webpanel"

# Port availability checks
check_service "IRC Port (6697)" "nc -z localhost 6697"
check_service "WebSocket Port (8000)" "nc -z localhost 8000"
check_service "WebPanel Port (8080)" "curl -f -s http://localhost:8080 >/dev/null"

# SSL certificate checks
check_service "SSL Certificate" "make ssl-status >/dev/null 2>&1"

# Resource usage checks
check_disk_usage() {
    local usage
    usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ $usage -gt 90 ]]; then
        echo -e "${RED}✗ Disk Usage: ${usage}% (CRITICAL)${NC}"
        OVERALL_STATUS=1
        ISSUES+=("Disk usage at ${usage}%")
    elif [[ $usage -gt 75 ]]; then
        echo -e "${YELLOW}⚠ Disk Usage: ${usage}% (WARNING)${NC}"
    else
        echo -e "${GREEN}✓ Disk Usage: ${usage}%${NC}"
    fi
}

check_memory_usage() {
    local usage
    usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

    if [[ $usage -gt 90 ]]; then
        echo -e "${RED}✗ Memory Usage: ${usage}% (CRITICAL)${NC}"
        OVERALL_STATUS=1
        ISSUES+=("Memory usage at ${usage}%")
    elif [[ $usage -gt 75 ]]; then
        echo -e "${YELLOW}⚠ Memory Usage: ${usage}% (WARNING)${NC}"
    else
        echo -e "${GREEN}✓ Memory Usage: ${usage}%${NC}"
    fi
}

check_disk_usage
check_memory_usage

# Recent error checks
check_recent_errors() {
    local log_files=(
        "logs/unrealircd/ircd.log"
        "logs/atheme/atheme.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local error_count
            error_count=$(tail -1000 "$log_file" 2>/dev/null | grep -i error | wc -l)

            if [[ $error_count -gt 10 ]]; then
                echo -e "${RED}✗ Recent Errors in $(basename "$log_file"): $error_count${NC}"
                OVERALL_STATUS=1
                ISSUES+=("$error_count recent errors in $(basename "$log_file")")
            elif [[ $error_count -gt 0 ]]; then
                echo -e "${YELLOW}⚠ Some Errors in $(basename "$log_file"): $error_count${NC}"
            else
                echo -e "${GREEN}✓ No Recent Errors in $(basename "$log_file")${NC}"
            fi
        fi
    done
}

check_recent_errors

# Summary
echo
echo "=== Health Check Summary ==="
if [[ $OVERALL_STATUS -eq 0 ]]; then
    echo -e "${GREEN}✓ All systems operational${NC}"
    exit 0
else
    echo -e "${RED}✗ Issues detected:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
    echo
    echo "Run 'make logs' to view detailed logs"
    echo "Run 'make status' for service status"
    exit 1
fi
```

## Metrics Collection

### System Metrics

#### Docker Metrics

```bash
# Container resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

# Container health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Container logs volume
docker logs --since 1h unrealircd 2>&1 | wc -l
```

#### System Resource Metrics

```bash
# CPU usage
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

# Memory usage
free | grep Mem | awk '{printf "%.2f", $3/$2 * 100.0}'

# Disk usage
df / | tail -1 | awk '{print $5}'

# Network statistics
cat /proc/net/dev | grep -E "(eth0|wlan0)" | awk '{print "RX: " $2/1024 " KB, TX: " $10/1024 " KB"}'
```

### Application Metrics

#### IRC Server Metrics

```bash
# Connection statistics
unrealircd_stats() {
    # Connect to IRC and request stats
    {
        echo "NICK stats_bot"
        echo "USER stats 0 * :Stats Collection"
        sleep 1
        echo "STATS u"  # User statistics
        echo "STATS c"  # Connection statistics
        sleep 1
        echo "QUIT"
    } | nc localhost 6697
}

# Parse IRC statistics
parse_irc_stats() {
    local stats_output="$1"

    # Extract metrics
    local user_count
    user_count=$(echo "$stats_output" | grep -o ":[0-9]* users" | grep -o "[0-9]*" | head -1)

    local connection_count
    connection_count=$(echo "$stats_output" | grep -o ":[0-9]* connections" | grep -o "[0-9]*" | head -1)

    echo "users=$user_count"
    echo "connections=$connection_count"
}
```

#### Atheme Service Metrics

```bash
# Service statistics
atheme_stats() {
    # Query Atheme via IRC
    {
        echo "NICK stats_bot"
        echo "USER stats 0 * :Stats Collection"
        sleep 1
        echo "PRIVMSG NickServ :info stats_bot"
        sleep 1
        echo "QUIT"
    } | nc localhost 6697 | grep -E "(registered|accounts|channels)"
}

# Database statistics
atheme_db_stats() {
    if [[ -f "data/atheme/atheme.db" ]]; then
        # User accounts
        local user_count
        user_count=$(sqlite3 data/atheme/atheme.db "SELECT COUNT(*) FROM account_table;")

        # Registered channels
        local channel_count
        channel_count=$(sqlite3 data/atheme/atheme.db "SELECT COUNT(*) FROM chan_table;")

        echo "user_accounts=$user_count"
        echo "registered_channels=$channel_count"
    fi
}
```

### Prometheus Metrics

#### Metrics Exposition

```bash
# Generate Prometheus metrics
generate_prometheus_metrics() {
    local metrics_file="/tmp/irc_metrics.prom"

    cat > "$metrics_file" << EOF
# HELP irc_users_connected Number of users currently connected
# TYPE irc_users_connected gauge
irc_users_connected $(get_user_count 2>/dev/null || echo 0)

# HELP irc_channels_registered Number of registered channels
# TYPE irc_channels_registered gauge
irc_channels_registered $(get_channel_count 2>/dev/null || echo 0)

# HELP irc_ssl_certificate_expiry_days Days until SSL certificate expiry
# TYPE irc_ssl_certificate_expiry_days gauge
irc_ssl_certificate_expiry_days $(get_ssl_expiry_days 2>/dev/null || echo 0)

# HELP docker_container_cpu_usage_percent CPU usage percentage
# TYPE docker_container_cpu_usage_percent gauge
docker_container_cpu_usage_percent{container="unrealircd"} $(get_container_cpu "unrealircd" 2>/dev/null || echo 0)

# HELP docker_container_memory_usage_bytes Memory usage in bytes
# TYPE docker_container_memory_usage_bytes gauge
docker_container_memory_usage_bytes{container="unrealircd"} $(get_container_memory "unrealircd" 2>/dev/null || echo 0)
EOF

    # Expose metrics via HTTP
    if command -v python3 >/dev/null; then
        python3 -m http.server 9090 --directory /tmp &
        echo "Metrics available at http://localhost:9090/irc_metrics.prom"
    fi
}

# Helper functions
get_user_count() {
    # Implementation to get current user count
    echo "150"  # Placeholder
}

get_channel_count() {
    # Implementation to get registered channel count
    sqlite3 data/atheme/atheme.db "SELECT COUNT(*) FROM chan_table;" 2>/dev/null || echo "0"
}

get_ssl_expiry_days() {
    # Implementation to get SSL certificate expiry
    if [[ -f "src/backend/unrealircd/conf/tls/server.cert.pem" ]]; then
        openssl x509 -in "src/backend/unrealircd/conf/tls/server.cert.pem" -noout -enddate 2>/dev/null | \
        cut -d= -f2 | xargs -I {} date -d "{}" +%s | \
        awk -v now=$(date +%s) '{print int(($1 - now) / 86400)}'
    else
        echo "0"
    fi
}

get_container_cpu() {
    local container="$1"
    docker stats --no-stream --format "{{.CPUPerc}}" "$container" 2>/dev/null | sed 's/%//' || echo "0"
}

get_container_memory() {
    local container="$1"
    docker stats --no-stream --format "{{.MemUsage}}" "$container" 2>/dev/null | \
    awk '{print $1}' | sed 's/[A-Za-z]*//' | numfmt --from=auto --to-unit=1 2>/dev/null || echo "0"
}
```

## Log Aggregation

### Log Collection

#### Service Logs

```bash
# UnrealIRCd logs
unrealircd_logs() {
    local log_file="logs/unrealircd/ircd.log"
    local json_log="logs/unrealircd/ircd.json.log"

    # Structured JSON logs
    if [[ -f "$json_log" ]]; then
        tail -f "$json_log" | jq '.message'
    else
        tail -f "$log_file"
    fi
}

# Atheme logs
atheme_logs() {
    tail -f logs/atheme/atheme.log
}

# WebPanel logs
webpanel_logs() {
    docker logs -f unrealircd-webpanel
}
```

#### Centralized Logging

```bash
# Log aggregation script
aggregate_logs() {
    local output_dir="logs/aggregated"
    mkdir -p "$output_dir"

    # Combine all logs with timestamps
    {
        echo "=== UnrealIRCd Logs ==="
        tail -100 logs/unrealircd/ircd.log
        echo
        echo "=== Atheme Logs ==="
        tail -100 logs/atheme/atheme.log
        echo
        echo "=== WebPanel Logs ==="
        docker logs unrealircd-webpanel 2>&1 | tail -100
    } > "$output_dir/combined_$(date +%Y%m%d_%H%M%S).log"
}
```

### Log Analysis

#### Error Detection

```bash
# Find recent errors across all logs
find_recent_errors() {
    local hours=${1:-1}
    local error_patterns=(
        "error"
        "Error"
        "ERROR"
        "failed"
        "Failed"
        "FAILED"
        "exception"
        "Exception"
        "EXCEPTION"
    )

    echo "Searching for errors in the last $hours hours..."

    for pattern in "${error_patterns[@]}"; do
        echo "=== $pattern ==="
        find logs/ -name "*.log" -newermt "$(date -d "$hours hours ago")" -exec grep -l "$pattern" {} \; | \
        while read -r log_file; do
            echo "File: $log_file"
            grep -n "$pattern" "$log_file" | tail -5
        done
        echo
    done
}

# Usage: find_recent_errors 24  # Last 24 hours
```

#### Log Statistics

```bash
# Generate log statistics
analyze_logs() {
    local log_dir="logs"
    local report_file="logs/analysis_$(date +%Y%m%d).txt"

    {
        echo "IRC.atl.chat Log Analysis Report"
        echo "Generated: $(date)"
        echo "================================="
        echo

        echo "=== File Sizes ==="
        find "$log_dir" -name "*.log" -exec ls -lh {} \; | sort -k5 -hr
        echo

        echo "=== Error Summary ==="
        find "$log_dir" -name "*.log" -exec grep -c "ERROR\|error\|Error" {} \; -print | sort -nr
        echo

        echo "=== Recent Activity ==="
        find "$log_dir" -name "*.log" -newermt "1 hour ago" -exec basename {} \; | sort | uniq -c | sort -nr
        echo

        echo "=== Top Error Messages ==="
        find "$log_dir" -name "*.log" -exec grep -h "ERROR\|error\|Error" {} \; | \
        sed 's/.*ERROR//' | sed 's/.*error//' | sed 's/.*Error//' | \
        sort | uniq -c | sort -nr | head -10

    } > "$report_file"

    echo "Log analysis report generated: $report_file"
}
```

## Alerting System

### Alert Types

#### Health Alerts

```bash
# Service down alert
alert_service_down() {
    local service="$1"
    local message="ALERT: $service is down"

    echo "$(date): $message" >> logs/alerts.log

    # Send notifications
    notify_slack "$message" "danger"
    notify_email "admin@atl.chat" "IRC Service Alert" "$message"
}

# High resource usage alert
alert_high_resource_usage() {
    local resource="$1"
    local usage="$2"
    local threshold="$3"

    if [[ $usage -gt $threshold ]]; then
        local message="WARNING: $resource usage at ${usage}% (threshold: ${threshold}%)"

        echo "$(date): $message" >> logs/alerts.log
        notify_slack "$message" "warning"
    fi
}
```

#### Security Alerts

```bash
# Failed login alert
alert_failed_login() {
    local ip="$1"
    local attempts="$2"

    if [[ $attempts -gt 5 ]]; then
        local message="SECURITY: Multiple failed login attempts from $ip ($attempts attempts)"

        echo "$(date): $message" >> logs/security.log
        notify_security_team "$message"
    fi
}

# SSL certificate expiry alert
alert_ssl_expiry() {
    local days_remaining="$1"

    if [[ $days_remaining -le 7 ]]; then
        local message="CRITICAL: SSL certificate expires in $days_remaining days"

        echo "$(date): $message" >> logs/ssl.log
        notify_admin "$message"
    elif [[ $days_remaining -le 30 ]]; then
        local message="WARNING: SSL certificate expires in $days_remaining days"

        echo "$(date): $message" >> logs/ssl.log
        notify_admin "$message"
    fi
}
```

### Notification Channels

#### Slack Integration

```bash
# Slack notification
notify_slack() {
    local message="$1"
    local color="${2:-good}"
    local webhook_url="$SLACK_WEBHOOK_URL"

    if [[ -n "$webhook_url" ]]; then
        curl -X POST "$webhook_url" \
            -H 'Content-type: application/json' \
            -d "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"text\": \"$message\",
                    \"footer\": \"IRC.atl.chat Monitoring\",
                    \"ts\": $(date +%s)
                }]
            }"
    fi
}
```

#### Email Notifications

```bash
# Email notification
notify_email() {
    local to="$1"
    local subject="$2"
    local body="$3"

    if command -v mail >/dev/null; then
        echo "$body" | mail -s "$subject" "$to"
    elif command -v sendmail >/dev/null; then
        {
            echo "To: $to"
            echo "Subject: $subject"
            echo
            echo "$body"
        } | sendmail -t
    fi
}
```

#### SMS/Pager Notifications

```bash
# SMS notification (using Twilio)
notify_sms() {
    local message="$1"
    local phone_number="$ADMIN_PHONE"

    if [[ -n "$TWILIO_ACCOUNT_SID" && -n "$phone_number" ]]; then
        curl -X POST "https://api.twilio.com/2010-04-07/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
            --data-urlencode "From=$TWILIO_PHONE_NUMBER" \
            --data-urlencode "To=$phone_number" \
            --data-urlencode "Body=$message" \
            -u "$TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN"
    fi
}
```

### Alert Escalation

```bash
# Alert escalation logic
escalate_alert() {
    local alert_id="$1"
    local severity="$2"
    local message="$3"

    # Log the alert
    echo "$(date)|$alert_id|$severity|$message" >> logs/alert_escalation.log

    # Immediate notification
    notify_slack "$message" "danger"

    # Escalate after 5 minutes if not acknowledged
    (
        sleep 300
        if [[ ! -f "logs/alert_acknowledged_$alert_id" ]]; then
            notify_email "admin@atl.chat" "ESCALATED: $message" "$message"
            notify_sms "$message"
        fi
    ) &
}
```

## Dashboards and Visualization

### Grafana Dashboards

#### IRC Server Dashboard

```json
{
  "dashboard": {
    "title": "IRC.atl.chat Server Monitoring",
    "tags": ["irc", "monitoring"],
    "panels": [
      {
        "title": "Connected Users",
        "type": "graph",
        "targets": [
          {
            "expr": "irc_users_connected",
            "legendFormat": "Users"
          }
        ]
      },
      {
        "title": "Server CPU Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "docker_container_cpu_usage_percent{container=\"unrealircd\"}",
            "legendFormat": "CPU %"
          }
        ]
      },
      {
        "title": "Server Memory Usage",
        "type": "graph",
        "targets": [
          {
            "expr": "docker_container_memory_usage_bytes{container=\"unrealircd\"}",
            "legendFormat": "Memory"
          }
        ]
      },
      {
        "title": "SSL Certificate Expiry",
        "type": "stat",
        "targets": [
          {
            "expr": "irc_ssl_certificate_expiry_days",
            "colorMode": "thresholds"
          }
        ],
        "thresholds": {
          "mode": "absolute",
          "steps": [
            { "color": "green", "value": null },
            { "color": "orange", "value": 30 },
            { "color": "red", "value": 7 }
          ]
        }
      }
    ]
  }
}
```

### WebPanel Dashboard

#### Real-time Statistics

```javascript
// WebPanel dashboard JavaScript
class MonitoringDashboard {
    constructor() {
        this.charts = {};
        this.updateInterval = 30000; // 30 seconds
        this.init();
    }

    init() {
        this.createCharts();
        this.startUpdates();
    }

    createCharts() {
        // User connections chart
        this.charts.users = new Chart(document.getElementById('users-chart'), {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Connected Users',
                    data: [],
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });

        // Server load chart
        this.charts.load = new Chart(document.getElementById('load-chart'), {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'CPU Usage %',
                    data: [],
                    borderColor: 'rgb(255, 99, 132)',
                    backgroundColor: 'rgba(255, 99, 132, 0.2)'
                }]
            }
        });
    }

    async updateData() {
        try {
            // Fetch data from API
            const response = await fetch('/api/monitoring/stats');
            const data = await response.json();

            // Update charts
            this.updateChart(this.charts.users, data.users);
            this.updateChart(this.charts.load, data.cpu);

            // Update status indicators
            this.updateStatusIndicators(data);

        } catch (error) {
            console.error('Failed to update monitoring data:', error);
        }
    }

    updateChart(chart, newData) {
        const now = new Date().toLocaleTimeString();

        // Add new data point
        chart.data.labels.push(now);
        chart.data.datasets[0].data.push(newData);

        // Keep only last 20 data points
        if (chart.data.labels.length > 20) {
            chart.data.labels.shift();
            chart.data.datasets[0].data.shift();
        }

        chart.update();
    }

    updateStatusIndicators(data) {
        // Update service status
        const services = ['unrealircd', 'atheme', 'webpanel'];
        services.forEach(service => {
            const element = document.getElementById(`${service}-status`);
            const status = data.services[service];

            element.className = `status ${status}`;
            element.textContent = status.toUpperCase();
        });

        // Update SSL status
        const sslElement = document.getElementById('ssl-status');
        const sslDays = data.ssl.days_remaining;

        if (sslDays < 7) {
            sslElement.className = 'status critical';
            sslElement.textContent = `EXPIRES SOON (${sslDays} days)`;
        } else if (sslDays < 30) {
            sslElement.className = 'status warning';
            sslElement.textContent = `EXPIRING (${sslDays} days)`;
        } else {
            sslElement.className = 'status good';
            sslElement.textContent = `VALID (${sslDays} days)`;
        }
    }

    startUpdates() {
        this.updateData(); // Initial update
        setInterval(() => this.updateData(), this.updateInterval);
    }
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
    new MonitoringDashboard();
});
```

## Incident Response

### Automated Response

#### Service Restart Automation

```bash
# Automatic service recovery
auto_recover_service() {
    local service="$1"
    local max_attempts=3
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempting to restart $service (attempt $attempt/$max_attempts)"

        if docker restart "$service"; then
            # Wait for health check
            sleep 30

            if docker ps --filter name="$service" --filter health=healthy | grep -q "$service"; then
                log_info "Service $service recovered successfully"
                alert_service_recovered "$service"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        sleep 10
    done

    log_error "Failed to recover service $service after $max_attempts attempts"
    alert_manual_intervention_required "$service"
    return 1
}
```

#### SSL Certificate Auto-Renewal

```bash
# Automatic SSL renewal
auto_renew_ssl() {
    local expiry_days
    expiry_days=$(get_ssl_expiry_days)

    if [[ $expiry_days -le 7 ]]; then
        log_info "SSL certificate expires in $expiry_days days, attempting renewal"

        if make ssl-renew; then
            log_info "SSL certificate renewed successfully"
            alert_ssl_renewed
        else
            log_error "SSL certificate renewal failed"
            alert_ssl_renewal_failed
        fi
    fi
}
```

### Manual Incident Response

#### Incident Response Checklist

```bash
# Incident response procedure
respond_to_incident() {
    local incident_type="$1"
    local severity="$2"

    # 1. Acknowledge the incident
    log_incident_acknowledged "$incident_type"

    # 2. Assess impact
    assess_incident_impact "$incident_type"

    # 3. Communicate status
    notify_stakeholders "Investigating $incident_type incident" "info"

    # 4. Execute recovery procedure
    case "$incident_type" in
        "service_down")
            execute_service_recovery
            ;;
        "ssl_expiry")
            execute_ssl_renewal
            ;;
        "high_load")
            execute_load_shedding
            ;;
        *)
            execute_general_recovery
            ;;
    esac

    # 5. Verify recovery
    verify_system_restored

    # 6. Document incident
    document_incident "$incident_type" "$severity"

    # 7. Communicate resolution
    notify_stakeholders "Incident resolved: $incident_type" "good"
}
```

#### Communication Templates

```bash
# Incident notification templates
notify_incident_start() {
    local incident="$1"
    cat << EOF
🚨 IRC.atl.chat Incident Started

Incident: $incident
Started: $(date)
Status: Investigating
Impact: Assessing

We'll provide updates as we work on resolution.
EOF
}

notify_incident_resolved() {
    local incident="$1"
    local duration="$2"
    cat << EOF
✅ IRC.atl.chat Incident Resolved

Incident: $incident
Resolved: $(date)
Duration: $duration

Service has been restored to normal operation.
EOF
}
```

## Performance Monitoring

### Benchmarking

#### Load Testing

```bash
# IRC load testing
load_test_irc() {
    local concurrent_users="$1"
    local duration="$2"

    log_info "Starting IRC load test: $concurrent_users users for $duration seconds"

    # Start load test
    docker run --rm \
        -v "$(pwd)/tests:/tests" \
        -e CONCURRENT_USERS="$concurrent_users" \
        -e DURATION="$duration" \
        load-test-image \
        python /tests/load_test.py

    # Analyze results
    analyze_load_test_results
}
```

#### Performance Metrics

```bash
# Collect performance metrics
collect_performance_metrics() {
    local metrics_file="logs/performance_$(date +%Y%m%d_%H%M%S).json"

    {
        echo "{"
        echo "  \"timestamp\": \"$(date +%s)\","
        echo "  \"system\": {"
        echo "    \"cpu_usage\": \"$(get_cpu_usage)\","
        echo "    \"memory_usage\": \"$(get_memory_usage)\","
        echo "    \"disk_usage\": \"$(get_disk_usage)\""
        echo "  },"
        echo "  \"services\": {"
        echo "    \"unrealircd\": {"
        echo "      \"connections\": $(get_irc_connections),"
        echo "      \"cpu\": \"$(get_container_cpu unrealircd)\","
        echo "      \"memory\": $(get_container_memory unrealircd)"
        echo "    },"
        echo "    \"atheme\": {"
        echo "      \"cpu\": \"$(get_container_cpu atheme)\","
        echo "      \"memory\": $(get_container_memory atheme)"
        echo "    }"
        echo "  }"
        echo "}"
    } > "$metrics_file"

    log_info "Performance metrics collected: $metrics_file"
}
```

## Maintenance Monitoring

### Automated Maintenance

#### Log Rotation

```bash
# Rotate logs automatically
rotate_logs() {
    local log_files=(
        "logs/unrealircd/ircd.log"
        "logs/atheme/atheme.log"
    )

    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" && $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null) -gt 104857600 ]]; then  # 100MB
            # Compress current log
            gzip "$log_file"

            # Create new log file
            touch "$log_file"

            # Restart services to reopen log files
            docker restart "$(basename "$(dirname "$log_file")")" 2>/dev/null || true

            log_info "Rotated log file: $log_file"
        fi
    done
}
```

#### Database Maintenance

```bash
# Atheme database maintenance
maintain_atheme_database() {
    local db_file="data/atheme/atheme.db"

    if [[ -f "$db_file" ]]; then
        log_info "Starting Atheme database maintenance"

        # Vacuum database
        sqlite3 "$db_file" "VACUUM;"

        # Analyze tables
        sqlite3 "$db_file" "ANALYZE;"

        # Integrity check
        if sqlite3 "$db_file" "PRAGMA integrity_check;" | grep -q "ok"; then
            log_info "Database maintenance completed successfully"
        else
            log_error "Database integrity check failed"
            alert_database_issue
        fi
    fi
}
```

### Capacity Planning

#### Growth Monitoring

```bash
# Monitor system growth
monitor_growth() {
    local metrics_file="logs/growth_metrics.json"

    # Collect historical data
    {
        echo "{"
        echo "  \"date\": \"$(date +%Y-%m-%d)\","
        echo "  \"users\": {"
        echo "    \"registered\": $(sqlite3 data/atheme/atheme.db "SELECT COUNT(*) FROM account_table;" 2>/dev/null || echo 0),"
        echo "    \"connected\": $(get_current_user_count)"
        echo "  },"
        echo "  \"channels\": {"
        echo "    \"registered\": $(sqlite3 data/atheme/atheme.db "SELECT COUNT(*) FROM chan_table;" 2>/dev/null || echo 0),"
        echo "    \"active\": $(get_active_channel_count)"
        echo "  },"
        echo "  \"storage\": {"
        echo "    \"database_size\": $(stat -f%z data/atheme/atheme.db 2>/dev/null || stat -c%s data/atheme/atheme.db 2>/dev/null || echo 0),"
        echo "    \"log_size\": $(du -sb logs/ 2>/dev/null | cut -f1 || echo 0)"
        echo "  }"
        echo "}"
    } >> "$metrics_file"

    # Analyze trends
    analyze_growth_trends "$metrics_file"
}
```

## Summary

### Monitoring Coverage

- **Health Checks**: Comprehensive service availability monitoring
- **Metrics Collection**: System and application performance metrics
- **Log Aggregation**: Centralized logging with analysis capabilities
- **Alerting System**: Multi-channel notifications with escalation
- **Visualization**: Real-time dashboards and historical analysis
- **Incident Response**: Automated and manual response procedures

### Key Monitoring Features

1. **Proactive Monitoring**: Detect issues before they impact users
2. **Comprehensive Coverage**: All system components monitored
3. **Automated Response**: Self-healing capabilities where possible
4. **Clear Communication**: Stakeholders informed throughout incidents
5. **Continuous Improvement**: Lessons learned feed back into monitoring

### Maintenance Best Practices

- **Regular Health Checks**: Daily automated verification
- **Performance Monitoring**: Trend analysis and capacity planning
- **Log Management**: Automated rotation and analysis
- **Backup Verification**: Regular restore testing
- **Security Monitoring**: Continuous vulnerability assessment

This comprehensive monitoring system ensures IRC.atl.chat maintains high availability, performance, and security while providing clear visibility into system health and rapid response to any issues that arise.