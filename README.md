# IRC.atl.chat - Complete IRC Infrastructure

A **production-ready IRC server ecosystem** with UnrealIRCd, Atheme Services, automated SSL certificates, and containerized deployment.

## Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| **IRC Server** | UnrealIRCd 6.1.10 | Core IRC daemon with modern features |
| **Services** | Atheme 7.2.12 | Nick/Channel services, authentication |
| **WebPanel** | UnrealIRCd WebPanel | Admin interface via JSON-RPC |
| **SSL/TLS** | Let's Encrypt + Cloudflare | Automated certificate management |
| **Container** | Docker + Compose | Deployment and orchestration |

### Services Integration

The setup includes **complete IRC services integration**:
- **NickServ**: Nickname registration and authentication
- **ChanServ**: Channel management and protection
- **OperServ**: Administrative services
- **Server linking**: Seamless integration between IRCd and Services

## Quick Start

### **4-Step Setup**
```bash
# 1. Copy environment template
cp env.example .env

# 2. Setup Cloudflare credentials (for SSL certificates)
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your Cloudflare API token

# 3. Edit .env with your settings (domain, passwords, etc.)
vim .env

# 4. Start everything
make build && make up
```

### What's Included
- **UnrealIRCd IRC Server** - Modern IRC daemon
- **Atheme Services** - NickServ, ChanServ, OperServ
- **WebPanel Admin Interface** - Browser-based management
- **Automated SSL certificates** - Let's Encrypt with monitoring
- **Health monitoring** - Automated service checks
- **Persistent storage** - Data survives container restarts

## Configuration

### **Environment Variables**

Copy the template and customize for your setup:

```bash
cp env.example .env
vim .env  # Edit with your settings
```

### **Required Environment Variables**

#### **Core IRC Configuration**
```bash
# Server Settings
IRC_DOMAIN=irc.atl.chat
IRC_PORT=6667
IRC_TLS_PORT=6697
IRC_RPC_PORT=8600

# Network Identity
IRC_ROOT_DOMAIN=atl.chat
IRC_NETWORK_NAME=atl.chat
IRC_CLOAK_PREFIX=atl

# Admin Contact
IRC_ADMIN_NAME="Your Admin Name"
IRC_ADMIN_EMAIL=admin@yourdomain.com
```

#### **IRC Operator Password** 🔐
```bash
# Generate secure password hash
make generate-password

# Copy the generated hash to .env
IRC_OPER_PASSWORD='$argon2id$...'    # Generated hash
```

#### **SSL/TLS Configuration**
```bash
# Let's Encrypt Email (required)
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

#### **Cloudflare DNS** (for SSL certificates)
```bash
# Create credentials file from template
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini

# Add your Cloudflare API token to the file:
dns_cloudflare_api_token = your-api-token-here
```

#### **Services Configuration**
```bash
# Atheme Services
ATHEME_SERVER_NAME=services.atl.chat
ATHEME_UPLINK_HOST=irc.atl.chat
ATHEME_UPLINK_PORT=6900
ATHEME_SEND_PASSWORD=your-services-password
ATHEME_RECEIVE_PASSWORD=your-services-password
```

## Management Commands

### **Core Commands**
```bash
# Get help
make help

# Build and start services
make build && make up

# Service management
make up          # Start all services
make down        # Stop all services
make restart     # Restart all services
make status      # Check service status

# View logs
make logs           # All service logs
make logs-ircd      # IRC server logs
make logs-atheme    # Services logs
make logs-webpanel  # WebPanel logs

# SSL management
make ssl-setup     # Complete SSL setup with monitoring
make ssl-status    # Check SSL certificate status
make ssl-renew     # Force certificate renewal (with safety checks)
make ssl-logs      # View SSL monitoring logs
make ssl-stop      # Stop SSL monitoring container
make ssl-clean     # Remove certificates and monitoring (CAUTION!)

# Maintenance
make clean         # Clean containers and images
make info          # System information
```

### **Configuration Management**
```bash
# Generate secure operator password
make generate-password

# Prepare configuration from templates
./scripts/prepare-config.sh
```

## SSL/TLS Setup

### **Automated SSL with Let's Encrypt**

The setup includes **robust SSL certificate management** with comprehensive features:

```bash
# One-command SSL setup
make ssl-setup

# Advanced troubleshooting and debugging
./scripts/ssl-manager.sh --verbose check    # Detailed status
./scripts/ssl-manager.sh --debug issue      # Maximum debugging
./scripts/ssl-manager.sh --help             # Complete help
```

### What Happens Automatically
- **Certificate Issuance**: Let's Encrypt with Cloudflare DNS challenges
- **Automatic Renewal**: Every day at 2 AM (no manual intervention)
- **Docker Monitoring**: 24/7 certificate health monitoring
- **Comprehensive Logging**: 5-level logging (INFO/WARN/ERROR/DEBUG/VERBOSE)
- **Safety Features**: Confirmation prompts for dangerous operations
- **Input Validation**: Domain and email format checking
- **Service Restart**: Automatic restart after certificate renewal

### **Prerequisites**
1. **Cloudflare Account** with DNS hosting for your domain
2. **API Token** from https://dash.cloudflare.com/profile/api-tokens
   - Create token with **Zone:DNS:Edit** permissions for your domain
3. **Domain Configuration** pointing to your server

### SSL Status & Monitoring
```bash
# Check SSL certificate status
make ssl-status

# View SSL monitoring logs
make ssl-logs

# Advanced SSL operations
make ssl-renew     # Force renewal (with safety checks)
make ssl-stop      # Stop monitoring container
make ssl-clean     # Remove certificates (CAUTION!)
```

### SSL Debugging & Troubleshooting
```bash
# Get comprehensive help
./scripts/ssl-manager.sh --help

# Verbose output for detailed information
./scripts/ssl-manager.sh --verbose check

# Maximum debugging for troubleshooting
./scripts/ssl-manager.sh --debug issue

# Manual certificate verification
openssl x509 -in unrealircd/conf/tls/server.cert.pem -noout -enddate
```

### **Security Features**
- **Argon2id password hashing** for IRC operators
- **PBKDF2v2 password hashing** for services with 64,000 iterations
- **SHA2-512 digest** for optimal cryptographic security
- **Secure server linking** with password authentication
- **U-line protection** preventing service disruption
- **Secrets management** via environment variables
- **Production-optimized Atheme build** following official documentation recommendations

## Ports and Services

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| **6667** | IRC | UnrealIRCd | Standard IRC connections |
| **6697** | IRC+TLS | UnrealIRCd | Encrypted IRC connections |
| **6900** | IRC+TLS | UnrealIRCd | Server-to-server links |
| **8080** | HTTP | WebPanel | Admin interface |

## Project Structure

```
irc.atl.chat/
├── compose.yaml              # Docker Compose configuration
├── Containerfile             # Docker build instructions
├── .env                      # Environment variables (gitignored)
├── cloudflare-credentials.ini # Cloudflare API credentials
├── scripts/                  # Management scripts
│   ├── ssl-manager.sh        # SSL management (--help, --debug, --verbose)
│   ├── prepare-config.sh     # Configuration preparation
│   └── health-check.sh       # Health monitoring
├── unrealircd/               # IRC server configuration
│   └── conf/                 # Configuration files
├── services/atheme/          # Services configuration
├── web/webpanel/             # WebPanel container
├── logs/                     # Service logs
├── data/                     # Persistent data
└── Makefile                  # Management commands
```

## Using Your IRC Server

### **Connect to IRC**
```bash
# Standard connection
irc irc.atl.chat:6667

# SSL connection (recommended)
irc irc.atl.chat:6697
```

### **Access WebPanel**
- **URL**: http://your-server:8080
- **Purpose**: Browser-based IRC server management
- **Features**: View connections, manage users, monitor server health

### **IRC Services**
Once connected, you have access to:
- **NickServ**: `/msg NickServ REGISTER password email`
- **ChanServ**: `/msg ChanServ REGISTER #channel`
- **OperServ**: Administrative services (for IRC operators)

## Troubleshooting

### **Services Not Starting**
```bash
# Check all service logs
make logs

# Check container status
make status
```

### **SSL Issues**
```bash
# Check SSL certificate status
make ssl-status

# View SSL monitoring logs
make ssl-logs

# Advanced SSL debugging
./scripts/ssl-manager.sh --verbose check    # Detailed status
./scripts/ssl-manager.sh --debug issue      # Maximum debugging

# Manual certificate verification
openssl x509 -in unrealircd/conf/tls/server.cert.pem -noout -enddate

# Check SSL monitoring container
docker compose ps ssl-monitor
```

### **Configuration Issues**
```bash
# Regenerate configuration from templates
./scripts/prepare-config.sh

# Restart services
make restart
```

## Additional Resources

- [SSL Setup Documentation](./docs/SSL.md) - Complete SSL management guide
- [UnrealIRCd Documentation](https://www.unrealircd.org/docs/)
- [Atheme Services Documentation](https://atheme.dev/docs/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## Ready to Get Started?

Your **production-ready IRC infrastructure** is now fully configured with:

- **Complete IRC ecosystem** - Server + Services + Web interface
- **SSL/TLS certificates** - Let's Encrypt with monitoring & debugging
- **Full management** - Complete set of make targets for control
- **Production security** - Argon2id password hashing, secure secrets management
- **Containerized deployment** - Easy scaling and updates
- **Troubleshooting tools** - Debug/verbose modes, comprehensive logging

**Start your IRC network:**
```bash
make build && make up
```

**Access your services:**
- **IRC Server**: `irc.atl.chat:6667` (standard) or `:6697` (SSL)
- **WebPanel**: `http://your-server:8080`
- **Services**: Available once connected to IRC
