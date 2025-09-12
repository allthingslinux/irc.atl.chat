# IRC.atl.chat

Docker-based IRC server with UnrealIRCd, Atheme Services, and automated SSL certificate management.

## Architecture

| Component | Technology | Purpose |
|-----------|------------|---------|
| IRC Server | UnrealIRCd 6.2.0.1 | IRC daemon |
| Services | Atheme 7.2.12 | NickServ, ChanServ, OperServ |
| WebPanel | UnrealIRCd WebPanel | Admin interface |
| SSL/TLS | Let's Encrypt + Cloudflare | Certificate management |
| Container | Docker + Compose | Deployment |

## Quick Start

```bash
# 1. Clone and configure
git clone https://github.com/allthingslinux/irc.atl.chat
cd irc.atl.chat
cp env.example .env

# 2. Edit configuration
vim .env

# 3. Setup Cloudflare DNS credentials
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
chmod 600 cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your Cloudflare API token

# 4. Setup SSL certificates (required before starting)
make ssl-setup

# 5. Start services
make up
```

**Note**: SSL setup must be completed before starting services, as UnrealIRCd configuration expects SSL certificates to exist.

## Shell Script Formatting

This project uses bash scripts with bash-specific features (arrays, `[[` builtin, etc.). The scripts are correctly formatted for bash but may show formatting errors in CI that uses POSIX shell parsing. To format the scripts locally:

```bash
# Format all shell scripts (without POSIX flag)
shfmt -i 2 -ci -bn -sr -kp -w -s scripts/*.sh src/backend/*/scripts/*.sh
```

## Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

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

## Configuration Workflow

Configuration files are automatically generated from templates using your `.env` file:

- **Templates**: `src/backend/*/conf/*.template` files
- **Generated**: `src/backend/*/conf/*.conf` files (gitignored)
- **Process**: `envsubst` substitutes variables from `.env` into templates
- **Automation**: `make up` runs `init.sh` and `prepare-config.sh` automatically

**Never edit the `.conf` files directly** - they will be overwritten. Always modify the `.env` file and run `make up` to regenerate.

## Commands

### Service Management
```bash
make up             # Start all services
make down           # Stop all services
make restart        # Restart services
make status         # Check service status
make logs           # View all logs
```

### Development
```bash
make build          # Build containers
make rebuild        # Rebuild from scratch
make test           # Run test suite
make lint           # Run linting
```

### SSL Management
```bash
make ssl-setup      # Setup SSL certificates
make ssl-status     # Check certificate status
make ssl-renew      # Force renewal
make ssl-logs       # View SSL logs
```

### Utilities
```bash
make generate-password    # Generate IRC operator password
make modules-list         # List available modules
make modules-installed    # Show installed modules
```

## Project Structure

```
irc.atl.chat/
├── src/
│   ├── backend/
│   │   ├── unrealircd/          # IRC server
│   │   └── atheme/              # IRC services
│   └── frontend/
│       ├── webpanel/            # Admin interface
│       └── gamja/               # Web client (optional)
├── scripts/                     # Management scripts
├── docs/                        # Documentation
├── data/                        # Persistent data
├── logs/                        # Service logs
└── tests/                       # Test suite
```

## Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 6667 | IRC | UnrealIRCd | Standard IRC |
| 6697 | IRC+TLS | UnrealIRCd | Encrypted IRC |
| 6900 | IRC+TLS | UnrealIRCd | Server links |
| 8600 | HTTP | UnrealIRCd | JSON-RPC API |
| 8000 | WebSocket | UnrealIRCd | WebSocket IRC |
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

- URL: `http://your-server:8080`
- Purpose: IRC server management

### IRC Services

- **NickServ**: `/msg NickServ REGISTER password email`
- **ChanServ**: `/msg ChanServ REGISTER #channel`
- **OperServ**: Administrative services

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
```

### Configuration Issues
```bash
make restart
# Check if configuration was generated properly
ls -la src/backend/unrealircd/conf/unrealircd.conf
ls -la src/backend/atheme/conf/atheme.conf

# If configs are missing, regenerate from templates
make build
```

## Development

### Running Tests
```bash
make test
```

### Linting
```bash
make lint
```

### Building
```bash
make build
```

## Documentation

- [SSL Setup](./docs/SSL.md)
- [Secret Management](./docs/SECRET_MANAGEMENT.md)
- [User Modes](./docs/user-modes.md)

## License

MIT License - see [LICENSE](LICENSE) for details.
