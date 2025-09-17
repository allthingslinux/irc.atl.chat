# Makefile Commands and Automation

This guide covers the Makefile system used for building, deploying, and managing IRC.atl.chat. The Makefile provides a comprehensive set of commands for all aspects of the IRC infrastructure.

## Overview

### Makefile Structure

The Makefile is organized into logical sections:

```
Makefile Sections:
├── Help & Information    - Usage information and system status
├── Building             - Container and image management
├── Service Management   - Starting, stopping, and monitoring
├── Testing              - Comprehensive test suites
├── SSL Management       - Certificate automation
├── Module Management    - UnrealIRCd module handling
├── Maintenance          - Cleanup and system management
└── Utilities            - Helper commands
```

### Command Categories

#### Quick Start Commands
```bash
make up          # Complete setup and start (recommended)
make down        # Stop all services
make restart     # Restart services
make status      # Check service status
```

#### Development Commands
```bash
make test        # Run all tests
make build       # Build containers
make logs        # View service logs
make lint        # Code quality checks
```

## Core Commands

### Service Lifecycle

#### Complete Setup (`make up`)
```bash
# What it does:
# 1. Initializes directories and permissions
# 2. Processes configuration templates
# 3. Builds Docker containers
# 4. Starts all services
# 5. Sets up proper file ownership
make up
```

#### Service Management
```bash
# Start services (assumes setup complete)
make start-only

# Stop all services
make down

# Stop and remove containers/networks
make stop

# Restart all services
make restart

# Force rebuild and restart
make rebuild
```

#### Selective Service Control
```bash
# View specific service logs
make logs-ircd        # UnrealIRCd logs
make logs-atheme      # Atheme logs
make logs-webpanel    # WebPanel logs

# Quick service access
make webpanel         # Open WebPanel info
```

### Building and Development

#### Container Building
```bash
# Build all containers
make build

# Rebuild without cache (clean build)
make rebuild

# Build and start (equivalent to make up)
make quick-start
```

#### Development Environment
```bash
# Access development shell
make dev-shell

# View all logs with timestamps
make dev-logs

# Run linting checks
make lint
```

### Testing Framework

#### Test Categories
```bash
# Complete test suite
make test

# Unit tests (no Docker required)
make test-unit

# Integration tests (requires Docker)
make test-integration

# End-to-end tests (full workflow)
make test-e2e

# Protocol compliance tests
make test-protocol

# Performance tests
make test-performance

# Service integration tests
make test-services

# Docker-specific tests
make test-docker
```

#### Specialized Testing
```bash
# Environment validation
make test-env

# IRC functionality tests
make test-irc

# Quick health checks
make test-quick
```

### SSL Certificate Management

#### Certificate Lifecycle
```bash
# One-command SSL setup
make ssl-setup

# Check certificate status
make ssl-status

# Force certificate renewal
make ssl-renew

# View SSL monitoring logs
make ssl-logs

# Stop SSL monitoring
make ssl-stop

# Remove certificates (CAUTION)
make ssl-clean
```

#### SSL Automation
The SSL system provides:
- Automatic certificate issuance via Let's Encrypt
- Daily renewal checks at 2 AM
- Service restart after certificate updates
- Comprehensive error handling and logging

### Module Management

#### Module Operations
```bash
# List available modules
make modules-list

# Show installed modules
make modules-installed

# Generate operator password
make generate-password
```

#### Module System
- **Third-party modules**: Community extensions
- **Custom modules**: Site-specific functionality
- **Automatic installation**: Script-based deployment

## Advanced Commands

### System Management

#### Information and Diagnostics
```bash
# Comprehensive help
make help

# System information
make info

# Quick environment check
make test-quick
```

#### Maintenance Operations
```bash
# Clean up containers and images
make clean

# Complete system reset (WARNING: destroys data)
make reset

# Remove everything and start fresh
make reset  # Requires confirmation
```

### Configuration Management

#### Setup Commands
```bash
# Initial setup only (no start)
make setup

# Setup and start services
make start-only

# Setup with permission handling
make up  # Includes init.sh and prepare-config.sh
```

#### Permission Management
The Makefile automatically handles:
- Directory creation
- File permission fixes
- User/group alignment (PUID/PGID)
- Cross-platform compatibility

## Command Reference

### Service Management

| Command | Description | Use Case |
|---------|-------------|----------|
| `make up` | Complete setup and start | First-time setup |
| `make down` | Stop all services | Shutdown |
| `make restart` | Restart services | Configuration changes |
| `make status` | Show service status | Monitoring |
| `make logs` | View all logs | Debugging |

### Building

| Command | Description | Use Case |
|---------|-------------|----------|
| `make build` | Build containers | Development |
| `make rebuild` | Clean rebuild | Dependency changes |
| `make quick-start` | Build and start | Fast iteration |

### Testing

| Command | Description | Test Type |
|---------|-------------|-----------|
| `make test` | Full test suite | Comprehensive |
| `make test-unit` | Unit tests | Fast, isolated |
| `make test-integration` | Integration tests | Service interaction |
| `make test-e2e` | End-to-end tests | Full workflow |
| `make test-protocol` | IRC protocol tests | Compliance |
| `make test-performance` | Performance tests | Load testing |
| `make test-services` | Service tests | Atheme integration |

### SSL Management

| Command | Description | Frequency |
|---------|-------------|-----------|
| `make ssl-setup` | Initial certificate setup | Once |
| `make ssl-status` | Check certificate status | Daily/Weekly |
| `make ssl-renew` | Force renewal | When needed |
| `make ssl-logs` | View SSL logs | Troubleshooting |
| `make ssl-stop` | Stop monitoring | Maintenance |
| `make ssl-clean` | Remove certificates | Emergency |

## Automation Scripts

### Initialization Script (`scripts/init.sh`)

Handles initial setup:
```bash
# Creates required directories
mkdir -p data/{unrealircd,atheme,letsencrypt}
mkdir -p logs/{unrealircd,atheme}

# Sets proper permissions
chown -R $(id -u):$(id -g) data/ logs/

# Creates .env if missing
if [ ! -f .env ]; then
    cp env.example .env
fi
```

### Configuration Script (`scripts/prepare-config.sh`)

Processes templates:
```bash
# Environment variable substitution
envsubst < template.conf > generated.conf

# Validates configuration
# Sets file permissions
chmod 644 generated.conf
```

### SSL Manager (`scripts/ssl-manager.sh`)

Certificate automation:
```bash
# Commands: check, issue, renew, copy, restart
# Features: verbose logging, error handling, service restart
```

## Error Handling

### Common Issues

#### Permission Errors
```bash
# Symptom: "Permission denied"
# Solution: Check PUID/PGID in .env
make up  # Automatically fixes permissions

# Manual fix
export PUID=$(id -u)
export PGID=$(id -g)
```

#### Build Failures
```bash
# Symptom: "Build failed"
# Solution: Clean rebuild
make rebuild

# Check build logs
docker compose build --progress=plain unrealircd
```

#### Service Won't Start
```bash
# Check service status
make status

# View specific logs
make logs-ircd

# Validate configuration
make test-env
```

### Debug Mode

#### Enable Verbose Output
```bash
# Add debug flags
DEBUG=1 make up

# Verbose SSL operations
VERBOSE=1 make ssl-setup
```

#### Manual Command Execution
```bash
# Run commands manually
docker compose up -d
docker compose logs -f

# Check environment
env | grep -E "(PUID|PGID|VERSION)"
```

## Performance Optimization

### Build Optimization

#### Layer Caching
```bash
# Use build cache when possible
make build

# Force clean build when needed
make rebuild
```

#### Parallel Building
```bash
# Build multiple services in parallel
docker compose build --parallel
```

### Runtime Optimization

#### Resource Management
```bash
# Monitor resource usage
docker stats

# Check container limits
make info
```

#### Log Management
```bash
# Rotate logs automatically
# Monitor disk usage
make info
```

## Customization

### Adding New Commands

#### Makefile Structure
```makefile
# Add new command
new-command:
	@echo "Running new command..."
	@./scripts/new-script.sh

# Add to help
	@echo "  make new-command      - Description"
```

#### Script Integration
```bash
# Create script in scripts/ directory
# Make executable: chmod +x scripts/new-script.sh
# Add error handling and logging
```

### Environment Variables

#### Custom Variables
```bash
# Add to .env
CUSTOM_VAR=value

# Use in Makefile
CUSTOM_VAR ?= default_value
```

#### Conditional Logic
```makefile
# Conditional commands
ifdef DEBUG
	COMMAND += --debug
endif
```

## Monitoring and Maintenance

### Regular Tasks

#### Daily Checks
```bash
# Check service health
make status

# Monitor SSL certificates
make ssl-status

# Run quick tests
make test-quick
```

#### Weekly Maintenance
```bash
# Update containers
docker compose pull

# Clean up resources
make clean

# Check disk usage
make info
```

#### Monthly Tasks
```bash
# Full test suite
make test

# Log rotation
# Backup verification

# Performance monitoring
make test-performance
```

### Automated Monitoring

#### Health Checks
```bash
# Container health status
docker ps --filter "health=healthy"

# Service connectivity
make test-env
```

#### Alert Integration
```bash
# Check for failures
if ! make test-quick >/dev/null 2>&1; then
    echo "Health check failed!"
    # Send alert
fi
```

## Troubleshooting

### Command Failures

#### `make up` Fails
```bash
# Check prerequisites
docker --version
docker compose version

# Validate .env file
cat .env | grep -E "(DOMAIN|EMAIL)"

# Check disk space
make info
```

#### SSL Setup Fails
```bash
# Check Cloudflare credentials
ls -la cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini

# Validate domain
dig ${IRC_ROOT_DOMAIN}

# Check logs
make ssl-logs
```

#### Tests Fail
```bash
# Run specific test with verbose output
make test-unit TEST_VERBOSE=1

# Check test environment
make test-env

# Validate Docker setup
make test-docker
```

### Recovery Procedures

#### Service Recovery
```bash
# Restart failed services
make restart

# Rebuild if needed
make rebuild

# Check logs for errors
make logs
```

#### Complete Reset
```bash
# WARNING: Destroys all data
make reset

# Followed by fresh setup
make up
```

## Integration with CI/CD

### GitHub Actions Integration

#### Build Workflow
```yaml
- name: Build containers
  run: make build

- name: Run tests
  run: make test

- name: Deploy
  run: make up
```

#### Automated Testing
```yaml
- name: Test suite
  run: |
    make test-unit
    make test-integration
    make test-e2e
```

### Custom CI/CD

#### Pre-deployment Checks
```bash
# Validate configuration
make test-env

# Check SSL setup
make ssl-status

# Run security tests
make test-security
```

#### Deployment Automation
```bash
# Blue-green deployment
make deploy-blue
# ... validation ...
make switch-traffic
make decommission-green
```

## Best Practices

### Usage Guidelines

#### Development Workflow
```bash
# Daily development cycle
make up          # Start environment
# Make changes
make rebuild     # Test changes
make test        # Validate
make down        # Clean shutdown
```

#### Production Deployment
```bash
# Careful production updates
make test        # Full validation
make backup      # Create backups
make up          # Deploy changes
make status      # Verify health
```

### Security Considerations

#### Access Control
```bash
# Secure file permissions
chmod 600 .env cloudflare-credentials.ini

# Use secure passwords
make generate-password
```

#### Audit Logging
```bash
# Log all make commands
echo "$(date): make $@" >> makefile-audit.log

# Monitor for suspicious activity
grep "make.*ssl-clean" makefile-audit.log
```

## Related Documentation

- [README.md](../README.md) - Quick start guide
- [DOCKER.md](DOCKER.md) - Container setup details
- [CONFIG.md](CONFIG.md) - Configuration management
- [SSL.md](SSL.md) - SSL certificate management
- [UNREALIRCD.md](UNREALIRCD.md) - IRC server configuration