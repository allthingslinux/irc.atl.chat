# UnrealIRCd WebPanel

The UnrealIRCd WebPanel provides a comprehensive web-based administration interface for managing your IRC network. It offers real-time monitoring, user management, configuration editing, and administrative controls through an intuitive web interface.

## Overview

### Architecture

The WebPanel consists of:
- **Frontend**: PHP-based web interface with modern responsive design
- **Backend**: JSON-RPC API communication with UnrealIRCd
- **Authentication**: File-based or SQL authentication systems
- **Security**: RPC access controls and session management

### Key Features

- **Real-time Monitoring**: Live server statistics and connection tracking
- **User Management**: IRC user administration and ban management
- **Channel Administration**: Channel settings and access controls
- **Server Configuration**: Remote configuration editing
- **Log Viewing**: Real-time log monitoring and filtering
- **Statistics Dashboard**: Network metrics and performance data

## Installation and Setup

### Container Configuration

The WebPanel runs as a Docker container with the following setup:

```yaml
unrealircd-webpanel:
  build:
    context: .
    dockerfile: src/frontend/webpanel/Containerfile

  container_name: unrealircd-webpanel
  hostname: unrealircd-webpanel

  depends_on:
    unrealircd:
      condition: service_healthy

  volumes:
    - unrealircd-webpanel-data:/var/www/html/unrealircd-webpanel/data

  environment:
    - TZ=UTC

  ports:
    - '${WEBPANEL_PORT:-8080}:8080'

  networks:
    - irc-network

  restart: unless-stopped

  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

### Prerequisites

- **UnrealIRCd**: Running with JSON-RPC API enabled (port 8600)
- **PHP 8.2+**: With required extensions
- **Nginx**: Web server for hosting
- **Database**: SQLite (default) or MySQL/MariaDB

### Quick Start

1. **Start the WebPanel:**
   ```bash
   make up
   ```

2. **Access the interface:**
   ```
   http://localhost:8080
   ```

3. **Default credentials:**
   - Username: `admin`
   - Password: `admin` (change immediately!)

## Configuration

### Environment Variables

Configure the WebPanel through environment variables:

```bash
# WebPanel Port
WEBPANEL_PORT=8080

# RPC Connection (auto-configured)
WEBPANEL_RPC_USER=adminpanel
WEBPANEL_RPC_PASSWORD=secure_password_here
```

### WebPanel Configuration File

The main configuration is stored in `config.php`:

```php
<?php
// Database configuration
$config['database'] = [
    'type' => 'sqlite',  // sqlite, mysql, pgsql
    'file' => '/var/www/html/unrealircd-webpanel/data/webpanel.db'
];

// RPC Configuration
$config['rpc'] = [
    'host' => 'unrealircd',
    'port' => 8600,
    'user' => getenv('WEBPANEL_RPC_USER') ?: 'adminpanel',
    'password' => getenv('WEBPANEL_RPC_PASSWORD') ?: 'test1234',
    'timeout' => 30
];

// Authentication
$config['auth'] = [
    'method' => 'file',  // file, sql
    'file' => '/var/www/html/unrealircd-webpanel/data/users.php'
];

// Security settings
$config['security'] = [
    'session_timeout' => 3600,
    'max_login_attempts' => 5,
    'lockout_time' => 900,
    'require_https' => true
];
```

### Authentication Setup

#### File-Based Authentication (Default)

Users are stored in a PHP file:

```php
<?php
$users = [
    'admin' => [
        'password' => '$2y$10$hashedpasswordhere',
        'level' => 100,  // 0-100 permission level
        'realname' => 'IRC Administrator'
    ]
];
```

**Create admin user:**
```bash
# Generate password hash
docker exec unrealircd-webpanel php -r "
\$password = password_hash('your_secure_password', PASSWORD_DEFAULT);
echo \"Password hash: \$password\n\";
"
```

#### SQL Authentication

Configure database authentication:

```php
$config['auth'] = [
    'method' => 'sql',
    'dsn' => 'mysql:host=db;dbname=webpanel',
    'username' => 'webpanel',
    'password' => 'secure_password',
    'table' => 'users',
    'columns' => [
        'username' => 'username',
        'password' => 'password_hash',
        'level' => 'permission_level'
    ]
];
```

### Database Setup

#### SQLite (Default)

Automatically created on first run:

```bash
# Database location
ls -la data/unrealircd-webpanel-data/webpanel.db
```

#### MySQL/MariaDB

Create database and user:

```sql
CREATE DATABASE webpanel;
CREATE USER 'webpanel'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON webpanel.* TO 'webpanel'@'localhost';
FLUSH PRIVILEGES;
```

## User Interface

### Dashboard

The main dashboard provides:
- **Server Status**: Connection status and uptime
- **Network Statistics**: User count, channel count, server load
- **Recent Activity**: Connection logs and events
- **System Health**: Memory usage, CPU load, disk space

### User Management

#### IRC User Administration

- **User Search**: Find users by nickname, username, or hostname
- **User Details**: View user information, modes, and channels
- **User Actions**:
  - Send messages
  - Change modes
  - Kick from channels
  - Ban management

#### Ban Management

- **Global Bans**: Network-wide K-lines and Z-lines
- **Channel Bans**: Channel-specific ban lists
- **Ban Types**:
  - **K-line**: Kill user on connect
  - **Z-line**: IP-based ban
  - **G-line**: Global ban with expiration
  - **Spamfilter**: Content-based filtering

### Channel Management

#### Channel Overview

- **Channel List**: All active channels with user counts
- **Channel Details**: Topic, modes, user list, creation time
- **Channel Settings**: Edit channel modes and properties

#### Channel Operations

- **Mode Changes**: Set channel modes (+nt, +i, etc.)
- **Topic Management**: Change channel topics
- **Access Control**: Manage channel operators and voices
- **Channel Bans**: Local ban lists and exceptions

### Server Configuration

#### Remote Configuration Editing

- **Edit Configuration**: Modify unrealircd.conf through web interface
- **Configuration Validation**: Syntax checking before applying changes
- **Configuration History**: Track configuration changes
- **Backup/Restore**: Configuration backup and recovery

#### Module Management

- **Module Status**: View loaded modules and their status
- **Module Control**: Load/unload modules remotely
- **Module Configuration**: Edit module-specific settings

### Logging and Monitoring

#### Log Viewer

- **Real-time Logs**: Live IRC server log streaming
- **Log Filtering**: Filter by log level, source, or content
- **Log Search**: Search historical logs
- **Log Export**: Download log excerpts

#### Server Statistics

- **Connection Statistics**: Peak connections, connection rates
- **Traffic Statistics**: Bandwidth usage, message rates
- **User Statistics**: Registration trends, geographic distribution
- **Channel Statistics**: Popular channels, growth trends

## API Integration

### JSON-RPC API

The WebPanel communicates with UnrealIRCd via JSON-RPC:

#### Connection Setup

```php
$rpc = new JsonRpcClient([
    'host' => 'unrealircd',
    'port' => 8600,
    'user' => 'adminpanel',
    'password' => 'secure_password'
]);
```

#### Common API Calls

**Get server information:**
```php
$result = $rpc->call('server.info');
```

**List online users:**
```php
$result = $rpc->call('user.list', ['limit' => 100]);
```

**Get channel details:**
```php
$result = $rpc->call('channel.get', ['name' => '#help']);
```

**Execute server command:**
```php
$result = $rpc->call('server.command', [
    'command' => 'KILL',
    'target' => 'baduser',
    'reason' => 'Violation of network rules'
]);
```

### WebSocket Support

Real-time updates use WebSocket connections:

```javascript
// Connect to WebSocket
const ws = new WebSocket('ws://localhost:8080/ws');

// Listen for updates
ws.onmessage = function(event) {
    const data = JSON.parse(event.data);
    if (data.type === 'user_connected') {
        updateUserCount(data.count);
    }
};
```

## Security Features

### Authentication Security

- **Password Hashing**: bcrypt/argon2 password storage
- **Session Management**: Secure session handling with timeouts
- **Rate Limiting**: Protection against brute force attacks
- **IP Logging**: Track login attempts and sources

### Access Control

#### Permission Levels

Permission levels range from 0-100:

- **0**: No access
- **25**: Read-only access
- **50**: Basic user management
- **75**: Channel and ban management
- **100**: Full administrative access

#### Role-Based Access

```php
// Check permissions
if ($user['level'] >= 75) {
    // Allow ban management
    showBanInterface();
}

if ($user['level'] >= 100) {
    // Allow server configuration
    showServerConfig();
}
```

### Network Security

- **HTTPS Enforcement**: Redirect HTTP to HTTPS
- **CSRF Protection**: Cross-site request forgery prevention
- **XSS Protection**: Input sanitization and output encoding
- **Secure Headers**: Security headers (CSP, HSTS, etc.)

## Customization

### Theme Customization

Customize the WebPanel appearance:

```php
$config['theme'] = [
    'name' => 'custom',
    'colors' => [
        'primary' => '#007bff',
        'secondary' => '#6c757d',
        'success' => '#28a745',
        'danger' => '#dc3545'
    ],
    'logo' => '/images/custom-logo.png'
];
```

### Custom Modules

Extend WebPanel functionality:

```php
// Custom module class
class CustomModule extends WebPanelModule {
    public function getRoutes() {
        return [
            '/custom' => 'customPage'
        ];
    }

    public function customPage() {
        // Custom page logic
        return $this->render('custom.html.twig');
    }
}
```

### Plugin System

The WebPanel supports plugins for additional functionality:

- **Custom Authentication**: LDAP, OAuth, SAML
- **Notification Systems**: Email, Slack, Discord
- **Backup Systems**: Automated configuration backups
- **Monitoring Integration**: Prometheus, Grafana

## Troubleshooting

### Connection Issues

#### RPC Connection Failed

**Symptoms:**
- WebPanel shows "Connection failed" errors
- Unable to retrieve server information

**Solutions:**

1. **Check RPC configuration:**
   ```bash
   # Verify UnrealIRCd RPC settings
   grep -A5 "listen.*rpc" src/backend/unrealircd/conf/unrealircd.conf
   ```

2. **Test RPC connectivity:**
   ```bash
   # Test from WebPanel container
   docker exec unrealircd-webpanel nc -z unrealircd 8600
   ```

3. **Check RPC credentials:**
   ```bash
   # Verify credentials match
   grep "WEBPANEL_RPC" .env
   ```

4. **Check UnrealIRCd logs:**
   ```bash
   make logs-ircd | grep -i rpc
   ```

#### Authentication Issues

**Symptoms:**
- "Invalid credentials" errors
- Unable to log in

**Solutions:**

1. **Check password hash:**
   ```bash
   # Verify password format
   docker exec unrealircd-webpanel php -r "
   \$hash = '$2y$10\$...';  // Your hash
   var_dump(password_verify('your_password', \$hash));
   "
   ```

2. **Check user file permissions:**
   ```bash
   ls -la data/unrealircd-webpanel-data/
   ```

3. **Verify user configuration:**
   ```bash
   # Check users.php file
   cat data/unrealircd-webpanel-data/users.php
   ```

### Performance Issues

#### Slow Loading

**Symptoms:**
- Slow page loads
- Timeout errors

**Solutions:**

1. **Check RPC timeout:**
   ```php
   $config['rpc']['timeout'] = 60;  // Increase timeout
   ```

2. **Optimize database:**
   ```bash
   # Vacuum SQLite database
   docker exec unrealircd-webpanel sqlite3 /var/www/html/unrealircd-webpanel/data/webpanel.db "VACUUM;"
   ```

3. **Enable caching:**
   ```php
   $config['cache'] = [
       'enabled' => true,
       'ttl' => 300  // 5 minutes
   ];
   ```

### Configuration Issues

#### Settings Not Applied

**Symptoms:**
- Configuration changes don't take effect
- Interface shows old data

**Solutions:**

1. **Clear cache:**
   ```bash
   # Clear PHP cache
   docker exec unrealircd-webpanel rm -rf /tmp/*
   ```

2. **Restart WebPanel:**
   ```bash
   docker restart unrealircd-webpanel
   ```

3. **Check file permissions:**
   ```bash
   # Ensure config.php is readable
   docker exec unrealircd-webpanel ls -la /var/www/html/unrealircd-webpanel/config.php
   ```

## Backup and Recovery

### Configuration Backup

```bash
# Backup WebPanel data
docker run --rm -v unrealircd-webpanel-data:/data \
    alpine tar czf - -C /data . > webpanel-backup-$(date +%Y%m%d).tar.gz
```

### Database Backup

```bash
# SQLite backup
docker exec unrealircd-webpanel sqlite3 /var/www/html/unrealircd-webpanel/data/webpanel.db \
    ".backup /tmp/webpanel.db.backup"

# Copy backup
docker cp unrealircd-webpanel:/tmp/webpanel.db.backup ./webpanel.db.backup
```

### Recovery Procedure

```bash
# Stop WebPanel
docker stop unrealircd-webpanel

# Restore data
docker run --rm -v unrealircd-webpanel-data:/data \
    -v $(pwd):/backup alpine \
    tar xzf /backup/webpanel-backup-latest.tar.gz -C /data

# Start WebPanel
docker start unrealircd-webpanel
```

## API Reference

### Authentication Endpoints

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
    "username": "admin",
    "password": "password"
}

Response:
{
    "success": true,
    "token": "jwt_token_here",
    "user": {
        "username": "admin",
        "level": 100
    }
}
```

#### Get Server Info
```http
GET /api/server/info
Authorization: Bearer jwt_token

Response:
{
    "name": "irc.atl.chat",
    "version": "6.2.0.1",
    "uptime": 86400,
    "users": 150,
    "channels": 25
}
```

### User Management

#### List Users
```http
GET /api/users?limit=50&offset=0
Authorization: Bearer jwt_token

Response:
{
    "users": [
        {
            "nickname": "user1",
            "username": "user",
            "hostname": "host.example.com",
            "modes": "+i",
            "channels": ["#help", "#general"]
        }
    ],
    "total": 150
}
```

#### Ban User
```http
POST /api/users/ban
Authorization: Bearer jwt_token
Content-Type: application/json

{
    "target": "baduser",
    "type": "kline",  // kline, zline, gline
    "duration": "24h",
    "reason": "Violation of network rules"
}

Response:
{
    "success": true,
    "ban_id": "123"
}
```

## Development

### Contributing

The WebPanel is open source and welcomes contributions:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Submit a pull request**

### Plugin Development

Create custom plugins:

```php
<?php
class MyPlugin extends WebPanelPlugin {
    public function init() {
        // Plugin initialization
        $this->addRoute('/my-feature', 'myFeatureAction');
        $this->addMenuItem('My Feature', '/my-feature');
    }

    public function myFeatureAction() {
        // Custom functionality
        return $this->render('my-feature.html.twig', [
            'data' => $this->getCustomData()
        ]);
    }
}
```

### Theme Development

Create custom themes:

```css
/* custom-theme.css */
.webpanel-theme-custom {
    --primary-color: #007bff;
    --background-color: #f8f9fa;
    --text-color: #212529;
}

.webpanel-theme-custom .navbar {
    background-color: var(--primary-color);
}
```

## Related Documentation

- [UNREALIRCD.md](UNREALIRCD.md) - IRC server configuration
- [CONFIG.md](CONFIG.md) - Configuration management
- [API.md](API.md) - JSON-RPC API documentation
- [DOCKER.md](DOCKER.md) - Container setup
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

## Support

For WebPanel support:

- **Documentation**: Check this guide and related docs
- **GitHub Issues**: Report bugs and request features
- **IRC Channel**: Join #help on your IRC network
- **Community**: Check UnrealIRCd forums and documentation