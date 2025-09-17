# Management Scripts

This guide covers the management and utility scripts that automate various aspects of IRC.atl.chat deployment, maintenance, and operations.

## Overview

### Script Categories

IRC.atl.chat includes several categories of management scripts:

```
scripts/
├── init.sh              # System initialization
├── prepare-config.sh    # Configuration processing
├── ssl-manager.sh       # SSL certificate management
└── health-check.sh      # System health monitoring
```

### Script Architecture

All scripts follow consistent patterns:
- **Error handling**: Proper exit codes and error messages
- **Logging**: Structured logging with timestamps
- **Configuration**: Environment variable driven
- **Safety**: Confirmation prompts for destructive operations

## Core Scripts

### Initialization Script (`scripts/init.sh`)

**Purpose**: Initialize the IRC.atl.chat environment and create required directories.

**Usage**:
```bash
# Automatic initialization (called by make up)
./scripts/init.sh

# Manual initialization with debug output
DEBUG=1 ./scripts/init.sh
```

**What it does**:

1. **Directory Creation**
   ```bash
   # Create persistent data directories
   mkdir -p data/{unrealircd,atheme,letsencrypt}
   mkdir -p logs/{unrealircd,atheme}
   ```

2. **Permission Setup**
   ```bash
   # Set proper ownership for host user
   chown -R $(id -u):$(id -g) data/ logs/

   # Ensure directories are writable
   chmod 755 data/ logs/
   ```

3. **Environment Validation**
   ```bash
   # Check required environment variables
   if [ -z "$PUID" ] || [ -z "$PGID" ]; then
       echo "Error: PUID and PGID must be set"
       exit 1
   fi
   ```

4. **Prerequisite Checks**
   ```bash
   # Verify Docker availability
   if ! command -v docker >/dev/null 2>&1; then
       echo "Error: Docker is not installed"
       exit 1
   fi

   # Check Docker Compose compatibility
   if ! docker compose version >/dev/null 2>&1; then
       echo "Error: Docker Compose is not available"
       exit 1
   fi
   ```

**Exit Codes**:
- `0`: Success
- `1`: Environment validation failed
- `2`: Permission setup failed
- `3`: Directory creation failed

### Configuration Preparation (`scripts/prepare-config.sh`)

**Purpose**: Process template files and generate production configurations.

**Usage**:
```bash
# Process all configuration templates
./scripts/prepare-config.sh

# Process with verbose output
VERBOSE=1 ./scripts/prepare-config.sh

# Process with debug information
DEBUG=1 ./scripts/prepare-config.sh
```

**Configuration Processing**:

1. **Template Discovery**
   ```bash
   # Find all template files
   find src/backend -name "*.template" | while read template; do
       # Generate corresponding .conf file
       output="${template%.template}.conf"
       process_template "$template" "$output"
   done
   ```

2. **Variable Substitution**
   ```bash
   # Use envsubst for variable replacement
   envsubst < "$template" > "$output"

   # Supported variables:
   # - IRC_DOMAIN, IRC_ROOT_DOMAIN
   # - ATHEME_SEND_PASSWORD, ATHEME_RECEIVE_PASSWORD
   # - WEBPANEL_RPC_USER, WEBPANEL_RPC_PASSWORD
   # - SSL certificate paths and ports
   ```

3. **Configuration Validation**
   ```bash
   # Basic syntax checking
   validate_config "$output"

   # Check for required sections
   check_required_settings "$output"
   ```

4. **Permission Setting**
   ```bash
   # Set secure permissions
   chmod 644 "$output"

   # Ensure service users can read
   chown $(id -u):$(id -g) "$output"
   ```

**Validation Checks**:

- **Syntax validation**: Basic config file format checking
- **Required settings**: Ensure critical configuration is present
- **Path validation**: Verify file paths exist and are accessible
- **Permission checks**: Ensure files have correct permissions

**Debug Output**:
```bash
# With DEBUG=1
[DEBUG] Processing template: src/backend/unrealircd/conf/unrealircd.conf.template
[DEBUG] Generated config: src/backend/unrealircd/conf/unrealircd.conf
[DEBUG] Variables substituted: 15
[DEBUG] Validation passed for: unrealircd.conf
```

### SSL Certificate Manager (`scripts/ssl-manager.sh`)

**Purpose**: Automated SSL certificate provisioning and management using Let's Encrypt.

**Usage**:
```bash
# Check certificate status
./scripts/ssl-manager.sh check

# Issue new certificates
./scripts/ssl-manager.sh issue

# Force certificate renewal
./scripts/ssl-manager.sh renew

# Copy certificates to services
./scripts/ssl-manager.sh copy

# Restart services after certificate update
./scripts/ssl-manager.sh restart

# Options
./scripts/ssl-manager.sh --help
./scripts/ssl-manager.sh --verbose check
./scripts/ssl-manager.sh --debug issue
```

**Certificate Management Process**:

1. **Status Checking**
   ```bash
   check_certificates() {
       local cert_file="$TLS_DIR/server.cert.pem"

       # Verify certificate exists
       if [[ ! -f $cert_file ]]; then
           log_warn "No SSL certificate found"
           return 1
       fi

       # Check certificate validity
       local expiry_date
       expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)

       # Calculate days until expiry
       local expiry_timestamp current_timestamp days_until_expiry
       expiry_timestamp=$(date -d "$expiry_date" +%s)
       current_timestamp=$(date +%s)
       days_until_expiry=$(((expiry_timestamp - current_timestamp) / 86400))

       # Determine renewal needed
       if [[ $days_until_expiry -le 7 ]]; then
           log_warn "Certificate expires in $days_until_expiry days"
           return 1
       fi

       log_info "Certificate valid for $days_until_expiry more days"
       return 0
   }
   ```

2. **Certificate Issuance**
   ```bash
   issue_certificates() {
       log_info "Issuing new SSL certificates for $DOMAIN"

       # Validate Cloudflare credentials
       validate_credentials

       # Run Certbot with Docker
       docker run --rm \
         -v "$LETSENCRYPT_DIR:/etc/letsencrypt" \
         -v "$CREDENTIALS_FILE:/etc/letsencrypt/cloudflare-credentials.ini:ro" \
         certbot/dns-cloudflare:latest \
         certonly \
         --dns-cloudflare \
         --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
         --email "$EMAIL" \
         --agree-tos \
         --no-eff-email \
         -d "$DOMAIN" \
         -d "*.$DOMAIN"

       # Fix permissions
       fix_letsencrypt_permissions

       # Copy certificates
       copy_certificates
   }
   ```

3. **Certificate Deployment**
   ```bash
   copy_certificates() {
       local cert_source="$LETSENCRYPT_DIR/live/$DOMAIN/fullchain.pem"
       local key_source="$LETSENCRYPT_DIR/live/$DOMAIN/privkey.pem"
       local cert_target="$TLS_DIR/server.cert.pem"
       local key_target="$TLS_DIR/server.key.pem"

       # Copy certificate files
       cp "$cert_source" "$cert_target"
       cp "$key_source" "$key_target"

       # Set secure permissions
       chmod 644 "$cert_target" "$key_target"

       log_info "Certificates copied successfully"
   }
   ```

4. **Service Restart**
   ```bash
   restart_services() {
       local containers=("unrealircd" "unrealircd-webpanel")

       for container in "${containers[@]}"; do
           if docker ps -a --format "table {{.Names}}" | grep -q "^${container}$"; then
               log_debug "Restarting container: $container"
               docker restart "$container"
               log_info "Container $container restarted successfully"
           fi
       done
   }
   ```

**Configuration Options**:

```bash
# Domain settings
DOMAIN="${IRC_ROOT_DOMAIN}"
EMAIL="${LETSENCRYPT_EMAIL}"

# Directory paths
TLS_DIR="./src/backend/unrealircd/conf/tls"
LETSENCRYPT_DIR="./data/letsencrypt"
CREDENTIALS_FILE="./cloudflare-credentials.ini"
```

**Error Handling**:

- **Cloudflare API errors**: Invalid tokens, rate limits, DNS issues
- **Certificate validation**: Chain verification, expiry checking
- **File permissions**: Secure certificate storage
- **Service restart failures**: Container health checking

**Monitoring Integration**:

The SSL manager integrates with Docker monitoring:
```bash
# Daily certificate checking
docker compose up -d ssl-monitor

# View SSL monitoring logs
docker compose logs -f ssl-monitor

# Stop monitoring
docker compose down ssl-monitor
```

### Health Check Script (`scripts/health-check.sh`)

**Purpose**: Comprehensive system health monitoring and diagnostics.

**Usage**:
```bash
# Basic health check
./scripts/health-check.sh

# Detailed health check
VERBOSE=1 ./scripts/health-check.sh

# Continuous monitoring
watch ./scripts/health-check.sh
```

**Health Checks Performed**:

1. **Service Status**
   ```bash
   check_services() {
       local services=("unrealircd" "atheme" "unrealircd-webpanel")

       for service in "${services[@]}"; do
           if docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
               echo "✅ $service: Running"
           else
               echo "❌ $service: Not running"
               return 1
           fi
       done
   }
   ```

2. **Port Availability**
   ```bash
   check_ports() {
       local ports=("6697" "8000" "8080")

       for port in "${ports[@]}"; do
           if nc -z localhost "$port" 2>/dev/null; then
               echo "✅ Port $port: Open"
           else
               echo "❌ Port $port: Closed"
               return 1
           fi
       done
   }
   ```

3. **SSL Certificate Status**
   ```bash
   check_ssl() {
       local cert_file="src/backend/unrealircd/conf/tls/server.cert.pem"

       if [[ ! -f $cert_file ]]; then
           echo "❌ SSL: No certificate found"
           return 1
       fi

       # Check expiry
       local expiry_info
       expiry_info=$(openssl x509 -in "$cert_file" -noout -dates 2>/dev/null)

       if [[ $? -ne 0 ]]; then
           echo "❌ SSL: Invalid certificate"
           return 1
       fi

       local expiry_date
       expiry_date=$(echo "$expiry_info" | grep "notAfter" | cut -d= -f2)

       local days_left
       days_left=$(( ($(date -d "$expiry_date" +%s) - $(date +%s)) / 86400 ))

       if [[ $days_left -lt 7 ]]; then
           echo "❌ SSL: Expires in $days_left days"
           return 1
       elif [[ $days_left -lt 30 ]]; then
           echo "⚠️  SSL: Expires in $days_left days"
       else
           echo "✅ SSL: Valid ($days_left days remaining)"
       fi
   }
   ```

4. **Configuration Integrity**
   ```bash
   check_config() {
       local config_files=(
           "src/backend/unrealircd/conf/unrealircd.conf"
           "src/backend/atheme/conf/atheme.conf"
       )

       for config in "${config_files[@]}"; do
           if [[ ! -f $config ]]; then
               echo "❌ Config: $config missing"
               return 1
           fi

           if [[ ! -r $config ]]; then
               echo "❌ Config: $config not readable"
               return 1
           fi
       done

       echo "✅ Config: All configuration files present"
   }
   ```

5. **Resource Usage**
   ```bash
   check_resources() {
       # Check disk space
       local disk_usage
       disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

       if [[ $disk_usage -gt 90 ]]; then
           echo "❌ Disk: ${disk_usage}% used"
           return 1
       elif [[ $disk_usage -gt 75 ]]; then
           echo "⚠️  Disk: ${disk_usage}% used"
       else
           echo "✅ Disk: ${disk_usage}% used"
       fi

       # Check memory usage
       local mem_usage
       mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')

       if [[ $mem_usage -gt 90 ]]; then
           echo "❌ Memory: ${mem_usage}% used"
           return 1
       elif [[ $mem_usage -gt 75 ]]; then
           echo "⚠️  Memory: ${mem_usage}% used"
       else
           echo "✅ Memory: ${mem_usage}% used"
       fi
   }
   ```

6. **Log Analysis**
   ```bash
   check_logs() {
       local log_files=(
           "logs/unrealircd/ircd.log"
           "logs/atheme/atheme.log"
       )

       for log in "${log_files[@]}"; do
           if [[ ! -f $log ]]; then
               echo "⚠️  Logs: $log not found"
               continue
           fi

           # Check for recent errors
           local recent_errors
           recent_errors=$(tail -100 "$log" 2>/dev/null | grep -i error | wc -l)

           if [[ $recent_errors -gt 0 ]]; then
               echo "⚠️  Logs: $recent_errors recent errors in $log"
           else
               echo "✅ Logs: $log clean"
           fi
       done
   }
   ```

## Utility Scripts

### Additional Management Scripts

#### Docker Compose Integration

```bash
# Custom Docker Compose operations
docker_compose_wrapper() {
    local command="$1"
    shift

    case "$command" in
        "up")
            echo "Starting IRC.atl.chat services..."
            docker compose up -d "$@"
            ;;
        "down")
            echo "Stopping IRC.atl.chat services..."
            docker compose down "$@"
            ;;
        "restart")
            echo "Restarting IRC.atl.chat services..."
            docker compose restart "$@"
            ;;
        "logs")
            docker compose logs "$@"
            ;;
        *)
            echo "Unknown command: $command"
            exit 1
            ;;
    esac
}
```

#### Environment Helpers

```bash
# Environment validation
validate_environment() {
    local required_vars=(
        "IRC_DOMAIN"
        "LETSENCRYPT_EMAIL"
        "PUID"
        "PGID"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "❌ Missing required environment variable: $var"
            return 1
        fi
    done

    echo "✅ Environment validation passed"
}

# Environment export
export_environment() {
    cat > .env << EOF
# IRC.atl.chat Environment Configuration
# Generated on $(date)

# System
PUID=$(id -u)
PGID=$(id -g)
TZ=UTC

# Network
IRC_DOMAIN=${IRC_DOMAIN:-irc.atl.chat}
IRC_ROOT_DOMAIN=${IRC_ROOT_DOMAIN:-atl.chat}

# Security
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-admin@atl.chat}

# Services
ATHEME_SEND_PASSWORD=${ATHEME_SEND_PASSWORD:-changeme}
ATHEME_RECEIVE_PASSWORD=${ATHEME_RECEIVE_PASSWORD:-changeme}
WEBPANEL_RPC_PASSWORD=${WEBPANEL_RPC_PASSWORD:-changeme}
EOF

    chmod 600 .env
    echo "✅ Environment file created: .env"
}
```

## Script Development

### Script Standards

All scripts follow consistent standards:

#### Header Template
```bash
#!/bin/bash
# ============================================================================
# Script Name: script_name.sh
# Description: Brief description of what the script does
# Author: IRC.atl.chat Team
# Version: 1.0.0
# ============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    # shellcheck disable=SC1091
    source "$PROJECT_ROOT/.env"
fi
```

#### Logging Functions
```bash
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:$(basename "$0"): $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN:$(basename "$0"): $1${NC}" >&2
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:$(basename "$0"): $1${NC}" >&2
}

log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] DEBUG:$(basename "$0"): $1${NC}"
    fi
}
```

#### Error Handling
```bash
# Trap errors
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

# Cleanup function
cleanup() {
    local exit_code=$?
    log_debug "Performing cleanup..."

    # Cleanup operations here
    # Remove temporary files, etc.

    exit "$exit_code"
}

trap cleanup EXIT
```

#### Argument Parsing
```bash
# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}
```

#### Help Function
```bash
show_help() {
    cat << EOF
$(basename "$0") - Script description

USAGE:
    $0 [OPTIONS] [COMMAND]

COMMANDS:
    command1    Description of command1
    command2    Description of command2

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --debug     Enable debug output
    --dry-run       Show what would be done without doing it

EXAMPLES:
    $0 command1
    $0 --verbose command2
    $0 --dry-run command1

ENVIRONMENT VARIABLES:
    DEBUG           Enable debug output
    VERBOSE         Enable verbose output
    DRY_RUN         Show what would be done

For more information, see the IRC.atl.chat documentation.
EOF
}
```

### Testing Scripts

#### Script Testing Framework
```bash
# Test helper functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    if [[ "$expected" != "$actual" ]]; then
        log_error "$message: expected '$expected', got '$actual'"
        return 1
    fi

    log_debug "$message: OK"
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist}"

    if [[ ! -f "$file" ]]; then
        log_error "$message: $file does not exist"
        return 1
    fi

    log_debug "$message: OK"
}

assert_command_success() {
    local command="$1"
    local message="${2:-Command should succeed}"

    if ! eval "$command" >/dev/null 2>&1; then
        log_error "$message: command failed: $command"
        return 1
    fi

    log_debug "$message: OK"
}
```

#### Running Script Tests
```bash
# Test script functions
test_script_functions() {
    log_info "Testing script functions..."

    # Test logging functions
    assert_equals "$(log_info "test" 2>&1 | grep -c "INFO")" "1" "log_info should output INFO level"

    # Test file operations
    touch /tmp/test_file
    assert_file_exists "/tmp/test_file" "File creation should work"
    rm /tmp/test_file

    log_info "All script tests passed"
}
```

## Integration with Make

### Makefile Script Integration

```makefile
# Script execution wrapper
define run_script
	@echo -e "$$(PURPLE)=== Running $(1) ===$$(NC)"
	@if [ -f "scripts/$(1)" ]; then \
		if DEBUG=$${DEBUG:-0} VERBOSE=$${VERBOSE:-0} ./scripts/$(1) $(2); then \
			echo -e "$$(GREEN)[SUCCESS]$$(NC) $(1) completed"; \
		else \
			echo -e "$$(RED)[FAILED]$$(NC) $(1) failed"; \
			exit 1; \
		fi; \
	else \
		echo -e "$$(RED)[ERROR]$$(NC) Script not found: scripts/$(1)"; \
		exit 1; \
	fi
endef

# Usage in targets
up:
	$(call run_script,init.sh)
	$(call run_script,prepare-config.sh)
	$(DOCKER_COMPOSE) up -d
	@echo -e "$(GREEN)[SUCCESS]$(NC) Services started!"

ssl-setup:
	$(call run_script,ssl-manager.sh,issue)
```

## Security Considerations

### Script Security

#### Input Validation
```bash
# Validate input parameters
validate_input() {
    local input="$1"

    # Check for dangerous characters
    if [[ "$input" =~ [;&|] ]]; then
        log_error "Invalid characters in input: $input"
        exit 1
    fi

    # Validate length
    if [[ ${#input} -gt 100 ]]; then
        log_error "Input too long: ${#input} characters"
        exit 1
    fi
}
```

#### Secure File Operations
```bash
# Secure temporary file creation
create_temp_file() {
    local template="${1:-temp}"
    local temp_file

    temp_file=$(mktemp "/tmp/${template}.XXXXXX")
    chmod 600 "$temp_file"

    echo "$temp_file"
}

# Secure file copying
secure_copy() {
    local source="$1"
    local destination="$2"

    if [[ ! -f "$source" ]]; then
        log_error "Source file does not exist: $source"
        return 1
    fi

    # Create destination directory if needed
    mkdir -p "$(dirname "$destination")"

    # Copy with verification
    cp "$source" "$destination"
    chmod 644 "$destination"

    # Verify copy
    if ! cmp -s "$source" "$destination"; then
        log_error "File copy verification failed"
        rm -f "$destination"
        return 1
    fi
}
```

#### Credential Handling
```bash
# Secure credential reading
read_credential() {
    local prompt="$1"
    local credential

    # Disable echo for password input
    stty -echo
    echo -n "$prompt"
    read -r credential
    echo
    stty echo

    echo "$credential"
}

# Secure credential storage
store_credential() {
    local file="$1"
    local credential="$2"

    # Create directory if needed
    mkdir -p "$(dirname "$file")"

    # Store with secure permissions
    echo "$credential" > "$file"
    chmod 600 "$file"
}
```

### Audit Logging

#### Script Activity Logging
```bash
# Log all script executions
log_script_execution() {
    local script_name="$1"
    local arguments="$*"
    local user="$USER"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    echo "$timestamp|$user|$script_name|$arguments" >> "$PROJECT_ROOT/logs/script-audit.log"
}

# Log before execution
trap 'log_script_execution "$(basename "$0")" "$*"' EXIT
```

#### Security Event Logging
```bash
# Log security events
log_security_event() {
    local event_type="$1"
    local details="$2"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    echo "$timestamp|SECURITY|$event_type|$USER|$details" >> "$PROJECT_ROOT/logs/security.log"
}

# Example usage
log_security_event "SSL_CERT_RENEWAL" "Certificate renewed for $DOMAIN"
```

## Troubleshooting Scripts

### Common Script Issues

#### Permission Denied
```bash
# Check script permissions
ls -la scripts/*.sh

# Fix permissions
chmod +x scripts/*.sh

# Check execution context
whoami
id -u
```

#### Environment Not Loaded
```bash
# Check .env file
ls -la .env

# Validate .env syntax
bash -n .env

# Check variable values
grep -E "(PUID|PGID)" .env
```

#### Docker Connection Issues
```bash
# Check Docker socket
ls -la /var/run/docker.sock

# Test Docker connectivity
docker ps

# Check Docker group membership
groups | grep docker
```

#### Path Issues
```bash
# Check script directory structure
find scripts -name "*.sh" -type f

# Verify relative paths
pwd
ls -la ../

# Check for symbolic links
ls -la scripts/ | grep ^l
```

### Debug Mode

#### Enable Script Debugging
```bash
# Run with debug output
DEBUG=1 ./scripts/init.sh

# Enable bash debugging
bash -x ./scripts/init.sh

# Verbose output
VERBOSE=1 ./scripts/ssl-manager.sh check
```

#### Script Tracing
```bash
# Trace script execution
bash -x ./scripts/prepare-config.sh 2>&1 | tee script-trace.log

# Analyze trace output
grep -n "error\|Error\|ERROR" script-trace.log
```

## Related Documentation

- [DOCKER.md](DOCKER.md) - Container operations
- [CONFIG.md](CONFIG.md) - Configuration management
- [SSL.md](SSL.md) - Certificate management
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
- [DEVELOPMENT.md](DEVELOPMENT.md) - Script development guidelines