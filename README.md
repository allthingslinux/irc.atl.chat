# IRC Services Docker Setup

This repository contains an optimized Docker setup for running UnrealIRCd and Atheme services.

## Docker Optimizations Implemented

### 1. Multi-Stage Build
- **Base stage**: Contains all system dependencies with pinned versions
- **Builder stage**: Compiles UnrealIRCd and Atheme from source with optimizations
- **Runtime stage**: Minimal production image with only compiled binaries

### 2. Layer Caching Improvements
- Dependencies installed in a single RUN command
- Build arguments properly structured for better cache invalidation
- Source downloads separated from compilation steps

### 3. Security Enhancements
- Non-root user for both building and runtime
- Proper file permissions and ownership
- Minimal attack surface in final image

### 4. Build Efficiency
- Parallel compilation with `make -j"$(nproc)"`
- Source archives removed after extraction
- Comprehensive `.dockerignore` file
- Compiler optimizations with `-O2 -march=native -mtune=native`
- Security flags with `-fstack-protector-strong` and `-Wl,-z,relro,-z,now`

### 5. Runtime Optimizations
- Health checks for both UnrealIRCd and Atheme services
- Proper volume mounts for persistence
- Network isolation with custom bridge network
- Optimized Atheme configuration with sanitizers and large network support
- Symlinks for easier service access

## Project Overview

This project provides a complete, production-ready IRC infrastructure with:

### **Core Services**
- **UnrealIRCd 6.1.10**: Modern IRC server with contrib modules support
- **Atheme 7.2.12**: IRC services (NickServ, ChanServ, OperServ, etc.)
- **WebPanel**: Web-based administration interface
- **KiwiIRC**: Web-based IRC client

### **Advanced Features**
- **Module Management**: Easy installation of contrib modules
- **JSON-RPC API**: Programmatic access to UnrealIRCd
- **Health Monitoring**: Comprehensive service health checks
- **Security Hardening**: Non-root users, proper permissions, security flags

### **Architecture**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │────│   WebPanel      │────│   UnrealIRCd    │
│   Port 8080     │    │  (PHP/Apache)   │    │   Port 8600     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │    Atheme       │
                       │   Services      │
                       └─────────────────┘
```

## Quick Start

### Build the Image
```bash
# Build with default settings
./scripts/build.sh

# Build specific versions
./scripts/build.sh -u 6.1.11 -a 7.2.13

# Build only the builder stage for development
./scripts/build.sh -t builder
```

### Run with Docker Compose
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Access Services
- **IRC Server**: Connect to `localhost:6667` or `localhost:6697` (SSL)
- **WebPanel**: Open http://localhost:8080 in your browser
- **Module Manager**: Use `docker-compose exec ircd manage-modules list`

### Manual Service Management
```bash
# Start services manually
docker exec ircd /usr/local/bin/start-services start

# Check service status
docker exec ircd /usr/local/bin/start-services status

# Restart services
docker exec ircd /usr/local/bin/start-services restart

# Stop services
docker exec ircd /usr/local/bin/start-services stop
```

### Configuration Files
- **UnrealIRCd**: `./unrealircd/conf/unrealircd.conf`
- **Atheme**: `./services/atheme/atheme.conf`
- **Startup Script**: `./scripts/start-services.sh`
- **Module Management**: `./scripts/manage-modules.sh`
- **Module Configuration**: `./scripts/module-config.sh`
- **WebPanel**: `./web/webpanel/config.php`

### Directory Structure
```
web/
├── kiwiirc/          # KiwiIRC web client
└── webpanel/         # UnrealIRCd administration panel
    ├── Dockerfile    # WebPanel container build
    └── config.php    # WebPanel configuration
```

## Configuration

### Environment Variables
- `UNREALIRCD_VERSION`: UnrealIRCd version to build (default: 6.1.10)
- `ATHEME_VERSION`: Atheme version to build (default: 7.2.12)
- `BUILD_TARGET`: Build target stage (base, builder, or runtime)

### Ports
- `6667`: Standard IRC port
- `6697`: IRC over SSL/TLS
- `8080`: WebPanel administration interface
- `8600`: JSON-RPC API (internal)

### Volumes
- `ircd_data`: UnrealIRCd data persistence
- `ircd_logs`: UnrealIRCd log files
- `ircd_modules`: Contrib modules storage
- `ircd_contrib`: Contrib modules source
- `atheme_data`: Atheme data persistence
- `atheme_logs`: Atheme log files
- `webpanel_data`: WebPanel data persistence
- `webpanel_config`: WebPanel configuration

## Build Script Usage

The `scripts/build.sh` script provides a convenient way to build Docker images with various options:

```bash
# Show help
./scripts/build.sh --help

# Build and push to registry
./scripts/build.sh -p

# Custom image naming
./scripts/build.sh -n my-irc-image -g v1.0.0
```

## Development

### Building Specific Stages
```bash
# Build only base dependencies
./scripts/build.sh -t base

# Build up to builder stage (includes compilation)
./scripts/build.sh -t builder

# Build complete runtime image (default)
./scripts/build.sh -t runtime
```

### Debugging Builds
```bash
# Build with verbose output
docker build --progress=plain --target builder .

# Interactive shell in builder stage
docker run -it --rm irc-atl-chat:latest-builder bash
```

## Performance Benefits

- **Faster builds**: Better layer caching and parallel compilation
- **Smaller images**: Multi-stage build eliminates build dependencies
- **Better security**: Non-root users and minimal runtime surface
- **Easier maintenance**: Clear separation of concerns between stages

## Atheme-Specific Optimizations

### Enhanced Dependencies
- **libidn2-dev**: Internationalized domain name support
- **nettle-dev**: Cryptographic library for better security
- **libqrencode-dev**: QR code generation capabilities
- **autoconf/automake/libtool**: Modern build system support

### Runtime Enhancements
- **Dual health checks**: Both UnrealIRCd and Atheme services
- **Service symlinks**: Easier access to binaries
- **Configuration directories**: Proper ownership and permissions
- **Enhanced metadata**: Docker labels and maintainer information
- **Atheme environment variables**: Pre-configured paths for configuration, data, and modules
- **Database directory**: Proper setup for Atheme data persistence
- **Smart startup script**: Coordinates both services with proper startup order
- **Database initialization**: Automatically initializes Atheme database on first run

### Build Configuration
- **Compiler sanitizers**: Enhanced debugging and security analysis
- **Large network support**: `--enable-large-net` for networks >2000 users
- **FHS compliance**: Follows Filesystem Hierarchy Standard
- **Reproducible builds**: Consistent output across different environments
- **Perl support**: Extended scripting capabilities
- **pkg-config integration**: Better library detection and linking
- **Contrib modules**: `--enable-contrib` for additional functionality
- **NLS support**: Internationalization capabilities

### Compiler Optimizations
- **Native architecture tuning**: `-march=native -mtune=native`
- **Security hardening**: Stack protection and read-only relocations
- **Performance flags**: `-O2` optimization level
- **Parallel builds**: Automatic job distribution across CPU cores
- **Fortify source**: `-D_FORTIFY_SOURCE=2` for additional security
- **Atheme-specific flags**: Optimized compilation for IRC services

## Troubleshooting

### Common Issues

1. **Build fails on dependency installation**
   - Ensure Docker has sufficient memory (recommend 4GB+)
   - Check internet connectivity for package downloads
   - Verify package versions match Debian Bookworm availability

2. **Permission denied errors**
   - Ensure proper ownership of source files
   - Check Docker daemon permissions

3. **Port conflicts**
   - Verify ports 6667 and 6697 are available
   - Check for existing IRC services

4. **Atheme build failures**
   - Ensure all required dependencies are available
   - Check that autoconf/automake versions are compatible
   - Verify pkg-config is properly installed
   - For large networks (>2000 users), ensure `--enable-large-net` is used
   - Check that contrib modules are properly enabled if needed

### Debug Commands

```bash
# Check container status
docker-compose ps

# View container logs
docker-compose logs ircd
docker-compose logs atheme

# Access container shell
docker-compose exec ircd bash
docker-compose exec atheme bash
```

## ⚠️ **IMPORTANT: Database Backend Change**

**Atheme 7.2+ no longer supports SQL databases.** This configuration uses the **flatfile backend** which is the only supported option for modern Atheme versions.

### **What Changed:**
- **SQL backends deprecated** as of Atheme 2.2
- **Flatfile backend required** for Atheme 7.2+
- **Data stored in** `/usr/local/atheme/data` directory
- **Automatic initialization** on first run

## Atheme Features & Capabilities

### Core Services
- **NickServ**: Nickname registration and management
- **ChanServ**: Channel registration and management
- **OperServ**: Network operator services
- **GroupServ**: Group management services
- **HostServ**: Hostname services
- **MemoServ**: Memo (private message) services

### Startup Script Features
- **Service Coordination**: Proper startup order (UnrealIRCd → Atheme)
- **Health Monitoring**: Waits for services to be ready before proceeding
- **Configuration Validation**: Ensures Atheme config exists before starting
- **Database Management**: Automatically initializes flatfile database
- **Graceful Shutdown**: Properly stops services in correct order
- **Status Monitoring**: Real-time service status checking
- **Error Handling**: Comprehensive error reporting and recovery

### Advanced Features
- **Large network optimization**: Built for networks with 2000+ users
- **Contrib modules**: Extended functionality through additional modules
- **Internationalization**: Multi-language support (NLS)
- **Perl scripting**: Extended automation capabilities
- **Database support**: Flatfile backend (Atheme 7.2+ requirement)
- **Security features**: Built-in protection against abuse

## Web Administration

### UnrealIRCd WebPanel

This setup includes the **UnrealIRCd WebPanel** - a web-based administration interface that gives you complete control over your IRC network from your browser.

#### **Features:**
- **Network Overview**: Real-time server, user, and channel information
- **Administrative Tasks**: Add/remove bans, spamfilters, and other controls
- **User Management**: Monitor and manage connected users
- **Channel Administration**: Manage channel settings and modes
- **Server Statistics**: Network performance and usage metrics
- **Mobile Responsive**: Works on desktop and mobile devices

#### **Quick Start:**

```bash
# Start all services including webpanel
docker-compose up -d

# Access webpanel
# Open http://localhost:8080 in your browser
```

#### **Configuration:**

The webpanel is automatically configured with:
- **JSON-RPC API**: Port 8600 for UnrealIRCd communication
- **Web Interface**: Port 8080 for browser access
- **Authentication**: File-based auth (configurable to SQL)
- **Security**: IP-restricted access (127.* by default)

#### **Access URLs:**
- **WebPanel**: http://localhost:8080
- **IRC Server**: irc://localhost:6667
- **IRC SSL**: ircs://localhost:6697

#### **Default Credentials:**
- **RPC User**: `adminpanel`
- **RPC Password**: `webpanel_password_2024`
- **Access IP**: `127.*` (localhost only)

#### **Customization:**

```bash
# Change webpanel port
# Edit docker-compose.yml: '8080:80' → 'YOUR_PORT:80'

# Change RPC password
# Edit docker-compose.yml: UNREALIRCD_RPC_PASSWORD

# Access from external IPs
# Edit unrealircd.conf: rpc-user adminpanel { match { ip YOUR_IP; } }
```

#### **Troubleshooting:**

```bash
# Check webpanel status
docker-compose ps webpanel

# View webpanel logs
docker-compose logs webpanel

# Test JSON-RPC connection
curl -f http://localhost:8600/

# Access webpanel container
docker-compose exec webpanel bash
```

## Module Management

### UnrealIRCd Contrib Modules

This setup includes full support for UnrealIRCd contrib modules with easy management tools.

#### **Available Tools:**

1. **`manage-modules.sh`** - Main module management script
2. **`module-config.sh`** - Configuration file helper

#### **Quick Start:**

```bash
# List available modules
docker-compose exec ircd manage-modules list

# Install a module (e.g., webpanel)
docker-compose exec ircd manage-modules install webpanel

# Add module to configuration
docker-compose exec ircd module-config add webpanel

# Check installed modules
docker-compose exec ircd manage-modules installed

# Update contrib repository
docker-compose exec ircd manage-modules update
```

#### **Module Management Commands:**

```bash
# List all available contrib modules
manage-modules list

# Show detailed module information
manage-modules info <module-name>

# Install a module
manage-modules install <module-name>

# Uninstall a module
manage-modules uninstall <module-name>

# Upgrade all modules or specific module
manage-modules upgrade [module-name]

# Update contrib repository
manage-modules update

# Show installed modules
manage-modules installed
```

#### **Configuration Management:**

```bash
# Add module to unrealircd.conf
module-config add <module-name>

# Remove module from unrealircd.conf
module-config remove <module-name>

# List loaded modules in config
module-config list
```

#### **Important Notes:**

- **Contrib modules are not officially supported** by the UnrealIRCd team
- **Use at your own risk** - modules can affect server stability
- **Always backup** before installing new modules
- **Test thoroughly** in development before production
- **REHASH or restart** UnrealIRCd after configuration changes

#### **Popular Modules:**

- **webpanel**: Web-based administration interface
- **chanfilter**: Advanced channel filtering
- **extbans**: Extended ban types
- **geoip**: Geographic IP-based features
- **ircops**: IRC operator management

#### **Troubleshooting:**

```bash
# Check module compilation errors
docker-compose logs ircd

# Verify module installation
ls -la /usr/local/unrealircd/modules/third/

# Check configuration syntax
docker-compose exec ircd unrealircd -configtest
```

## Contributing

When making changes to the Dockerfile:

1. Test builds with different targets
2. Verify runtime functionality
3. Update version numbers in docker-compose.yml
4. Test with the build script
5. Update this README if needed

## License

This project is part of the AllThingsLinux IRC infrastructure.
