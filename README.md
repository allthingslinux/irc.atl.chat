# IRC.atl.chat - Professional IRC Server Setup

A production-ready IRC server setup using UnrealIRCd with modern security, SSL/TLS support, and containerization.

## 🚀 Quick Start

```bash
# Complete setup
make setup

# Start the IRC server
make up

# Check status
make status
```

## 📋 Configuration

### Environment Variables

The server uses environment variables for configuration. There are two types of environment files:

#### Public Configuration (`env.example`)
Contains non-sensitive configuration that can be committed to version control.

#### Private Configuration (`.env.local`)
Contains sensitive data that should NEVER be committed. This file is automatically excluded via `.gitignore`.

### Setting up Environment Files

1. **Create public configuration:**
   ```bash
   make setup-env
   ```

2. **Create private configuration:**
   ```bash
   make setup-private-env
   ```

3. **Generate secure operator password:**
   ```bash
   make generate-oper-password
   ```

### Environment Variables Reference

#### IRC Server Configuration
```bash
# Server details
IRC_DOMAIN=irc.atl.chat
IRC_PORT=6667                    # Standard IRC port
IRC_TLS_PORT=6697               # SSL/TLS IRC port
IRC_SERVER_PORT=6900           # Server-to-server TLS port
IRC_RPC_PORT=8600              # JSON-RPC API port

# Network configuration
IRC_NETWORK_NAME=atl.chat
IRC_CLOAK_PREFIX=atl
IRC_ADMIN_EMAIL=admin@yourdomain.com
IRC_ADMIN_NAME="Your Admin Name"
```

#### IRC Operator Credentials (PRIVATE!)
```bash
# Generate with: make generate-oper-password
IRC_OPER_PASSWORD='$argon2id$...'
```

#### SSL/TLS Configuration
```bash
LETSENCRYPT_EMAIL=admin@yourdomain.com
SSL_CERT_PATH=./.runtime/certs
```

## 🔐 Security Features

### External Sensitive Data
- IRC operator passwords stored in `.env.local` (not committed)
- SSL certificates managed externally
- Database credentials (if used) stored securely

### SSL/TLS Support
- Modern TLS 1.2/1.3 protocols
- Strong cipher suites
- **Automatic certificate management** with Let's Encrypt + Cloudflare DNS
- Server Name Indication (SNI) support

### Container Security
- Non-root user execution (`no-new-privileges`)
- Minimal attack surface
- Resource limits and health monitoring

## 🔑 SSL Certificate Management

### 🎯 **RECOMMENDED: Best Practice Approach**

For **production deployments**, use the standalone certificate manager:

```bash
# 1. Start certificate manager (runs independently)
make certbot-up

# 2. Issue initial certificates
make certbot-issue

# 3. Check status
make certbot-status-check

# 4. Start your IRC server (certificates auto-loaded)
make up
```

**Benefits:**
- ✅ **Separation of Concerns**: Certificates managed independently
- ✅ **Persistent Storage**: Certificates survive container restarts
- ✅ **Centralized Management**: One manager for multiple services
- ✅ **Better Monitoring**: Dedicated health checks and logging
- ✅ **Scalable**: Can manage certificates for multiple domains/services

### 🚀 **Quick Start Approach** (Current Setup)

For **development/testing**, use the integrated approach:

```bash
# Configure Cloudflare credentials
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini

# Set environment variables in .env.local
LETSENCRYPT_EMAIL=your-email@example.com
IRC_DOMAIN=irc.yourdomain.com

# Issue certificates
make setup-ssl

# Start everything
make up
```

**Benefits:**
- ✅ **Simple**: Everything in one compose file
- ✅ **Quick**: Fast setup for development
- ✅ **Integrated**: Certificates managed alongside services

### 📊 **Comparison**

| Feature | Standalone Manager | Integrated Approach |
|---------|-------------------|-------------------|
| **Complexity** | Medium | Simple |
| **Production Ready** | ✅ High | ⚠️ Medium |
| **Separation** | ✅ Excellent | ⚠️ Good |
| **Persistence** | ✅ Excellent | ⚠️ Good |
| **Monitoring** | ✅ Dedicated | ⚠️ Basic |
| **Multi-Service** | ✅ Excellent | ❌ Limited |
| **Setup Time** | ⏱️ Longer | ⚡ Faster |

### 🔧 **Manual Commands**

```bash
# === STANDALONE MANAGER ===
make certbot-up              # Start certificate manager
make certbot-down            # Stop certificate manager
make certbot-status          # Check manager status
make certbot-logs            # View manager logs
make certbot-issue           # Issue certificates
make certbot-renew           # Renew certificates
make certbot-status-check    # Check certificate status

# === INTEGRATED APPROACH ===
make setup-ssl               # Setup certificates
make ssl-renew               # Manual renewal
make ssl-check               # Check status
make ssl-monitor             # Start monitoring
```

### 📋 **Prerequisites (Both Approaches)**

1. **Cloudflare Account** with DNS hosting
2. **API Token** from https://dash.cloudflare.com/profile/api-tokens
   - Required permission: `Zone:DNS:Edit` for your domain
3. **Domain Configuration** pointing to your server

### ⚙️ **Environment Variables**

Add to `.env.local`:
```bash
# Required for both approaches
LETSENCRYPT_EMAIL=admin@yourdomain.com
IRC_DOMAIN=irc.yourdomain.com
CLOUDFLARE_EMAIL=your-email@yourdomain.com
CLOUDFLARE_API_KEY=your-api-token-here
```

### 🔄 **Automatic vs Manual Certificate Management**

| **Automatic (Ongoing)** | **Manual (One-time Setup)** |
|--------------------------|------------------------------|
| ✅ Certificate renewal (every 30 days) | ❌ Initial certificate issuance |
| ✅ Health monitoring (24/7) | ❌ Cloudflare credential setup |
| ✅ Automatic restart after renewal | ❌ Domain DNS configuration |
| ✅ Log rotation and cleanup | ❌ First-time SSL setup |

**What Happens Automatically:**
- ✅ **Certificate renewal** every 30 days (no manual intervention)
- ✅ **Persistent storage** across container restarts
- ✅ **Centralized logging** and monitoring
- ✅ **Health checks** and status monitoring
- ✅ **Automatic IRC config reload** after renewal

**What Requires Manual Setup:**
- ❌ **Initial certificate issuance** (DNS challenge, domain validation)
- ❌ **Cloudflare credential configuration** (API keys, permissions)
- ❌ **Domain DNS setup** (pointing to your server)

### 📁 File Structure (Merged)
```
irc.atl.chat/
├── compose.yaml              # 🎯 Main Docker Compose (everything integrated)
├── Containerfile             # Docker build instructions
├── .env.local                 # 🔑 Private environment variables
├── cloudflare-credentials.ini # 🔐 Cloudflare API credentials
└── scripts/
    ├── certbot/              # Certificate management scripts
    └── health-check.sh       # Health monitoring
```

**Integrated Approach:**
- ✅ Issues certificates on demand
- ✅ **Automatic certificate sync** to IRC server
- ✅ **Persistent certificate storage**
- ✅ **24/7 certificate monitoring**
- ✅ **Simple setup** for development

## 📊 Ports and Services

| Port | Protocol | Purpose |
|------|----------|---------|
| 6667 | IRC | Standard IRC connection |
| 6697 | IRC+TLS | Encrypted IRC connection |
| 6900 | IRC+TLS | Server-to-server connections |
| 8600 | HTTP+TLS | JSON-RPC API for webpanel |

## 🛠️ Management Commands

```bash
# Server management
make up              # Start services
make down            # Stop services
make restart         # Restart services
make status          # Check status
make logs            # View logs

# SSL/TLS management
make setup-ssl       # Setup Let's Encrypt certificates
make ssl-renew       # Renew certificates
make ssl-check       # Check certificate status
make ssl-monitor     # Run certificate monitoring

# Environment management
make setup-env       # Setup environment files
make setup-private-env    # Setup private environment
make generate-oper-password  # Generate operator password

# Development
make build           # Build containers
make clean           # Clean up
```

## 🔑 IRC Operator Setup

1. **Generate a secure password hash:**
   ```bash
   make generate-oper-password
   ```

2. **Copy the generated hash to your `.env.local` file:**
   ```bash
   IRC_OPER_PASSWORD='$argon2id$...'
   ```

3. **Restart the server:**
   ```bash
   make restart
   ```

4. **Connect and authenticate as operator:**
   ```bash
   /OPER admin yourpassword
   ```

## 📁 Project Structure

```
irc.atl.chat/
├── compose.yaml              # Docker Compose configuration
├── unrealircd/               # UnrealIRCd configuration
│   └── conf/
│       ├── unrealircd.conf   # Main server configuration
│       └── tls/             # SSL certificates
├── scripts/                  # Management scripts
│   ├── cert-monitor.sh      # Certificate monitoring
│   ├── health-check.sh      # Health monitoring
│   ├── setup-letsencrypt.sh # SSL certificate setup
│   ├── setup-environment.sh # Environment setup
│   └── generate-oper-password.sh # Password generator
├── env.example              # Public configuration template
├── .env.local               # Private configuration (gitignored)
├── cloudflare-credentials.ini.template # Cloudflare DNS credentials
├── .runtime/               # Runtime data (certificates, logs)
└── Makefile                # Management commands
```

## 🔒 Security Best Practices

1. **Never commit sensitive data** - Use `.env.local` for passwords, keys, etc.
2. **Use strong passwords** - Generate with the provided tools
3. **Keep certificates updated** - Use Let's Encrypt automation
4. **Regular backups** - Important data is in Docker volumes
5. **Monitor logs** - Check for security issues regularly

## 🐛 Troubleshooting

### IRC Server Won't Start
```bash
# Check logs
make logs

# Check configuration
docker compose exec ircd /usr/local/unrealircd/bin/unrealircd -t
```

### SSL Issues
```bash
# Check certificates
make ssl-check

# Renew certificates
make ssl-renew

# Issue new certificate manually
make ssl-issue

# Run certificate monitoring
make ssl-monitor
```

### SSL Certificate Troubleshooting
```bash
# Check certificate files
ls -la .runtime/certs/live/irc.atl.chat/

# Check certificate expiry
openssl x509 -in .runtime/certs/live/irc.atl.chat/fullchain.pem -text | grep "Not After"

# Test SSL connection
openssl s_client -connect localhost:6697 -servername irc.atl.chat

# View certificate logs
tail -f .runtime/logs/cert-monitor.log
```

### Environment Variables Not Loading
```bash
# Check if .env.local exists
ls -la .env.local

# Check variable values
docker compose exec ircd env | grep IRC_
```

## 📚 Additional Resources

- [UnrealIRCd Documentation](https://www.unrealircd.org/docs/)
- [IRC Operator Guide](https://www.unrealircd.org/docs/IRCOp_guide)
- [SSL/TLS Configuration](https://www.unrealircd.org/docs/SSL/TLS)

## 🤝 Contributing

1. Follow security best practices
2. Test changes thoroughly
3. Update documentation
4. Never commit sensitive data

## 📄 License

This project is part of the All Things Linux initiative.