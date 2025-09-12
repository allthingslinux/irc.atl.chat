# SSL Setup - Enterprise-Grade & Automatic! 🚀

## What You Get

✅ **One-command setup**: `make ssl-setup`
✅ **Automatic renewal**: Every day at 2 AM
✅ **Enterprise logging**: Debug/verbose modes with full error handling
✅ **Safety first**: Confirmation prompts for dangerous operations
✅ **Docker-based monitoring**: No host cron jobs needed
✅ **Zero maintenance**: Just works forever

## Quick Start (3 Steps)

```bash
# 1. Setup credentials
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your API token

# 2. Configure your domain (already set in .env)
# IRC_ROOT_DOMAIN=atl.dev
# LETSENCRYPT_EMAIL=admin@allthingslinux.org

# 3. One command does everything
make ssl-setup
```

## Advanced Usage & Debugging

```bash
# Basic commands
make ssl-status        # Check SSL status
make ssl-logs          # View monitoring logs

# Advanced troubleshooting
./scripts/ssl-manager.sh --verbose check    # Detailed output
./scripts/ssl-manager.sh --debug issue      # Full debugging
./scripts/ssl-manager.sh --help             # Complete help

# Force operations
make ssl-renew         # Force certificate renewal
make ssl-stop          # Stop SSL monitoring
make ssl-clean         # Remove certificates (with confirmation)
```

## How It Works

The system is built with **enterprise-grade reliability**:

### 🔄 Automatic Monitoring (ssl-monitor container)
- **Checks certificates** every 4 hours
- **Renews automatically** at 2 AM when certificates expire within 30 days
- **Validates configurations** before operations
- **Comprehensive logging** with color-coded output
- **Smart error handling** with specific troubleshooting

### 🛡️ Safety Features
- **Input validation**: Domain and email format checking
- **File permission checks**: Ensures proper access rights
- **Docker availability**: Validates Docker environment
- **Confirmation prompts**: Prevents accidental certificate deletion
- **Graceful degradation**: Continues working despite minor issues

### 📊 Enhanced Logging System
```bash
# Different log levels
INFO:   General operations and success messages
WARN:   Non-critical issues and upcoming expirations
ERROR:  Failures and configuration problems
DEBUG:  Detailed technical information (--debug flag)
VERBOSE: Enhanced operational details (--verbose flag)
```

## Files & Directories

### Core Files
- `scripts/ssl-manager.sh`: Enhanced SSL management script with full error handling
- `compose.yaml`: SSL monitoring container configuration
- `Makefile`: Complete SSL management targets

### Certificate Storage
- `src/backend/unrealircd/conf/tls/server.cert.pem`: SSL certificate for IRCd
- `src/backend/unrealircd/conf/tls/server.key.pem`: SSL private key for IRCd
- `data/letsencrypt/`: Let's Encrypt ACME challenge data

### Configuration Files
- `cloudflare-credentials.ini`: Cloudflare API token (keep secure!)
- `.env`: Environment variables (IRC_ROOT_DOMAIN, LETSENCRYPT_EMAIL)

## Environment Variables

From your `.env` file:
- `IRC_ROOT_DOMAIN`: Your domain (e.g., `atl.dev`) - **required**
- `LETSENCRYPT_EMAIL`: Contact email for Let's Encrypt - **required**

## Complete Command Reference

### Makefile Targets
```bash
make ssl-setup      # Complete SSL setup with monitoring
make ssl-status     # Check certificate status and monitoring
make ssl-renew      # Force certificate renewal (with safety checks)
make ssl-logs       # View SSL monitoring logs
make ssl-stop       # Stop SSL monitoring container
make ssl-clean      # Remove certificates and monitoring (CAUTION!)
```

### Script Direct Commands
```bash
./scripts/ssl-manager.sh check       # Check certificate validity
./scripts/ssl-manager.sh issue       # Issue new certificates
./scripts/ssl-manager.sh renew       # Renew existing certificates
./scripts/ssl-manager.sh copy        # Copy certificates to IRCd
./scripts/ssl-manager.sh restart     # Restart certificate-dependent services
```

### Debug Options
```bash
--help, -h           # Show comprehensive help
--verbose, -v        # Enhanced operational logging
--debug, -d          # Maximum debugging output
```

## Troubleshooting Guide

### Common Issues & Solutions

#### ❌ "Cloudflare credentials not found"
```bash
# Check credentials file exists
ls -la cloudflare-credentials.ini

# Verify format (should contain one line)
cat cloudflare-credentials.ini
# Expected: dns_cloudflare_api_token = YOUR_TOKEN_HERE
```

#### ❌ "Certificate file is not readable"
```bash
# Check file permissions
ls -la src/backend/unrealircd/conf/tls/

# Fix permissions if needed
chmod 644 src/backend/unrealircd/conf/tls/server.cert.pem
chmod 644 src/backend/unrealircd/conf/tls/server.key.pem
```

#### ❌ "Domain validation failed"
```bash
# Check .env file has correct values
cat .env | grep -E "(IRC_ROOT_DOMAIN|LETSENCRYPT_EMAIL)"

# Verify domain format (no http:// or trailing slashes)
# Correct: IRC_ROOT_DOMAIN=atl.dev
# Wrong:   IRC_ROOT_DOMAIN=https://atl.dev/
```

#### ❌ "Docker socket not accessible"
```bash
# Check Docker is running
docker --version
docker ps

# Check socket permissions (Linux)
ls -la /var/run/docker.sock

# Try with sudo if permission denied
sudo make ssl-setup
```

### Debug Commands
```bash
# Maximum debugging output
./scripts/ssl-manager.sh --debug issue

# Check certificate expiry manually
openssl x509 -in src/backend/unrealircd/conf/tls/server.cert.pem -noout -enddate

# Verify certificate validity
./scripts/ssl-manager.sh --verbose check

# Check Docker container status
docker compose ps ssl-monitor
```

## Best Practices

### 🔒 Security
- Never commit `cloudflare-credentials.ini` to git
- Keep `.env` secure and don't share API tokens
- Use strong, unique API tokens with minimal permissions
- Regularly rotate Cloudflare API tokens

### 📊 Monitoring
- Check `make ssl-status` regularly
- Monitor logs with `make ssl-logs`
- Set up alerts for certificate expiry warnings
- Keep an eye on Let's Encrypt rate limits (20 certificates per domain/week)

### 🔄 Maintenance
- Let automatic renewal handle most tasks
- Use `make ssl-renew` only when needed
- Clean up old certificates periodically if needed
- Backup certificates before major changes

### 🚨 Emergency Procedures
```bash
# If certificates expire unexpectedly
make ssl-renew

# If monitoring stops working
docker compose restart ssl-monitor

# Complete reset (CAUTION!)
make ssl-clean
make ssl-setup
```

## Advanced Configuration

### Custom Certificate Paths
The script uses these default paths (defined in ssl-manager.sh):
```bash
TLS_DIR="./src/backend/unrealircd/conf/tls"
LETSENCRYPT_DIR="./data/letsencrypt"
CREDENTIALS_FILE="./cloudflare-credentials.ini"
```

### Custom Domains
For multiple domains or wildcards:
```bash
# The script automatically handles:
# - yourdomain.com
# - *.yourdomain.com (wildcard)
```

### Docker Network Considerations
The ssl-monitor container runs on the same network as your IRC services, ensuring proper certificate deployment.

## Migration from Manual Setup

If you're migrating from a manual SSL setup:

1. **Backup existing certificates** (if any)
2. **Stop existing renewal processes**
3. **Run `make ssl-setup`** to establish automated management
4. **Remove old cron jobs or renewal scripts**
5. **Verify with `make ssl-status`**

## That's It!

No complex configuration, no host dependencies, no manual management.
SSL certificates are now **completely automatic**, **enterprise-grade**, and **Docker-native**.

**Need help?** Run `./scripts/ssl-manager.sh --help` or check the logs with `make ssl-logs`! 🎉
