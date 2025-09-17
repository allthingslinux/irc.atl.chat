# Secret Management Guide

This guide covers the management of passwords, API tokens, and other sensitive configuration for IRC.atl.chat. Proper secret management is critical for security and operational integrity.

## Overview

IRC.atl.chat uses a comprehensive secret management approach with environment variables, secure file permissions, and automated configuration processing. All secrets are managed through the `.env` file and external credential files.

### Security Principles

- **No hardcoded secrets**: Never commit secrets to version control
- **Environment isolation**: Separate development and production secrets
- **Least privilege**: Minimal required permissions for each secret
- **Regular rotation**: Periodic secret renewal
- **Access control**: Restricted file permissions and ownership

## Environment Variables and .env File

### .env File Management

The `.env` file is the central location for all configuration, including sensitive data:

```bash
# Copy template and customize
cp env.example .env

# Edit with your values
vim .env

# File is automatically ignored by .gitignore
```

### Critical Security Variables

#### IRC Operator Password
```bash
# Generate secure password hash
docker compose exec unrealircd /home/unrealircd/unrealircd/bin/unrealircd mkpasswd

# Add to .env
IRC_OPER_PASSWORD='$argon2id$v=19$m=6144,t=2,p=2$WXOLpTE+DPDr8q6OBVTx3w$bqXpBsaAK6lkXfR/IPn+TcE0VJEKjUFD7xordE6pFSo'
```

#### Atheme Service Passwords
```bash
# Generate secure random passwords
openssl rand -base64 32

# Configure in .env
ATHEME_SEND_PASSWORD=your_secure_send_password_here
ATHEME_RECEIVE_PASSWORD=your_secure_receive_password_here
IRC_SERVICES_PASSWORD=your_secure_services_password_here
```

#### Web Panel Credentials
```bash
WEBPANEL_RPC_USER=adminpanel
WEBPANEL_RPC_PASSWORD=your_secure_webpanel_password
```

### Environment Variable Validation

The system validates critical environment variables:

```bash
# Check configuration
./scripts/prepare-config.sh

# Validate SSL settings
./scripts/ssl-manager.sh check
```

## API Tokens and External Credentials

### Cloudflare API Token

#### Setup
```bash
# Copy template
cp cloudflare-credentials.ini.template cloudflare-credentials.ini

# Edit with your token
vim cloudflare-credentials.ini
# dns_cloudflare_api_token = your-actual-api-token-here

# Secure permissions
chmod 600 cloudflare-credentials.ini
```

#### Token Requirements
- **Type**: API Token (not Global API Key)
- **Permissions**: Zone:DNS:Edit for your domain
- **Scope**: Limited to DNS operations only

#### Token Security
- Store outside version control
- Restrict file permissions (600)
- Rotate periodically (every 6-12 months)
- Monitor usage in Cloudflare dashboard

### Let's Encrypt Email

```bash
# In .env file
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

This email receives:
- Certificate expiry notifications
- Security alerts from Let's Encrypt
- Account recovery information

## Password Generation and Storage

### Secure Password Generation

#### IRC Operator Password
```bash
# Use UnrealIRCd's built-in password generator
docker compose exec unrealircd /home/unrealircd/unrealircd/bin/unrealircd mkpasswd

# Interactive password creation
docker compose exec unrealircd /home/unrealircd/unrealircd/bin/unrealircd mkpasswd
Enter password: ********
Re-enter password: ********
$argon2id$v=19$m=6144,t=2,p=2$abc123... (copy this hash)
```

#### Random Passwords for Services
```bash
# Generate base64-encoded random password (32 bytes = 43 characters)
openssl rand -base64 32

# Generate hex-encoded password (64 characters)
openssl rand -hex 32

# Generate alphanumeric password (only letters and numbers)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```

### Password Storage Format

#### Hashed Passwords (IRC Operators)
- **Algorithm**: Argon2id (default in UnrealIRCd 6)
- **Format**: `$argon2id$v=19$m=6144,t=2,p=2$salt$hash`
- **Security**: Memory-hard, resistant to brute force and GPU attacks

#### Plaintext Passwords (Service Communication)
- Used for Atheme-UnrealIRCd communication
- Must be identical in both configurations
- Should be long random strings (32+ characters)

## Security Best Practices

### File Permissions

#### Critical Files
```bash
# Credentials files: owner read/write only
chmod 600 cloudflare-credentials.ini
chmod 600 .env

# Configuration directories: owner access only
chmod 700 data/letsencrypt/
chmod 700 logs/

# Certificate files: readable by services
chmod 644 src/backend/unrealircd/conf/tls/server.cert.pem
chmod 644 src/backend/unrealircd/conf/tls/server.key.pem
```

#### Permission Verification
```bash
# Check critical file permissions
ls -la .env cloudflare-credentials.ini
ls -la src/backend/unrealircd/conf/tls/

# Verify ownership (should match PUID/PGID in .env)
ls -ln data/letsencrypt/
```

### Password Policies

#### IRC Operator Passwords
- **Minimum length**: 12 characters
- **Complexity**: Mixed case, numbers, symbols
- **Algorithm**: Argon2id (modern, secure)
- **Rotation**: Every 90 days or after compromise

#### Service Passwords
- **Length**: 32+ characters
- **Generation**: Cryptographically secure random
- **Storage**: Environment variables only
- **Rotation**: During maintenance windows

### Access Control

#### Development vs Production
```bash
# Development: Use test values
IRC_OPER_PASSWORD='$argon2id$test-hash-here'

# Production: Use strong, unique passwords
IRC_OPER_PASSWORD='$argon2id$production-hash-here'
```

#### Multi-Administrator Setup
- Use shared password manager (Bitwarden, 1Password)
- Document password purposes and rotation schedules
- Implement approval process for password changes

## Secret Rotation Procedures

### IRC Operator Password

1. **Generate new password hash**
   ```bash
   docker compose exec unrealircd /home/unrealircd/unrealircd/bin/unrealircd mkpasswd
   ```

2. **Update .env file**
   ```bash
   vim .env
   # Replace IRC_OPER_PASSWORD with new hash
   ```

3. **Regenerate configuration**
   ```bash
   make build
   ```

4. **Restart services**
   ```bash
   make restart
   ```

5. **Test new password**
   ```bash
   # Connect to IRC and test /OPER command
   /OPER yournick yournewpassword
   ```

### Atheme Service Passwords

1. **Generate new passwords**
   ```bash
   NEW_SEND_PASS=$(openssl rand -base64 32)
   NEW_RECV_PASS=$(openssl rand -base64 32)
   ```

2. **Update .env file**
   ```bash
   sed -i "s/ATHEME_SEND_PASSWORD=.*/ATHEME_SEND_PASSWORD=$NEW_SEND_PASS/" .env
   sed -i "s/ATHEME_RECEIVE_PASSWORD=.*/ATHEME_RECEIVE_PASSWORD=$NEW_RECV_PASS/" .env
   ```

3. **Regenerate configurations**
   ```bash
   make build
   ```

4. **Restart services in order**
   ```bash
   # Restart UnrealIRCd first
   docker restart unrealircd

   # Wait for IRCd to be ready
   sleep 10

   # Restart Atheme
   docker restart atheme

   # Restart WebPanel
   docker restart unrealircd-webpanel
   ```

### Cloudflare API Token

1. **Create new token in Cloudflare**
   - Go to API Tokens section
   - Create new token with Zone:DNS:Edit permissions

2. **Update credentials file**
   ```bash
   vim cloudflare-credentials.ini
   # Replace dns_cloudflare_api_token with new token
   ```

3. **Test SSL functionality**
   ```bash
   ./scripts/ssl-manager.sh check --verbose
   ```

4. **Revoke old token**
   - Delete old token in Cloudflare dashboard
   - Confirm SSL still works with new token

## Backup and Recovery

### Secret Backup Strategy

#### What to Backup
- `.env` file (encrypted or secure location)
- `cloudflare-credentials.ini` (encrypted)
- Certificate private keys (`data/letsencrypt/`)

#### What NOT to Backup
- Generated configuration files (they're regenerated)
- Log files (can be recreated)
- Cache files

#### Secure Backup Commands
```bash
# Create encrypted backup
tar -czf secrets-backup-$(date +%Y%m%d).tar.gz .env cloudflare-credentials.ini
openssl enc -aes-256-cbc -salt -in secrets-backup-*.tar.gz -out secrets-backup-*.enc

# Secure the encrypted backup
chmod 600 secrets-backup-*.enc
```

### Recovery Procedures

#### Full System Recovery
1. **Restore .env file**
   ```bash
   # Decrypt and extract backup
   openssl enc -d -aes-256-cbc -in secrets-backup.enc -out secrets-backup.tar.gz
   tar -xzf secrets-backup.tar.gz
   ```

2. **Restore Cloudflare credentials**
   ```bash
   cp cloudflare-credentials.ini.backup cloudflare-credentials.ini
   chmod 600 cloudflare-credentials.ini
   ```

3. **Rebuild configurations**
   ```bash
   make build
   ```

4. **Restore SSL certificates**
   ```bash
   ./scripts/ssl-manager.sh copy
   ```

5. **Start services**
   ```bash
   make up
   ```

## Monitoring and Auditing

### Secret Health Checks

```bash
# Check environment variables are set
./scripts/prepare-config.sh

# Verify SSL certificates
make ssl-status

# Test service connectivity
make health-check
```

### Audit Logging

#### Configuration Changes
```bash
# Log configuration updates
echo "$(date): Updated IRC_OPER_PASSWORD" >> audit.log

# Track password rotations
echo "$(date): Rotated Atheme passwords" >> audit.log
```

#### Access Monitoring
- Monitor Cloudflare API token usage
- Check for unauthorized file access attempts
- Log configuration regeneration events

### Alert Configuration

Set up alerts for:
- Certificate expiry (via Let's Encrypt email)
- Configuration file changes
- Failed authentication attempts
- Unusual API token usage

## Troubleshooting

### Common Issues

#### "Environment variable not set"
```bash
# Check .env file exists and is readable
ls -la .env
cat .env | grep VARIABLE_NAME

# Validate .env syntax
bash -n .env

# Regenerate configurations
make build
```

#### "Permission denied" errors
```bash
# Check file ownership
ls -ln .env cloudflare-credentials.ini

# Verify PUID/PGID in .env match your user
id -u && id -g

# Fix ownership if needed
sudo chown $(id -u):$(id -g) .env cloudflare-credentials.ini
```

#### "Password authentication failed"
```bash
# Verify password hash format
grep IRC_OPER_PASSWORD .env

# Test with known good password
docker compose exec unrealircd /home/unrealircd/unrealircd/bin/unrealircd mkpasswd

# Check UnrealIRCd logs
make logs | grep -i oper
```

#### "Services not connecting"
```bash
# Verify Atheme passwords match
grep ATHEME_SEND_PASSWORD .env
grep ATHEME_RECEIVE_PASSWORD .env

# Check service logs
docker logs atheme
docker logs unrealircd

# Test service connectivity
docker exec unrealircd nc -z localhost 6901
```

### Debug Procedures

#### Enable Debug Logging
```bash
# Debug configuration processing
DEBUG=1 ./scripts/prepare-config.sh

# Verbose SSL operations
./scripts/ssl-manager.sh --debug check

# Test service authentication
make test-services
```

#### Password Recovery
If passwords are lost:

1. **IRC Operator**: Generate new password hash and update configuration
2. **Atheme Services**: Generate new passwords and update both IRCd and Atheme configs
3. **Web Panel**: Update RPC password in both .env and webpanel config

## Emergency Procedures

### Complete Secret Compromise

If all secrets are compromised:

1. **Immediate Actions**
   - Revoke Cloudflare API token
   - Change all passwords
   - Generate new SSL certificates

2. **System Reset**
   ```bash
   # Stop all services
   make down

   # Remove old configurations
   rm -rf data/atheme/* data/unrealircd/*
   rm -rf src/backend/*/conf/*.conf

   # Update all secrets in .env
   vim .env

   # Rebuild everything
   make build
   make ssl-setup
   make up
   ```

3. **Verification**
   - Test all services start correctly
   - Verify SSL certificates work
   - Test authentication with new credentials

## Related Documentation

- [SSL.md](SSL.md) - SSL certificate management
- [README.md](../README.md) - Quick start and configuration
- [USERMODES.md](USERMODES.md) - IRC user mode reference
- [UnrealIRCd Security Documentation](https://www.unrealircd.org/docs/Security) - Server security
- [Atheme Security Guide](https://github.com/atheme/atheme/wiki/Security) - Services security