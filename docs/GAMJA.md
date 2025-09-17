# Gamja - Web IRC Client

Gamja is a modern, responsive web-based IRC client for IRC.atl.chat. It provides a user-friendly interface for connecting to IRC networks through a web browser, featuring real-time messaging, channel management, and mobile-friendly design.

## Overview

### Features

- **Modern Web Interface**: Clean, responsive design that works on desktop and mobile
- **Real-time Messaging**: WebSocket-based IRC connection with instant message delivery
- **Multi-channel Support**: Join multiple channels simultaneously with tabbed interface
- **Message History**: Persistent message history and scrollback
- **User-friendly**: Intuitive interface suitable for IRC newcomers
- **Theme Support**: Light and dark themes with customization options
- **Mobile Optimized**: Touch-friendly interface for mobile devices
- **Offline Support**: Basic functionality even with intermittent connections

### Architecture

Gamja consists of:
- **Frontend**: Single-page application built with modern web technologies
- **WebSocket Connection**: Direct connection to IRC server via WebSocket
- **Configuration**: JSON-based configuration for server settings
- **Containerized**: Docker container for easy deployment

## Installation and Setup

### Container Configuration

Gamja runs as a Docker container (currently commented out in compose.yaml):

```yaml
gamja:
  build:
    context: .
    dockerfile: src/frontend/gamja/Containerfile
  container_name: gamja
  hostname: gamja
  depends_on:
    unrealircd:
      condition: service_healthy
  volumes:
    - ./src/frontend/gamja:/var/www/html/gamja:ro
  environment:
    - TZ=UTC
  ports:
    - '8081:80'
  networks:
    - irc-network
  restart: unless-stopped
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost/gamja/"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

### Quick Start

1. **Uncomment Gamja in compose.yaml:**
   ```yaml
   # Remove the comments from the gamja service block
   gamja:
     # ... configuration ...
   ```

2. **Start the service:**
   ```bash
   make up
   ```

3. **Access Gamja:**
   ```
   http://localhost:8081
   ```

### Prerequisites

- **UnrealIRCd**: Running with WebSocket support enabled (port 8000)
- **Web Server**: Nginx or Apache for serving static files
- **Modern Browser**: Chrome, Firefox, Safari, or Edge (latest versions)

## Configuration

### Server Configuration

Gamja is configured through JSON files:

#### Default Configuration (`default/config.json`)

```json
{
	"server": {
		"url": "wss://irc.example.org",
		"autojoin": "#gamja"
	},
	"oauth2": {
		"url": "https://auth.example.org",
		"client_id": "your_oauth_client_id"
	}
}
```

#### Custom Configuration (`conf/config.json`)

Create a custom configuration file:

```json
{
	"server": {
		"url": "wss://irc.atl.chat:8000",
		"autojoin": "#welcome,#help,#general"
	},
	"oauth2": {
		"url": "https://auth.atl.chat",
		"client_id": "gamja_client"
	},
	"defaults": {
		"nick": "Guest",
		"realname": "Web IRC User",
		"username": "webirc"
	},
	"theme": "dark",
	"notifications": {
		"enabled": true,
		"highlight": true,
		"private": true
	}
}
```

### Configuration Options

#### Server Settings

```json
{
	"server": {
		"url": "wss://irc.atl.chat:8000",     // WebSocket URL
		"autojoin": "#channel1,#channel2",    // Channels to auto-join
		"nickFormat": "Guest{random}",       // Nickname format for guests
		"maxRetries": 3,                     // Connection retry attempts
		"retryDelay": 5000                   // Delay between retries (ms)
	}
}
```

#### User Interface

```json
{
	"theme": "auto",                         // auto, light, dark
	"fontSize": "medium",                    // small, medium, large
	"messageLayout": "compact",              // compact, comfortable
	"timestamps": true,                      // Show message timestamps
	"seconds": false,                        // Show seconds in timestamps
	"showJoinParts": true,                   // Show join/part messages
	"showNickChanges": true                  // Show nickname changes
}
```

#### Notification Settings

```json
{
	"notifications": {
		"enabled": true,                      // Enable browser notifications
		"highlight": true,                    // Notify on highlights
		"private": true,                      // Notify on private messages
		"mentionSound": "bell.mp3",           // Sound file for mentions
		"messageSound": "pop.mp3"             // Sound file for messages
	}
}
```

#### OAuth2 Integration

```json
{
	"oauth2": {
		"url": "https://auth.atl.chat",       // OAuth2 provider URL
		"client_id": "gamja_client",          // OAuth2 client ID
		"scope": "openid profile",            // OAuth2 scopes
		"redirect_uri": "/oauth2/callback"    // Callback URL
	}
}
```

## User Interface

### Connecting to IRC

1. **Open Gamja** in your web browser
2. **Enter connection details:**
   - **Nickname**: Your desired IRC nickname
   - **Channels**: Channels to join (optional)
3. **Click "Connect"**

Gamja will establish a WebSocket connection to the IRC server and join the specified channels.

### Main Interface

#### Channel Tabs

- **Tab Navigation**: Switch between channels and private messages
- **Close Button**: Close channels (except the first one)
- **Unread Indicators**: Show unread message counts
- **Status Indicators**: Connection status for each tab

#### Message Area

- **Message History**: Scrollable message history
- **Timestamps**: Optional message timestamps
- **User Colors**: Color-coded nicknames for easy identification
- **Message Types**: Different styling for messages, notices, actions

#### User Input

- **Message Input**: Send messages to the current channel
- **Commands**: Support for IRC commands (e.g., `/join #channel`)
- **Tab Completion**: Auto-complete nicknames and channel names
- **Message History**: Navigate through previously sent messages

#### User List

- **Online Users**: List of users in the current channel
- **User Modes**: Display user modes (@ for operators, + for voiced)
- **Click Actions**: Right-click for user actions (private message, etc.)
- **User Count**: Display total number of users

### IRC Commands

Gamja supports standard IRC commands:

#### Channel Commands
```irc
/join #channel         # Join a channel
/part #channel         # Leave a channel
/topic #channel New topic  # Change channel topic
/mode #channel +m      # Set channel mode
```

#### User Commands
```irc
/nick newnickname      # Change nickname
/msg nickname message  # Send private message
/notice nickname message  # Send notice
/away reason          # Set away status
/back                 # Return from away
```

#### Service Commands
```irc
/nickserv register password email@example.com  # Register nickname
/nickserv identify password                    # Identify with services
/chanserv register #channel                    # Register channel
```

### Keyboard Shortcuts

- **Ctrl+Enter**: Send message
- **Tab**: Auto-complete nicknames/channels
- **↑/↓**: Navigate message history
- **Ctrl+L**: Clear message history
- **Ctrl+/**: Focus input field

## Mobile Experience

### Responsive Design

Gamja is fully responsive and optimized for mobile devices:

- **Touch-friendly Interface**: Large buttons and touch targets
- **Swipe Gestures**: Swipe between channels
- **Mobile Keyboard**: Optimized for mobile keyboards
- **Landscape/Portrait**: Adapts to screen orientation

### Mobile-Specific Features

- **Simplified Layout**: Streamlined interface for small screens
- **Touch Gestures**: Swipe to navigate, tap to interact
- **Push Notifications**: Browser notifications for mentions
- **Battery Optimization**: Reduced background activity

## Advanced Features

### Themes and Customization

#### Built-in Themes

Gamja includes several built-in themes:

- **Light**: Clean, bright theme for daytime use
- **Dark**: Easy on the eyes for low-light environments
- **Auto**: Automatically switches based on system preference

#### Custom Themes

Create custom themes using CSS variables:

```css
:root {
	--background-color: #1a1a1a;
	--text-color: #ffffff;
	--input-background: #2a2a2a;
	--message-hover: #333333;
	--border-color: #444444;
	--link-color: #007bff;
}
```

### OAuth2 Authentication

Gamja supports OAuth2 for user authentication:

1. **Configure OAuth2 provider** in `config.json`
2. **Users authenticate** through the OAuth2 flow
3. **Automatic nickname assignment** based on OAuth2 claims
4. **Session management** with automatic reconnection

### Message History

Gamja maintains message history:

- **Persistent Storage**: Messages stored in browser localStorage
- **Scrollback**: Unlimited scrollback through message history
- **Search**: Search through message history
- **Export**: Export message history for backup

### Connection Management

#### Auto-reconnection

Gamja automatically handles connection issues:

- **Connection Lost**: Automatic reconnection attempts
- **Exponential Backoff**: Increasing delays between retry attempts
- **Connection Status**: Visual indicators for connection state
- **Rejoin Channels**: Automatically rejoin channels after reconnection

#### Multiple Servers

While primarily designed for single-server use, Gamja can be configured for multiple servers:

```json
{
	"servers": [
		{
			"name": "ATL Chat",
			"url": "wss://irc.atl.chat:8000",
			"autojoin": "#welcome"
		},
		{
			"name": "Other Network",
			"url": "wss://irc.other.net:8000",
			"autojoin": "#main"
		}
	]
}
```

## Security Considerations

### Connection Security

- **WebSocket over TLS**: All connections use secure WebSocket (WSS)
- **Certificate Validation**: Validates server certificates
- **No Plaintext**: Never connects to non-TLS IRC servers

### Data Protection

- **Local Storage**: Message history stored locally in browser
- **No Server Logging**: Messages not stored on the server
- **Session Security**: Secure WebSocket connections
- **Input Sanitization**: Prevents XSS attacks

### Privacy Features

- **No Tracking**: No analytics or tracking scripts
- **Local Preferences**: Settings stored locally
- **Incognito Mode**: Works in private browsing
- **Data Export**: Users can export their message history

## Troubleshooting

### Connection Issues

#### Cannot Connect to Server

**Symptoms:**
- "Connection failed" error
- WebSocket connection timeout

**Solutions:**

1. **Check WebSocket URL:**
   ```json
   {
   	"server": {
   		"url": "wss://irc.atl.chat:8000"  // Must be WSS, not WS
   	}
   }
   ```

2. **Verify server configuration:**
   ```bash
   # Check if WebSocket is enabled in UnrealIRCd
   grep -A5 "websocket" src/backend/unrealircd/conf/unrealircd.conf
   ```

3. **Check firewall:**
   ```bash
   # Test port accessibility
   telnet localhost 8000
   ```

4. **Browser compatibility:**
   - Use a modern browser (Chrome 60+, Firefox 55+, Safari 12+)
   - Disable browser extensions that might block WebSockets

#### Authentication Issues

**Symptoms:**
- "Nickname already in use" error
- SASL authentication failure

**Solutions:**

1. **Check SASL configuration:**
   ```bash
   # Verify SASL is enabled in UnrealIRCd
   grep -i sasl src/backend/unrealircd/conf/unrealircd.conf
   ```

2. **Validate credentials:**
   - Ensure username/password are correct
   - Check if account is registered with NickServ

3. **Nickname availability:**
   - Try a different nickname
   - Use `/nick newnickname` to change nickname

### Performance Issues

#### Slow Loading

**Symptoms:**
- Slow initial page load
- Laggy message display

**Solutions:**

1. **Browser cache:**
   - Clear browser cache and cookies
   - Hard refresh (Ctrl+F5)

2. **Network issues:**
   - Check internet connection
   - Try different network

3. **Server performance:**
   ```bash
   # Check server load
   make status
   docker stats unrealircd
   ```

#### High Memory Usage

**Symptoms:**
- Browser becomes slow or unresponsive
- High memory usage in browser task manager

**Solutions:**

1. **Clear message history:**
   ```javascript
   // In browser console
   localStorage.clear();
   ```

2. **Limit scrollback:**
   ```json
   {
   	"maxHistory": 1000
   }
   ```

3. **Close unused tabs:**
   - Close channel tabs you're not using
   - Use `/part #channel` to leave channels

### Mobile Issues

#### Touch Interface Problems

**Symptoms:**
- Buttons not responding to touch
- Interface elements too small

**Solutions:**

1. **Enable touch mode:**
   ```json
   {
   	"touchMode": true
   }
   ```

2. **Zoom level:**
   - Set browser zoom to 100%
   - Use landscape orientation on mobile

3. **Browser settings:**
   - Enable JavaScript
   - Allow popups (for some features)

### Configuration Issues

#### Settings Not Applied

**Symptoms:**
- Configuration changes don't take effect
- Interface shows old settings

**Solutions:**

1. **Clear browser cache:**
   - Hard refresh the page
   - Clear localStorage if needed

2. **Check configuration syntax:**
   ```bash
   # Validate JSON syntax
   python3 -m json.tool conf/config.json
   ```

3. **Reload configuration:**
   - Refresh the page
   - Close and reopen the browser tab

## Development

### Building Gamja

Gamja is built using modern web development tools:

```bash
# Install dependencies
npm install

# Development server
npm run dev

# Build for production
npm run build

# Run tests
npm test
```

### Contributing

Contribute to Gamja development:

1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Test thoroughly**
5. **Submit a pull request**

### Customizing Gamja

#### Adding Custom Themes

Create a new theme file in `themes/`:

```css
/* themes/custom.css */
.gamja-theme-custom {
	--bg-color: #ffffff;
	--text-color: #333333;
	--accent-color: #007bff;
}

/* Custom theme styles */
.gamja-theme-custom .message {
	border-left: 3px solid var(--accent-color);
}
```

#### Extending Functionality

Add custom features using the plugin system:

```javascript
// plugins/custom.js
class CustomPlugin {
	init(gamja) {
		// Add custom commands
		gamja.addCommand('custom', (args) => {
			// Custom command logic
		});

		// Add custom UI elements
		gamja.addButton('Custom', () => {
			// Custom button action
		});
	}
}

// Register plugin
gamja.registerPlugin(new CustomPlugin());
```

## API Reference

### WebSocket Events

Gamja communicates with the IRC server via WebSocket events:

#### Incoming Events

```javascript
// Message received
{
	type: 'message',
	from: 'nickname',
	to: '#channel',
	text: 'Hello world!',
	time: 1640995200000
}

// User joined
{
	type: 'join',
	nick: 'nickname',
	channel: '#channel'
}

// User left
{
	type: 'part',
	nick: 'nickname',
	channel: '#channel',
	reason: 'Goodbye!'
}
```

#### Outgoing Commands

```javascript
// Send message
gamja.send({
	type: 'message',
	target: '#channel',
	text: 'Hello world!'
});

// Join channel
gamja.send({
	type: 'join',
	channel: '#newchannel'
});

// Change nickname
gamja.send({
	type: 'nick',
	nick: 'newnickname'
});
```

### Configuration API

Access and modify configuration programmatically:

```javascript
// Get current configuration
const config = gamja.getConfig();

// Update configuration
gamja.updateConfig({
	theme: 'dark',
	notifications: {
		enabled: true
	}
});

// Save configuration
gamja.saveConfig();
```

## Deployment

### Production Deployment

For production deployment:

1. **Build optimized version:**
   ```bash
   npm run build
   ```

2. **Configure web server:**
   ```nginx
   server {
       listen 80;
       server_name gamja.example.com;

       root /path/to/gamja/dist;
       index index.html;

       location / {
           try_files $uri $uri/ /index.html;
       }

       # Enable gzip compression
       gzip on;
       gzip_types text/css application/javascript application/json;
   }
   ```

3. **SSL configuration:**
   ```nginx
   server {
       listen 443 ssl http2;
       server_name gamja.example.com;

       ssl_certificate /path/to/certificate.pem;
       ssl_certificate_key /path/to/private.key;

       # ... rest of configuration
   }
   ```

### Container Deployment

Use the provided Docker configuration:

```dockerfile
FROM nginx:alpine

# Copy built files
COPY dist/ /usr/share/nginx/html/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
```

## Related Documentation

- [UNREALIRCD.md](UNREALIRCD.md) - IRC server configuration
- [WEBPANEL.md](WEBPANEL.md) - Web administration interface
- [API.md](API.md) - JSON-RPC API documentation
- [DOCKER.md](DOCKER.md) - Container setup
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

## Support

For Gamja support:

- **Documentation**: Check this guide and related docs
- **GitHub Issues**: Report bugs and request features
- **IRC Channel**: Join #help on your IRC network
- **Community**: Check the Gamja project repository