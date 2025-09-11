# IRC.atl.chat

IRC server with UnrealIRCd, Atheme Services, and SSL certificates.

## Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| IRC Server | UnrealIRCd 6.1.10 | IRC daemon |
| Services | Atheme 7.2.12 | NickServ, ChanServ, OperServ |
| WebPanel | UnrealIRCd WebPanel | Admin interface |
| SSL/TLS | Let's Encrypt + Cloudflare | Certificate management |
| Container | Docker + Compose | Deployment |

## Setup

```bash
# 1. Copy environment template
cp env.example .env

# 2. Setup Cloudflare credentials
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your Cloudflare API token

# 3. Edit .env with your settings
vim .env

# 4. Start services
make up
```

## Commands

```bash
make up             # Start all services
make down           # Stop all services
make logs           # View logs
make status         # Check service status
make build          # Build containers
make rebuild        # Rebuild containers
make restart        # Restart services
make reset          # Complete reset
make help           # Show all commands
```

## Configuration

Copy the template and edit:
```bash
cp env.example .env
vim .env
```

### Required Variables

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

# SSL/TLS
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Services
ATHEME_SERVER_NAME=services.atl.chat
ATHEME_UPLINK_HOST=irc.atl.chat
ATHEME_UPLINK_PORT=6900
ATHEME_SEND_PASSWORD=your-services-password
ATHEME_RECEIVE_PASSWORD=your-services-password
```

### Password Generation

```bash
# Generate IRC operator password hash
make generate-password

# Copy the generated hash to .env
IRC_OPER_PASSWORD='$argon2id$...'
```

### Cloudflare DNS

```bash
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your API token
```

## SSL Management

```bash
make ssl-setup     # Setup SSL certificates
make ssl-status    # Check certificate status
make ssl-renew     # Force certificate renewal
make ssl-logs      # View SSL logs
make ssl-stop      # Stop SSL monitoring
make ssl-clean     # Remove certificates
```

## Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 6667 | IRC | UnrealIRCd | Standard IRC |
| 6697 | IRC+TLS | UnrealIRCd | Encrypted IRC |
| 6900 | IRC+TLS | UnrealIRCd | Server links |
| 8080 | HTTP | WebPanel | Admin interface |

## Usage

### Connect to IRC
```bash
# Standard connection
irc irc.atl.chat:6667

# SSL connection
irc irc.atl.chat:6697
```

### WebPanel
- URL: http://your-server:8080
- Purpose: IRC server management

### IRC Services
- NickServ: `/msg NickServ REGISTER password email`
- ChanServ: `/msg ChanServ REGISTER #channel`
- OperServ: Administrative services

## Troubleshooting

### Services Not Starting
```bash
make logs
make status
```

### SSL Issues
```bash
make ssl-status
make ssl-logs
./scripts/ssl-manager.sh --help
```

### Configuration Issues
```bash
make restart
ls -la unrealircd/conf/unrealircd.conf
ls -la services/atheme/atheme.conf
```

## Documentation

- [SSL Setup](./docs/SSL.md)
- [UnrealIRCd Documentation](https://www.unrealircd.org/docs/)
- [Atheme Services Documentation](https://atheme.dev/docs/)
