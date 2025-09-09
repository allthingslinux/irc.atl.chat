# IRC.atl.chat - Complete IRC Infrastructure

A **production-ready IRC server ecosystem** featuring UnrealIRCd with Atheme Services, modern security, SSL/TLS support, and comprehensive containerization.

## 🏗️ **Core Components**

| Component | Technology | Purpose |
|-----------|------------|---------|
| **IRC Server** | UnrealIRCd 6.1.10 | Core IRC daemon with modern features |
| **Services** | Atheme 7.2.12 | Nick/Channel services, authentication |
| **SSL/TLS** | Let's Encrypt + Cloudflare | Automated certificate management |
| **Container** | Docker + Compose | Deployment and orchestration |
| **Web Interface** | TheLounge + Gamja | Modern web-based IRC clients |

### 🔄 **Services Integration**

The setup includes **full IRC services integration**:
- **NickServ**: Nickname registration and authentication
- **ChanServ**: Channel management and protection
- **OperServ**: Administrative services
- **HostServ**: vHost management
- **Server linking**: Seamless integration between IRCd and Services

## 🚀 **Quick Start**

### **One-Command Setup**
```bash
# Complete production-ready setup
make setup

# Start the full IRC ecosystem
make up

# Check everything is working
make status
```

### **What's Included**
✅ **UnrealIRCd IRC Server** - Modern IRC daemon
✅ **Atheme Services** - NickServ, ChanServ, OperServ
✅ **SSL/TLS Certificates** - Let's Encrypt automation
✅ **Web IRC Clients** - TheLounge + Gamja
✅ **Health Monitoring** - Automated checks
✅ **Persistent Storage** - Data survives restarts
✅ **Security Hardening** - Production-ready configuration

## ⚙️ **Configuration**

### **Environment Variables**

The setup uses **secure environment variable management** with separation of public and private configuration:

#### **Public Configuration** (`.env.example`)
Non-sensitive settings that can be committed to version control.

#### **Private Configuration** (`.env.local`) 🔐
**Sensitive data that MUST NEVER be committed**. This file contains:
- IRC operator passwords
- SSL certificate credentials
- Database credentials
- API keys

### **Automated Setup**

```bash
# 1. Setup all environment files
make setup-env

# 2. Generate secure operator password
make generate-oper-password

# 3. Configure SSL certificates
make setup-ssl

# 4. Start everything
make up
```

### **Key Environment Variables**

#### **Core IRC Configuration**
```bash
# Server Identity
IRC_DOMAIN=irc.atl.chat              # Your IRC domain
IRC_NETWORK_NAME=atl.chat            # Network name
IRC_CLOAK_PREFIX=atl                # Hostname cloaking prefix

# Administrative
IRC_ADMIN_NAME="All Things Linux Admin"
IRC_ADMIN_EMAIL=admin@atl.chat
```

#### **IRC Operator Credentials** 🔐 **(PRIVATE - Never Commit!)**
```bash
# Generate with: make generate-oper-password
IRC_OPER_PASSWORD='$argon2id$...'    # Argon2id hashed password
```

#### **SSL/TLS Configuration**
```bash
# Let's Encrypt
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Cloudflare DNS (for certificate challenges)
CLOUDFLARE_EMAIL=your-email@domain.com
CLOUDFLARE_API_KEY=your-api-token
```

#### **Services Configuration**
```bash
# Atheme Services
ATHEME_ADMIN_NAME="All Things Linux IRC Admin"
ATHEME_ADMIN_EMAIL=admin@atl.chat
ATHEME_REGISTER_EMAIL=noreply@atl.chat
```

### **Network Architecture**

#### **Server Linking vs U-lines**
The setup implements **both server linking AND U-lines** for complete services integration:

**🔗 Server Links** establish the network connection:
```irc
link services.atl.chat {
    incoming { mask *; }
    password "mypassword";
    class servers;
}
```

**🛡️ U-lines** give services special privileges:
```irc
ulines {
    services.atl.chat;
}
```

**Why Both?**
- **Server Links**: Enable network communication between IRCd and Services
- **U-lines**: Allow services to perform privileged operations (kill protection, enhanced modes)

#### **Services Architecture**
```
IRC Clients ↔ UnrealIRCd (irc.atl.chat) ↔ Atheme Services (services.atl.chat)
     │                │                           │
     └────────────────┼───────────────────────────┘
                      │
            Server-to-Server Link
            (Port 6667, plaintext)
```

**Connection Details:**
- **Protocol**: UnrealIRCd 4.x (compatible with Atheme)
- **Link Security**: Plaintext (Atheme doesn't support TLS for server links)
- **Authentication**: Password-based server authentication
- **Auto-recovery**: Services automatically reconnect if disconnected

## 🔐 **Security Features**

### External Sensitive Data
- IRC operator passwords stored in `.env.local` (not committed)
- SSL certificates managed externally
- Database credentials (if used) stored securely

### **SSL/TLS Certificate Management**
- **Let's Encrypt automation** with Cloudflare DNS challenges
- **Modern TLS 1.2/1.3** protocols with strong cipher suites
- **Automatic renewal** every 30 days
- **SNI support** for multiple domains
- **Certificate persistence** across container restarts

### **Container Security**
- **Non-root execution** with proper user permissions
- **Resource limits** and health monitoring
- **Minimal attack surface** with Alpine Linux base
- **Secrets management** via environment variables
- **Network isolation** with Docker networks

### **Services Security**
- **PBKDF2v2 password hashing** with 64,000 iterations
- **SHA2-512 digest** for optimal security
- **Secure server linking** with password authentication
- **U-line protection** preventing service disruption

## 🔑 **SSL Certificate Management (Simplified)**

The setup includes **simplified SSL/TLS certificate management**:

### **Quick Setup**
```bash
# 1. Configure Cloudflare API token
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
# Edit cloudflare-credentials.ini and add your API token
chmod 600 cloudflare-credentials.ini

# 2. Set environment variables
LETSENCRYPT_EMAIL=admin@yourdomain.com
IRC_DOMAIN=irc.yourdomain.com

# 3. Issue certificates automatically
make ssl-setup

# 4. Everything is ready!
make up
```

### **What Happens Automatically**
✅ **Certificate Issuance**: Let's Encrypt with Cloudflare DNS challenges
✅ **Direct Integration**: Certificates copied directly to UnrealIRCd
✅ **IRC Server Reload**: Configuration reloads automatically after renewal
✅ **Simple Management**: Single script handles all SSL operations

### **Manual Certificate Management**
```bash
# Check certificate status
make ssl-status

# Force renewal
make ssl-renew

# Direct script usage
./scripts/ssl-manager.sh status
./scripts/ssl-manager.sh renew
```

### 🔧 **Available Commands**

```bash
make ssl-setup              # Setup certificates (one-time)
make ssl-renew              # Renew certificates
make ssl-status             # Check certificate status
```

### 📋 **Prerequisites**

1. **Cloudflare Account** with DNS hosting for your domain
2. **API Token** from https://dash.cloudflare.com/profile/api-tokens
   - Create a token with **Zone:DNS:Edit** permissions for your domain
   - Copy the token and paste it into `cloudflare-credentials.ini`
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

## 📊 **Ports and Services**

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| **6667** | IRC | UnrealIRCd | Standard IRC connection |
| **6697** | IRC+TLS | UnrealIRCd | Encrypted IRC connection |
| **6900** | IRC+TLS | UnrealIRCd | Server-to-server connections |
| **8600** | HTTP+TLS | UnrealIRCd | JSON-RPC API for webpanel |
| **9000** | HTTP | TheLounge | Modern web IRC client |
| **9001** | HTTP | Gamja | Lightweight web IRC client |

### **Web IRC Clients**
- **TheLounge**: Feature-rich web client with persistent connections
- **Gamja**: Minimal, fast web client perfect for quick connections

## 🛠️ **Management Commands**

### **Core Server Management**
```bash
# Start the complete IRC ecosystem
make up

# Stop all services
make down

# Restart services
make restart

# Check status of all containers
make status

# View logs from all services
make logs
```

### **SSL/TLS Certificate Management**
```bash
# Initial SSL setup
make setup-ssl

# Certificate operations
make ssl-renew       # Force renewal
make ssl-check       # Check status
make ssl-monitor     # Monitor certificates
```

### **Environment & Security Setup**
```bash
# Complete environment setup
make setup-env

# Generate secure operator password
make generate-oper-password

# Build custom containers
make build

# Clean up containers and volumes
make clean
```

### **Services-Specific Commands**
```bash
# Check services linkage
make logs | grep -E "(services.atl.chat|Server linked)"

# Monitor Atheme services
docker compose logs atheme --tail=10

# Test services connectivity
docker compose exec atheme /usr/local/atheme/bin/atheme-services -c /usr/local/atheme/etc/atheme.conf -n
```

## 👑 **IRC Operator Setup**

### **Automated Operator Setup**
```bash
# 1. Generate secure operator password
make generate-oper-password

# 2. The hash is automatically added to .env.local
# 3. Restart to apply changes
make restart
```

### **Manual Operator Authentication**
```irc
# Connect to your IRC server
/OPER admin yourpassword

# Verify operator status
/WHOIS admin
```

### **Operator Commands**
```irc
# Server statistics
/STATS u          # Uptime and connection info
/STATS o          # Online operators
/STATS l          # Server links

# User management
/KILL nickname   # Disconnect user (use carefully)
/KLINE user@host  # Ban user by hostmask

# Channel management
/JOIN #opers     # Join operator channels
/MODE #channel +o nickname  # Give operator status
```

## 🎮 **Using IRC Services**

Once connected, you have access to **comprehensive IRC services**:

### **NickServ - Nickname Management**
```irc
# Register your nickname
/msg NickServ REGISTER yourpassword youremail@example.com

# Identify with your nickname
/msg NickServ IDENTIFY yourpassword

# Change password
/msg NickServ SET PASSWORD newpassword

# Set email address
/msg NickServ SET EMAIL newemail@example.com

# Enable auto-identification
/msg NickServ SET AUTOIDENTIFY ON

# View your info
/msg NickServ INFO
```

### **ChanServ - Channel Management**
```irc
# Register a channel
/msg ChanServ REGISTER #yourchannel

# Set channel topic (as founder)
/msg ChanServ TOPIC #yourchannel Welcome to our channel!

# Add channel operators
/msg ChanServ AOP #yourchannel ADD nickname

# Set channel modes that persist
/msg ChanServ SET #yourchannel MLOCK +nt

# Transfer ownership
/msg ChanServ SET #yourchannel FOUNDER newowner

# View channel info
/msg ChanServ INFO #yourchannel
```

### **OperServ - Administrative Services**
```irc
# View network statistics
/msg OperServ STATS

# Clear user modes globally
/msg OperServ CLEARMODES nickname

# View operator list
/msg OperServ OPERLIST
```

### **HostServ - Custom Hostnames**
```irc
# Request a vHost
/msg HostServ REQUEST your.custom.hostname

# Activate vHost
/msg HostServ ACTIVATE

# View available vHosts
/msg HostServ LIST
```

## 📁 **Project Structure**

```
irc.atl.chat/
├── 📄 compose.yaml              # 🎯 Main Docker Compose (all services)
├── 🐳 Containerfile             # Docker build instructions
├── ⚙️ unrealircd/               # UnrealIRCd IRC server
│   └── conf/
│       ├── unrealircd.conf     # Main server configuration
│       └── tls/               # SSL certificates
├── 🎭 services/atheme/         # Atheme Services configuration
│   └── atheme.conf            # Services configuration
├── 📜 scripts/                 # Management scripts
│   ├── certbot/               # Certificate management
│   ├── generate-oper-password.sh # Password generator
│   └── health-check.sh        # Health monitoring
├── 🔧 Makefile                # Management commands
├── 📝 .env.local              # 🔑 Private environment (gitignored)
├── 🔐 cloudflare-credentials.ini # Cloudflare DNS credentials
├── 📊 README.md               # This documentation
└── 📁 .runtime/               # Runtime data
    ├── certs/                # SSL certificates
    └── logs/                 # Monitoring logs
```

### **Service Architecture**
```
Docker Compose
├── UnrealIRCd (irc.atl.chat:6667/6697)
│   ├── IRC Server with SSL/TLS
│   ├── WebPanel API (port 8600)
│   └── Server-to-server links (port 6900)
├── Atheme Services (services.atl.chat)
│   ├── NickServ, ChanServ, OperServ
│   ├── Linked to UnrealIRCd
│   └── PBKDF2v2 password hashing
├── TheLounge (port 9000)
│   └── Modern web IRC client
├── Gamja (port 9001)
│   └── Lightweight web IRC client
└── SSL Certificate Manager
    └── Let's Encrypt automation
```

## 🔒 **Security Features**

### **Multi-Layer Security**
- ✅ **Argon2id password hashing** for IRC operators
- ✅ **PBKDF2v2 password hashing** for services (64,000 iterations)
- ✅ **SHA2-512 digest** for optimal cryptographic security
- ✅ **Let's Encrypt SSL/TLS** with automatic renewal
- ✅ **Secure server linking** with password authentication
- ✅ **U-line protection** preventing service disruption

### **Best Practices**
1. **🔐 Never commit sensitive data** - Use `.env.local` for all secrets
2. **🔑 Use generated passwords** - Always use `make generate-oper-password`
3. **🔒 Keep certificates updated** - Automatic renewal every 30 days
4. **💾 Regular backups** - Services database contains user registrations
5. **📊 Monitor logs** - Check for security issues and failed login attempts
6. **🚫 Limit operator access** - Only grant IRCop to trusted administrators

## 🐛 **Troubleshooting**

### **General Issues**

#### **Services Won't Start**
```bash
# Check all service logs
make logs

# Check container status
make status

# Restart all services
make restart
```

#### **Environment Variables Issues**
```bash
# Check if .env.local exists and has content
ls -la .env.local
cat .env.local

# Validate environment loading
docker compose exec unrealircd env | grep -E "(IRC_|ATHEME_)"
```

### **IRC Server Issues**

#### **IRC Server Won't Start**
```bash
# Check UnrealIRCd configuration syntax
docker compose exec unrealircd /usr/local/unrealircd/bin/unrealircd -t

# Check for port conflicts
netstat -tlnp | grep -E "(6667|6697|6900|8600)"
```

#### **Cannot Connect to IRC Server**
```bash
# Test basic connectivity
telnet localhost 6667
# Should see: :irc.atl.chat NOTICE * :*** Looking up your hostname...

# Test SSL connection
openssl s_client -connect localhost:6697 -servername irc.atl.chat
```

### **Services Integration Issues**

#### **Services Not Working (NickServ/ChanServ)**
```bash
# Check services linkage
make logs | grep -E "(services.atl.chat|Server linked)"

# Check Atheme logs
docker compose logs atheme --tail=20

# Test services connectivity
docker compose exec atheme /usr/local/atheme/bin/atheme-services -c /usr/local/atheme/etc/atheme.conf -n
```

#### **"No protocol module loaded" Error**
```bash
# Check if modules are properly installed
docker compose exec atheme find /usr/local/atheme/modules -name "*unreal*"

# Verify modulepath in configuration
docker compose exec atheme grep "modulepath" /usr/local/atheme/etc/atheme.conf
```

#### **Services Database Issues**
```bash
# Check database file
docker compose exec atheme ls -la /usr/local/atheme/etc/services.db

# Reset services database (CAUTION: loses all registrations)
docker compose exec atheme rm /usr/local/atheme/etc/services.db
docker compose restart atheme
```

### **SSL/TLS Certificate Issues**

#### **SSL Certificate Problems**
```bash
# Check certificate status
make ssl-check

# View certificate details
openssl x509 -in .runtime/certs/live/irc.atl.chat/fullchain.pem -text

# Test SSL handshake
openssl s_client -connect localhost:6697 -servername irc.atl.chat
```

#### **Certificate Renewal Issues**
```bash
# Force renewal
make ssl-renew

# Check renewal logs
tail -f .runtime/logs/cert-monitor.log

# Manual certificate issuance
make ssl-issue
```

#### **Cloudflare DNS Issues**
```bash
# Check Cloudflare credentials
cat cloudflare-credentials.ini

# Test DNS challenge
make ssl-issue  # Watch for DNS propagation errors
```

### **Web Client Issues**

#### **TheLounge/Gamja Not Loading**
```bash
# Check web client logs
docker compose logs thelounge
docker compose logs gamja

# Test web interface
curl -I http://localhost:9000
curl -I http://localhost:9001
```

### **Performance Issues**

#### **High CPU/Memory Usage**
```bash
# Check resource usage
docker stats

# Monitor specific containers
docker compose logs --tail=50 | grep -i "error\|warning"
```

#### **Slow Services Response**
```bash
# Check services database size
docker compose exec atheme ls -lh /usr/local/atheme/etc/services.db

# Monitor services performance
docker compose logs atheme --tail=20
```

### **Common Error Messages**

| Error Message | Likely Cause | Solution |
|---------------|--------------|----------|
| `Server linked: denied` | Wrong password in link config | Check passwords in `unrealircd.conf` and `atheme.conf` |
| `No protocol module loaded` | Module path issues | Check `modulepath` in `atheme.conf` |
| `Bad ulines` | U-lines mismatch | Ensure `services.atl.chat` in ulines block |
| `SSL certificate verify failed` | Certificate issues | Run `make ssl-renew` |
| `Connection refused` | Port/firewall issues | Check `docker compose ps` and firewall rules |

## 📚 **Additional Resources**

### **Official Documentation**
- [UnrealIRCd Documentation](https://www.unrealircd.org/docs/) - IRC server configuration
- [Atheme Services Documentation](https://atheme.dev/docs/) - Services configuration
- [Docker Compose Documentation](https://docs.docker.com/compose/) - Container orchestration

### **IRC Resources**
- [IRC Operator Guide](https://www.unrealircd.org/docs/IRCOp_guide) - Server administration
- [RFC 2812](https://tools.ietf.org/html/rfc2812) - IRC protocol specification
- [IRCv3 Specifications](https://ircv3.net/irc/) - Modern IRC extensions

### **Security & SSL**
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/) - Certificate management
- [Cloudflare DNS API](https://developers.cloudflare.com/api/) - DNS automation
- [OWASP SSL/TLS Guidelines](https://owasp.org/www-project-cheat-sheets/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html)

## 🎯 **Quick Reference**

### **Essential Commands**
```bash
# Complete setup
make setup && make up

# Monitor services
make status && make logs

# SSL management
make ssl-check && make ssl-renew

# Services testing
docker compose logs atheme --tail=10
```

### **Ports Summary**
| Service | Port | Protocol | Purpose |
|---------|------|----------|---------|
| **IRC Server** | 6667 | IRC | Standard connections |
| **IRC SSL** | 6697 | IRC+TLS | Encrypted connections |
| **Services Link** | 6900 | IRC+TLS | Server-to-server |
| **WebPanel** | 8600 | HTTP+TLS | Admin interface |
| **TheLounge** | 9000 | HTTP | Web IRC client |
| **Gamja** | 9001 | HTTP | Web IRC client |

## 🤝 **Contributing**

### **Development Guidelines**
1. 🔐 **Follow security best practices** - Never commit sensitive data
2. 🧪 **Test changes thoroughly** - Use `make status` and `make logs`
3. 📝 **Update documentation** - Keep README current with changes
4. 🐳 **Container best practices** - Minimal images, proper user permissions
5. 🔄 **Version control** - Use conventional commits and proper branching

### **Reporting Issues**
- Check existing issues before creating new ones
- Include relevant logs and configuration
- Specify your environment (OS, Docker version, etc.)
- Use issue templates when available

## 📄 **License & Attribution**

**License:** This project is part of the **All Things Linux** initiative.

**Credits:**
- **UnrealIRCd** - Professional IRC server software
- **Atheme Services** - Comprehensive IRC services package
- **Let's Encrypt** - Free SSL certificate authority
- **Docker** - Containerization platform
- **TheLounge & Gamja** - Modern web IRC clients

---

## 🚀 **Ready to Get Started?**

Your **production-ready IRC infrastructure** is now fully configured with:

✅ **Complete IRC ecosystem** - Server + Services + Web clients
✅ **Enterprise-grade security** - SSL/TLS + strong password hashing
✅ **Automated certificate management** - 30-day renewal cycle
✅ **Containerized deployment** - Easy scaling and management
✅ **Comprehensive documentation** - Everything you need to know

**Start your IRC network:**
```bash
make setup && make up
```

**Join the community:**
- Connect to `irc.atl.chat:6667` or `irc.atl.chat:6697` (SSL)
- Use `/msg NickServ HELP` for nickname registration
- Access web clients at `http://your-server:9000` (TheLounge) or `:9001` (Gamja)

**Happy IRCing! 🎉**