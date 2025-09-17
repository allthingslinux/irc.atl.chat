# UnrealIRCd Modules

This guide covers the module system in UnrealIRCd, including core modules, third-party modules, and custom module development for IRC.atl.chat.

## Overview

### Module Architecture

UnrealIRCd uses a modular architecture where functionality is provided by loadable modules:

- **Core Modules**: Built-in functionality (user modes, channel modes, etc.)
- **Third-Party Modules**: Community-developed extensions
- **Custom Modules**: Site-specific modifications

### Module Categories

```
Modules/
├── usermodes/          # User mode implementations
├── chanmodes/          # Channel mode implementations
├── commands/           # IRC command extensions
├── extensions/         # Protocol extensions (IRCv3, etc.)
├── third/             # Third-party modules
├── crypto/            # Cryptographic functions
└── backend/           # Database backends
```

## Module Management

### Module Loading

Modules are loaded in configuration files:

#### Default Modules (`modules.default.conf`)
```c
// Core functionality - always loaded
loadmodule "cloak_sha256";
loadmodule "usermodes/secureonlymsg";
loadmodule "chanmodes/ban";
```

#### Custom Modules (`modules.custom.conf`)
```c
// Site-specific modules
loadmodule "third/showwebirc";
loadmodule "third/geoip";
```

#### Optional Modules (`modules.optional.conf`)
```c
// Feature modules - loaded as needed
// loadmodule "chanmodes/auditorium";
```

### Module Dependencies

Some modules require others to function:

```c
// SASL requires crypto modules
loadmodule "crypto/pbkdf2v2";
loadmodule "extensions/sasl";

// IRCv3 requires specific extensions
loadmodule "extensions/ircv3";
loadmodule "extensions/ircv3-cap";
```

## Core Modules

### User Mode Modules

#### Authentication & Security
```c
loadmodule "usermodes/secureonlymsg";    // +Z: SSL-only messaging
loadmodule "usermodes/regonlymsg";      // +R: Registered users only
loadmodule "usermodes/privdeaf";        // +D: Block private messages
loadmodule "usermodes/noctcp";          // +T: Block CTCP
```

#### Privacy & Control
```c
loadmodule "usermodes/bot";             // +B: Bot identification
loadmodule "usermodes/censor";          // +G: Content filtering
loadmodule "usermodes/hide-idle-time"; // +I: Hide idle time
loadmodule "usermodes/privacy";         // +p: Hide channel list
```

#### Administrative
```c
loadmodule "usermodes/nokick";          // +q: Unkickable (services)
loadmodule "usermodes/servicebot";      // +S: Services bot
loadmodule "usermodes/showwhois";       // +W: See who does /WHOIS
```

### Channel Mode Modules

#### Access Control
```c
loadmodule "chanmodes/admin";           // +a: Admin status
loadmodule "chanmodes/ban";             // +b: Ban list
loadmodule "chanmodes/inviteonly";      // +i: Invite-only
loadmodule "chanmodes/key";             // +k: Channel key
```

#### Moderation
```c
loadmodule "chanmodes/limit";           // +l: User limit
loadmodule "chanmodes/moderated";       // +m: Moderated
loadmodule "chanmodes/no-external";     // +n: No external messages
loadmodule "chanmodes/private";         // +p: Private channel
```

#### Special Features
```c
loadmodule "chanmodes/auditorium";      // +A: Auditorium mode
loadmodule "chanmodes/operonly";        // +O: IRCops only
loadmodule "chanmodes/permanent";       // +P: Permanent channel
loadmodule "chanmodes/secret";          // +s: Secret channel
```

### Extension Modules

#### IRCv3 Support
```c
loadmodule "extensions/ircv3";          // IRCv3 protocol support
loadmodule "extensions/ircv3-cap";      // Capability negotiation
loadmodule "extensions/ircv3-echo";     // Message echo
loadmodule "extensions/sasl";           // SASL authentication
```

#### Web Integration
```c
loadmodule "extensions/webirc";         // WebIRC support
loadmodule "third/showwebirc";          // Display WebIRC usage
```

#### Security Extensions
```c
loadmodule "extensions/restrict-usermode"; // Restrict user modes
loadmodule "extensions/restrict-channelmode"; // Restrict channel modes
```

## Third-Party Modules

### Available Modules

IRC.atl.chat includes several third-party modules:

```bash
# List available modules
cat src/backend/unrealircd/third-party-modules.list

# Currently available:
# - geoip: IP geolocation
# - showwebirc: WebIRC logging
# - antirandom: Anti-random nick protection
# - antirandom-channel: Channel anti-random protection
# - jointhrottle: Join throttling
# - antirandom-ident: Ident anti-random
```

### Installing Third-Party Modules

```bash
# Install all available modules
./src/backend/unrealircd/scripts/install-modules.sh

# Install specific module
./src/backend/unrealircd/scripts/install-modules.sh geoip
```

### Module Configuration

#### GeoIP Module
```c
loadmodule "third/geoip";

geoip {
    ipv4-database "/path/to/GeoLite2-Country.mmdb";
    ipv6-database "/path/to/GeoLite2-Country.mmdb";
}
```

#### WebIRC Logging
```c
loadmodule "third/showwebirc";

showwebirc {
    oper-only no;              // Show to all users
    log yes;                   // Log WebIRC usage
}
```

## Module Development

### Creating Custom Modules

#### Module Structure
```c
#include "unrealircd.h"

ModuleHeader Mod_Header = {
    "mymodule",                // Module name
    "1.0",                     // Version
    "My custom module",        // Description
    "Author Name",             // Author
    "unrealircd-6"             // UnrealIRCd version
};

MOD_INIT(mymodule) {
    // Initialization code
    return MOD_SUCCESS;
}

MOD_LOAD(mymodule) {
    // Load-time code
    return MOD_SUCCESS;
}

MOD_UNLOAD(mymodule) {
    // Cleanup code
    return MOD_SUCCESS;
}
```

#### Hook System

Modules can hook into IRC events:

```c
HookAdd(modinfo, HOOKTYPE_PRE_USERMSG, 0, my_usermsg_hook);

static int my_usermsg_hook(Cmdoverride *ovr, aClient *cptr, aClient *sptr, int parc, char *parv[]) {
    // Process user messages
    return 0; // Continue processing
}
```

#### User Mode Implementation
```c
UMODE_FUNC(mymode) {
    // Handle +mymode/-mymode
    if (what == MODE_ADD) {
        // Add mode logic
    } else {
        // Remove mode logic
    }
}
```

### Building Modules

```bash
# Compile module
gcc -shared -fPIC -I/usr/include/unrealircd mymodule.c -o mymodule.so

# Install module
cp mymodule.so /home/unrealircd/unrealircd/modules/

# Load in configuration
loadmodule "mymodule";
```

## Module Configuration

### Configuration Files

#### modules.default.conf
Contains core modules required for basic functionality:

```c
// Core modules - DO NOT REMOVE
loadmodule "cloak_sha256";
loadmodule "usermodes/secureonlymsg";
loadmodule "chanmodes/ban";
loadmodule "chanmodes/inviteonly";

// Standard extensions
loadmodule "extensions/ircv3";
loadmodule "extensions/sasl";
```

#### modules.custom.conf
Site-specific modules:

```c
// Third-party modules
loadmodule "third/showwebirc";
loadmodule "third/geoip";

// Custom modules
// loadmodule "mymodule";
```

#### modules.optional.conf
Optional features:

```c
// Load as needed
// loadmodule "chanmodes/auditorium";
// loadmodule "usermodes/censor";
```

### Runtime Module Management

```bash
# List loaded modules
MODULE LIST

# Load module at runtime
MODULE LOAD mymodule

# Unload module
MODULE UNLOAD mymodule
```

## Troubleshooting

### Common Issues

#### Module Not Loading
```bash
# Check module file exists
ls -la /home/unrealircd/unrealircd/modules/mymodule.so

# Check dependencies
ldd /home/unrealircd/unrealircd/modules/mymodule.so

# Check logs for errors
grep "mymodule" logs/unrealircd/ircd.log
```

#### Missing Dependencies
```bash
# Install required libraries
apt-get install libssl-dev libgeoip-dev

# Rebuild module
make clean && make

# Check library paths
pkg-config --libs openssl geoip
```

#### Configuration Errors
```bash
# Validate configuration
unrealircd -c /path/to/unrealircd.conf

# Check syntax errors
grep "error" logs/unrealircd/ircd.log
```

#### Version Compatibility
```bash
# Check UnrealIRCd version
unrealircd -v

# Verify module compatibility
strings mymodule.so | grep "unrealircd"
```

### Debug Information

```bash
# Enable module debugging
set {
    log-level debug;
};

# Check module status
MODULE INFO mymodule
```

## Performance Considerations

### Module Overhead

- **Core modules**: Minimal overhead, essential functionality
- **Third-party modules**: Variable overhead, test performance impact
- **Custom modules**: Depends on implementation complexity

### Memory Usage

```bash
# Monitor module memory
ps aux | grep unrealircd

# Check module allocations
valgrind --tool=massif unrealircd
```

### CPU Usage

```bash
# Profile module performance
perf record -p $(pidof unrealircd)

# Analyze performance data
perf report
```

## Security Considerations

### Module Security

#### Trust Levels
- **Official modules**: Fully trusted, security audited
- **Third-party modules**: Use at own risk, review source code
- **Custom modules**: Full responsibility for security

#### Best Practices
```c
// Input validation
if (parc < 2) return 0;

// Buffer bounds checking
strlcpy(buffer, parv[1], sizeof(buffer));

// Privilege checking
if (!IsOper(sptr)) return 0;
```

### Access Controls

```c
// Restrict module commands to operators
if (!ValidatePermissions(sptr, "admin")) {
    sendto_one(sptr, ":%s NOTICE %s :Permission denied",
               me.name, sptr->name);
    return 0;
}
```

## Maintenance

### Module Updates

```bash
# Check for updates
./scripts/check-module-updates.sh

# Update modules
./scripts/update-modules.sh

# Restart to load new versions
make restart
```

### Backup and Recovery

```bash
# Backup module configurations
cp src/backend/unrealircd/conf/modules.*.conf backup/

# Backup custom modules
cp src/backend/unrealircd/modules/*.so backup/

# Recovery
cp backup/modules.custom.conf src/backend/unrealircd/conf/
```

### Monitoring

```bash
# Module health checks
./scripts/monitor-modules.sh

# Log analysis
grep "module" logs/unrealircd/ircd.log

# Performance monitoring
./scripts/profile-modules.sh
```

## Related Documentation

- [UNREALIRCD.md](UNREALIRCD.md) - Main server configuration
- [CONFIG.md](CONFIG.md) - Configuration management
- [DOCKER.md](DOCKER.md) - Container setup
- [UnrealIRCd Module API](https://www.unrealircd.org/docs/module_api) - Official API docs
- [Third-Party Modules](https://modules.unrealircd.org/) - Module repository