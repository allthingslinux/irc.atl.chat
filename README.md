# IRC Infrastructure

A production-ready Docker-based IRC infrastructure featuring UnrealIRCd, Atheme services, and a web-based administration panel.

[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)]()

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/allthingslinux/irc.atl.chat.git
cd irc.atl.chat

# Start everything with one command
make quick-start

# Access the web panel
open http://localhost:8080
```

## ✨ Features

- **UnrealIRCd 6.1.10** - Modern IRC server with advanced features
- **Atheme 7.2.12** - Professional IRC services (NickServ, ChanServ, etc.)
- **Web Administration Panel** - PHP-based web interface for server management
- **Module Management** - Easy contrib module installation and configuration
- **Docker Native** - Containerized deployment with health checks
- **Production Ready** - Optimized builds, security hardening, and monitoring

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌───────────────┐
│   UnrealIRCd    │    │   Atheme        │    │  WebPanel     │
│   Port: 6667    │◄──►│   Port: 7000    │    │  Port: 8080   │
│   (SSL: 6697)   │    │                 │    │               │
└─────────────────┘    └─────────────────┘    └───────────────┘
         └───────────────────────┼──────────────────────┘
                        ┌─────────────────┐
                        │   JSON-RPC API  │
                        │   Port: 8600    │
                        └─────────────────┘
```

## 📋 Prerequisites

- **Docker** 20.10+ and **Docker Compose** 2.0+
- **Make** (optional, for convenience commands)
- **4GB RAM** minimum, **8GB+** recommended
- **Linux/macOS/Windows** with Docker support

## 🛠️ Installation

### Option 1: Using Make (Recommended)

```bash
# Show all available commands
make help

# Quick start (build and run everything)
make quick-start

# Individual operations
make build          # Build all services
make up             # Start services
make status         # Check status
make down           # Stop services
```

### Option 2: Using Docker Compose Directly

```bash
# Build and start
docker compose up -d --build

# View logs
docker compose logs -f

# Stop services
docker compose down
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TZ` | `UTC` | Timezone for all services |
| `UNREALIRCD_HOST` | `ircd` | Internal hostname for UnrealIRCd |
| `UNREALIRCD_PORT` | `8600` | JSON-RPC API port |

### Ports

| Service | Port | Description |
|---------|------|-------------|
| UnrealIRCd | 6667 | Standard IRC connection |
| UnrealIRCd | 6697 | SSL IRC connection |
| WebPanel | 8080 | Web administration interface |
| JSON-RPC | 8600 | Internal API (container only) |

### Volumes

- `ircd_data` - UnrealIRCd data and logs
- `ircd_modules` - Custom modules
- `atheme_data` - Atheme services data
- `webpanel_data` - WebPanel configuration and data

## 📚 Usage

### Basic Operations

```bash
# Start services
make up

# Check status
make status

# View logs
make logs

# Stop services
make down
```

### Module Management

```bash
# List available modules
make modules-list

# Install a module
make modules install MODULE=webpanel

# Remove a module
make modules remove MODULE=webpanel

# Update contrib repository
make modules update
```

### WebPanel Access

```bash
# Show access information
make webpanel

# Access container shell
make webpanel-shell

# View webpanel logs
make webpanel-logs
```

### Development

```bash
# Access IRC container shell
make dev-shell

# Run linting checks
make lint

# Run validation tests
make test
```

## 🔒 Security

- **Non-root containers** for all services
- **Network isolation** with custom Docker networks
- **Health checks** for service monitoring
- **Secure defaults** with minimal attack surface
- **Environment-based configuration** for secrets

## 📊 Monitoring

### Health Checks

All services include health checks that monitor:
- Service availability
- Port accessibility
- Internal service health
- Resource usage

### Logs

```bash
# All services
make logs

# Specific service
make logs-ircd
make logs-atheme
make logs-webpanel
```

## 🚨 Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check Docker status
docker info

# Verify configuration
make test

# View detailed logs
make logs
```

**WebPanel not accessible:**
```bash
# Check service status
make status

# Verify port binding
docker compose ps

# Check webpanel logs
make webpanel-logs
```

**Module installation fails:**
```bash
# Verify contrib repository
make modules update

# Check module availability
make modules list

# Verify configuration
make test
```

### Debug Mode

```bash
# Enable debug logging
docker compose up -d --build --force-recreate

# Follow logs in real-time
make logs
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Install development dependencies
make install-dev

# Run quality checks
make quality

# Run full test suite
make test
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [UnrealIRCd](https://www.unrealircd.org/) - Modern IRC server
- [Atheme](https://atheme.github.io/) - IRC services suite
- [UnrealIRCd WebPanel](https://github.com/unrealircd/unrealircd-webpanel) - Web administration interface

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/allthingslinux/irc.atl.chat/issues)
- **Discussions**: [GitHub Discussions](https://github.com/allthingslinux/irc.atl.chat/discussions)
- **Documentation**: [Wiki](https://github.com/allthingslinux/irc.atl.chat/wiki)

---