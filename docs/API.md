# IRC.atl.chat APIs

This guide covers the programmatic interfaces available for IRC.atl.chat, including the JSON-RPC API for server management and WebSocket support for real-time IRC connectivity.

## Overview

### Available APIs

IRC.atl.chat provides several APIs for different use cases:

1. **JSON-RPC API** - Server administration and monitoring
2. **WebSocket API** - Real-time IRC client connections
3. **REST API** (WebPanel) - Web interface operations

### API Endpoints

```
JSON-RPC API:    unrealircd:8600    (internal)
WebSocket API:   unrealircd:8000    (external)
WebPanel API:    webpanel:8080/api  (internal)
```

### Authentication

#### JSON-RPC Authentication
```json
{
    "jsonrpc": "2.0",
    "method": "auth.login",
    "params": {
        "username": "rpcuser",
        "password": "rpcpassword"
    },
    "id": 1
}
```

#### WebSocket Authentication
WebSocket connections use standard IRC authentication:
```
NICK yournick
USER username 0 * :Real Name
```

## JSON-RPC API

### Connection Setup

The JSON-RPC API allows programmatic control of the IRC server:

#### HTTP Connection
```python
import requests
import json

class UnrealIRCRPC:
    def __init__(self, host='localhost', port=8600, user='admin', password='password'):
        self.url = f'http://{host}:{port}/api'
        self.auth = (user, password)

    def call(self, method, params=None):
        payload = {
            'jsonrpc': '2.0',
            'method': method,
            'params': params or {},
            'id': self._next_id()
        }

        response = requests.post(self.url, json=payload, auth=self.auth)
        return response.json()
```

#### Python Library Usage
```python
rpc = UnrealIRCRPC('localhost', 8600, 'rpcuser', 'rpcpass')

# Get server information
result = rpc.call('server.info')
print(f"Server: {result['name']} ({result['version']})")
```

### Core API Methods

#### Server Information

**server.info**
Get basic server information.

```json
{
    "jsonrpc": "2.0",
    "method": "server.info",
    "params": {},
    "id": 1
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "name": "irc.atl.chat",
        "description": "All Things Linux IRC Server",
        "version": "6.2.0.1",
        "uptime": 86400,
        "boot_time": 1640995200,
        "online_users": 150,
        "online_channels": 25,
        "online_servers": 1
    },
    "id": 1
}
```

**server.stats**
Get detailed server statistics.

```json
{
    "jsonrpc": "2.0",
    "method": "server.stats",
    "params": {},
    "id": 2
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "connections": {
            "total": 15420,
            "current": 150,
            "max": 200
        },
        "traffic": {
            "bytes_in": 1024000,
            "bytes_out": 2048000
        },
        "commands": {
            "privmsg": 5000,
            "join": 1000,
            "part": 800
        }
    },
    "id": 2
}
```

#### User Management

**user.list**
List online users with pagination.

```json
{
    "jsonrpc": "2.0",
    "method": "user.list",
    "params": {
        "limit": 50,
        "offset": 0,
        "filter": {
            "channel": "#help"
        }
    },
    "id": 3
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "users": [
            {
                "nickname": "user1",
                "username": "user",
                "hostname": "host.example.com",
                "realname": "User One",
                "modes": "+i",
                "channels": ["#help", "#general"],
                "connected_at": 1640995200,
                "idle_time": 300
            }
        ],
        "total": 150,
        "limit": 50,
        "offset": 0
    },
    "id": 3
}
```

**user.get**
Get detailed information about a specific user.

```json
{
    "jsonrpc": "2.0",
    "method": "user.get",
    "params": {
        "nickname": "user1"
    },
    "id": 4
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "nickname": "user1",
        "username": "user",
        "hostname": "host.example.com",
        "realname": "User One",
        "modes": "+i",
        "account": "user1",
        "ip": "192.168.1.100",
        "connected_at": 1640995200,
        "idle_time": 300,
        "away": false,
        "away_message": null
    },
    "id": 4
}
```

**user.action**
Perform actions on users.

```json
{
    "jsonrpc": "2.0",
    "method": "user.action",
    "params": {
        "action": "kill",
        "target": "baduser",
        "reason": "Violation of network rules"
    },
    "id": 5
}

Actions:
- "kill" - Disconnect user
- "kline" - Ban user by hostname
- "gline" - Global ban
- "shun" - Silence user
```

#### Channel Management

**channel.list**
List active channels.

```json
{
    "jsonrpc": "2.0",
    "method": "channel.list",
    "params": {
        "limit": 25,
        "offset": 0,
        "filter": {
            "min_users": 5
        }
    },
    "id": 6
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "channels": [
            {
                "name": "#help",
                "topic": "Welcome to #help | Please ask your questions",
                "topic_set_by": "helper",
                "topic_set_at": 1640995000,
                "user_count": 15,
                "modes": "+nt",
                "created_at": 1640994000
            }
        ],
        "total": 25
    },
    "id": 6
}
```

**channel.get**
Get detailed channel information.

```json
{
    "jsonrpc": "2.0",
    "method": "channel.get",
    "params": {
        "name": "#help"
    },
    "id": 7
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "name": "#help",
        "topic": "Welcome to #help",
        "topic_set_by": "helper",
        "topic_set_at": 1640995000,
        "modes": "+nt",
        "key": null,
        "limit": null,
        "created_at": 1640994000,
        "users": [
            {
                "nickname": "helper",
                "modes": "@"  // @ = op, + = voice, % = halfop
            }
        ]
    },
    "id": 7
}
```

**channel.action**
Perform channel actions.

```json
{
    "jsonrpc": "2.0",
    "method": "channel.action",
    "params": {
        "action": "mode",
        "channel": "#help",
        "mode": "+m",
        "reason": "Enabling moderated mode"
    },
    "id": 8
}

Actions:
- "mode" - Change channel modes
- "topic" - Change channel topic
- "kick" - Kick user from channel
- "ban" - Ban user from channel
```

#### Ban Management

**ban.list**
List active bans.

```json
{
    "jsonrpc": "2.0",
    "method": "ban.list",
    "params": {
        "type": "kline",  // kline, gline, zline, shun, spamfilter
        "limit": 50
    },
    "id": 9
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "bans": [
            {
                "type": "kline",
                "mask": "*@bad.host.com",
                "reason": "Spam",
                "operator": "admin",
                "set_at": 1640995000,
                "expires_at": 1641081400,
                "duration": 86400
            }
        ],
        "total": 15
    },
    "id": 9
}
```

**ban.add**
Add a new ban.

```json
{
    "jsonrpc": "2.0",
    "method": "ban.add",
    "params": {
        "type": "kline",
        "mask": "*@bad.host.com",
        "reason": "Spamming",
        "duration": "24h"
    },
    "id": 10
}

Duration formats:
- "30m" - 30 minutes
- "2h" - 2 hours
- "7d" - 7 days
- "permanent" - no expiration
```

**ban.remove**
Remove a ban.

```json
{
    "jsonrpc": "2.0",
    "method": "ban.remove",
    "params": {
        "type": "kline",
        "mask": "*@bad.host.com"
    },
    "id": 11
}
```

#### Server Control

**server.command**
Execute raw IRC server commands.

```json
{
    "jsonrpc": "2.0",
    "method": "server.command",
    "params": {
        "command": "REHASH",
        "reason": "Reloading configuration"
    },
    "id": 12
}

Common commands:
- "REHASH" - Reload configuration
- "RESTART" - Restart server
- "DIE" - Shutdown server
- "MODULE LOAD modulename" - Load module
- "MODULE UNLOAD modulename" - Unload module
```

**server.module_list**
List loaded modules.

```json
{
    "jsonrpc": "2.0",
    "method": "server.module_list",
    "params": {},
    "id": 13
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "modules": [
            {
                "name": "cloak_sha256",
                "version": "1.0",
                "description": "Hostname cloaking",
                "loaded": true
            }
        ]
    },
    "id": 13
}
```

### Advanced API Methods

#### Log Management

**log.get**
Retrieve log entries.

```json
{
    "jsonrpc": "2.0",
    "method": "log.get",
    "params": {
        "lines": 100,
        "filter": {
            "level": "error",
            "source": "user"
        }
    },
    "id": 14
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "entries": [
            {
                "timestamp": 1640995200,
                "level": "error",
                "source": "user",
                "message": "Bad password for user 'baduser'"
            }
        ]
    },
    "id": 14
}
```

#### Configuration Management

**config.get**
Get current configuration values.

```json
{
    "jsonrpc": "2.0",
    "method": "config.get",
    "params": {
        "section": "set",
        "key": "modes-on-connect"
    },
    "id": 15
}

Response:
{
    "jsonrpc": "2.0",
    "result": {
        "section": "set",
        "key": "modes-on-connect",
        "value": "+ixw"
    },
    "id": 15
}
```

**config.set**
Modify configuration (requires rehash).

```json
{
    "jsonrpc": "2.0",
    "method": "config.set",
    "params": {
        "section": "set",
        "key": "modes-on-connect",
        "value": "+ixwR"
    },
    "id": 16
}
```

## WebSocket API

### Connection Setup

WebSocket provides real-time IRC connectivity for clients:

#### JavaScript Connection
```javascript
// Connect to WebSocket
const ws = new WebSocket('wss://irc.atl.chat:8000');

// Handle connection open
ws.onopen = function(event) {
    console.log('Connected to IRC server');

    // Send IRC commands
    ws.send('NICK mynickname\r\n');
    ws.send('USER mynick 0 * :Real Name\r\n');
};

// Handle incoming messages
ws.onmessage = function(event) {
    const message = event.data;
    console.log('Received:', message);

    // Parse IRC message
    const ircMessage = parseIRCMessage(message);
    handleIRCMessage(ircMessage);
};

// Handle connection close
ws.onclose = function(event) {
    console.log('Disconnected from IRC server');
    // Attempt reconnection
    setTimeout(connect, 5000);
};
```

#### Python Connection
```python
import websocket
import threading
import time

class IRCWebSocketClient:
    def __init__(self, host='irc.atl.chat', port=8000, nickname='websocket_user'):
        self.host = host
        self.port = port
        self.nickname = nickname
        self.ws = None
        self.connected = False

    def connect(self):
        websocket.enableTrace(True)
        self.ws = websocket.WebSocketApp(
            f'wss://{self.host}:{self.port}',
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close,
            on_open=self.on_open
        )

        # Start WebSocket in a thread
        wst = threading.Thread(target=self.ws.run_forever)
        wst.daemon = True
        wst.start()

    def on_open(self, ws):
        self.connected = True
        print("Connected to IRC server")

        # Send IRC registration
        self.send(f'NICK {self.nickname}')
        self.send('USER websocket 0 * :WebSocket IRC Client')

    def on_message(self, ws, message):
        print(f"Received: {message}")
        self.handle_irc_message(message)

    def on_error(self, ws, error):
        print(f"Error: {error}")

    def on_close(self, ws, close_status_code, close_msg):
        self.connected = False
        print("Disconnected from IRC server")

    def send(self, message):
        if self.ws and self.connected:
            self.ws.send(message + '\r\n')

    def handle_irc_message(self, message):
        # Parse IRC message and handle appropriately
        if message.startswith('PING'):
            self.send('PONG ' + message.split()[1])
        elif '001' in message:  # Welcome message
            self.send('JOIN #testchannel')
        # Handle other IRC messages...
```

### IRC Protocol over WebSocket

WebSocket connections use standard IRC protocol:

#### Connection Handshake
```
Client → Server: NICK websocket_user
Client → Server: USER websocket 0 * :WebSocket Client
Server → Client: :irc.atl.chat 001 websocket_user :Welcome to IRC.atl.chat
```

#### Channel Operations
```
Client → Server: JOIN #channel
Server → Client: :websocket_user!websocket@localhost JOIN #channel
Server → Client: :irc.atl.chat 353 websocket_user = #channel :@operator +voiceuser normaluser
Server → Client: :irc.atl.chat 366 websocket_user #channel :End of /NAMES list
```

#### Message Exchange
```
Client → Server: PRIVMSG #channel :Hello everyone!
Server → Client: :websocket_user!websocket@localhost PRIVMSG #channel :Hello everyone!
```

#### Ping/Pong (Keepalive)
```
Server → Client: PING :irc.atl.chat
Client → Server: PONG :irc.atl.chat
```

### Message Parsing

#### IRC Message Format
IRC messages follow the format:
```
:prefix command parameters :trailing
```

#### JavaScript Parser
```javascript
function parseIRCMessage(rawMessage) {
    const message = {
        raw: rawMessage,
        prefix: null,
        command: null,
        params: [],
        trailing: null
    };

    let msg = rawMessage.trim();

    // Parse prefix
    if (msg.startsWith(':')) {
        const prefixEnd = msg.indexOf(' ');
        message.prefix = msg.substring(1, prefixEnd);
        msg = msg.substring(prefixEnd + 1);
    }

    // Parse command
    const commandEnd = msg.indexOf(' ');
    if (commandEnd === -1) {
        message.command = msg;
        return message;
    }

    message.command = msg.substring(0, commandEnd);
    msg = msg.substring(commandEnd + 1);

    // Parse parameters and trailing
    if (msg.startsWith(':')) {
        message.trailing = msg.substring(1);
    } else {
        const parts = msg.split(' ');
        const trailingIndex = parts.findIndex(part => part.startsWith(':'));

        if (trailingIndex !== -1) {
            message.params = parts.slice(0, trailingIndex);
            message.trailing = parts.slice(trailingIndex).join(' ').substring(1);
        } else {
            message.params = parts;
        }
    }

    return message;
}

// Example usage
const msg = parseIRCMessage(':user!host@server PRIVMSG #channel :Hello world!');
console.log(msg.command);  // 'PRIVMSG'
console.log(msg.params);   // ['#channel']
console.log(msg.trailing); // 'Hello world!'
```

#### Python Parser
```python
import re

class IRCMessage:
    def __init__(self, raw_message):
        self.raw = raw_message
        self.prefix = None
        self.command = None
        self.params = []
        self.trailing = None

        self._parse(raw_message)

    def _parse(self, message):
        message = message.strip()

        # Parse prefix
        if message.startswith(':'):
            prefix_end = message.find(' ')
            if prefix_end != -1:
                self.prefix = message[1:prefix_end]
                message = message[prefix_end + 1:]

        # Parse command
        command_end = message.find(' ')
        if command_end == -1:
            self.command = message
            return

        self.command = message[:command_end]
        message = message[command_end + 1:]

        # Parse parameters and trailing
        if message.startswith(':'):
            self.trailing = message[1:]
        else:
            parts = message.split()
            trailing_start = -1

            for i, part in enumerate(parts):
                if part.startswith(':'):
                    trailing_start = i
                    break

            if trailing_start != -1:
                self.params = parts[:trailing_start]
                self.trailing = ' '.join(parts[trailing_start:])[1:]
            else:
                self.params = parts

# Example usage
msg = IRCMessage(':user!host PRIVMSG #channel :Hello world!')
print(msg.command)  # 'PRIVMSG'
print(msg.params)   # ['#channel']
print(msg.trailing) # 'Hello world!'
```

### WebSocket Events

#### Connection Events

**Open Event**
```javascript
ws.onopen = function(event) {
    console.log('WebSocket connection established');
    // Start IRC handshake
    ws.send('NICK mynick\r\n');
    ws.send('USER mynick 0 * :Real Name\r\n');
};
```

**Close Event**
```javascript
ws.onclose = function(event) {
    console.log('WebSocket connection closed');
    console.log('Code:', event.code);
    console.log('Reason:', event.reason);

    // Attempt reconnection with exponential backoff
    setTimeout(() => connect(), 1000 * Math.pow(2, reconnectAttempts++));
};
```

**Error Event**
```javascript
ws.onerror = function(event) {
    console.error('WebSocket error:', event);
    // Handle connection errors
};
```

#### Message Events

**IRC Message Handling**
```javascript
function handleIRCMessage(message) {
    switch(message.command) {
        case '001':  // Welcome
            console.log('Connected to IRC server');
            // Join channels
            ws.send('JOIN #welcome,#help\r\n');
            break;

        case 'PRIVMSG':
            const target = message.params[0];
            const text = message.trailing;
            console.log(`${message.prefix} -> ${target}: ${text}`);
            break;

        case 'PING':
            // Respond to ping
            ws.send(`PONG ${message.trailing}\r\n`);
            break;

        case 'JOIN':
            const channel = message.params[0];
            console.log(`${message.prefix} joined ${channel}`);
            break;

        case 'PART':
            console.log(`${message.prefix} left ${message.params[0]}`);
            break;

        case 'QUIT':
            console.log(`${message.prefix} quit: ${message.trailing}`);
            break;

        default:
            console.log('Unhandled command:', message.command);
    }
}
```

### Advanced WebSocket Features

#### SASL Authentication
```javascript
// Request SASL capability
ws.send('CAP REQ :sasl\r\n');

// Start SASL authentication
ws.send('AUTHENTICATE PLAIN\r\n');

// Send credentials (base64 encoded)
const authString = btoa('\0' + username + '\0' + password);
ws.send(`AUTHENTICATE ${authString}\r\n`);

// End SASL
ws.send('CAP END\r\n');
```

#### IRCv3 Capabilities
```javascript
// Request IRCv3 capabilities
ws.send('CAP LS 302\r\n');

// Enable capabilities
ws.send('CAP REQ :echo-message sasl\r\n');

// End capability negotiation
ws.send('CAP END\r\n');
```

#### Message Tagging
```javascript
// IRCv3 message tags
ws.send('@time=2023-01-01T12:00:00.000Z PRIVMSG #channel :Hello\r\n');
```

## API Libraries and SDKs

### Official Libraries

#### Python SDK
```python
from unrealircd_rpc import UnrealIRCRPC

# Initialize client
rpc = UnrealIRCRPC(
    host='localhost',
    port=8600,
    username='rpcuser',
    password='rpcpass'
)

# Get server info
server_info = rpc.server_info()
print(f"Connected to {server_info['name']}")

# List users
users = rpc.user_list(limit=10)
for user in users['users']:
    print(f"- {user['nickname']} ({user['realname']})")
```

#### JavaScript SDK
```javascript
import { UnrealIRCWebSocket } from 'unrealircd-websocket';

const client = new UnrealIRCWebSocket({
    host: 'irc.atl.chat',
    port: 8000,
    nickname: 'mybot',
    username: 'bot'
});

client.on('connected', () => {
    console.log('Connected to IRC');
    client.join('#channel');
});

client.on('message', (message) => {
    console.log(`${message.from}: ${message.text}`);
});

client.connect();
```

### Community Libraries

#### Go Client
```go
package main

import (
    "github.com/unrealircd/go-rpc"
    "log"
)

func main() {
    client := rpc.NewClient("localhost:8600", "rpcuser", "rpcpass")

    serverInfo, err := client.ServerInfo()
    if err != nil {
        log.Fatal(err)
    }

    log.Printf("Connected to %s (%s)", serverInfo.Name, serverInfo.Version)
}
```

#### PHP Client
```php
<?php
require 'vendor/autoload.php';

use UnrealIRCd\RPC\Client;

$client = new Client('localhost', 8600, 'rpcuser', 'rpcpass');

try {
    $serverInfo = $client->serverInfo();
    echo "Connected to {$serverInfo['name']}\n";

    $users = $client->userList(['limit' => 10]);
    foreach ($users['users'] as $user) {
        echo "- {$user['nickname']}\n";
    }
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
```

## Error Handling

### JSON-RPC Errors

#### Standard Error Responses
```json
{
    "jsonrpc": "2.0",
    "error": {
        "code": -32601,
        "message": "Method not found",
        "data": {
            "method": "nonexistent.method"
        }
    },
    "id": 1
}
```

#### Common Error Codes
```json
// Authentication errors
{"code": -32000, "message": "Authentication failed"}
{"code": -32001, "message": "Insufficient permissions"}

// Validation errors
{"code": -32002, "message": "Invalid parameters"}
{"code": -32003, "message": "Resource not found"}

// Server errors
{"code": -32004, "message": "Internal server error"}
{"code": -32005, "message": "Service unavailable"}
```

### WebSocket Errors

#### Connection Errors
```javascript
ws.onerror = function(event) {
    switch(event.code) {
        case 1006:  // Abnormal closure
            console.error('Connection lost unexpectedly');
            break;
        case 1011:  // Internal server error
            console.error('Server error occurred');
            break;
        default:
            console.error('WebSocket error:', event.code);
    }
};
```

#### IRC Error Codes
```javascript
// Handle IRC numeric replies
function handleNumericReply(code, message) {
    switch(code) {
        case '401':  // ERR_NOSUCHNICK
            console.error('User not found:', message);
            break;
        case '403':  // ERR_NOSUCHCHANNEL
            console.error('Channel not found:', message);
            break;
        case '433':  // ERR_NICKNAMEINUSE
            console.error('Nickname already in use');
            break;
        case '464':  // ERR_PASSWDMISMATCH
            console.error('Password incorrect');
            break;
        default:
            console.log(`IRC ${code}: ${message}`);
    }
}
```

## Security Considerations

### API Security

#### Authentication
- Use strong RPC credentials
- Implement proper session management
- Enable HTTPS for WebSocket connections
- Validate all input parameters

#### Authorization
- Implement role-based access control
- Limit API rate limits
- Audit all API calls
- Use secure random tokens

### WebSocket Security

#### Connection Security
- Always use WSS (WebSocket Secure)
- Validate server certificates
- Implement proper origin checking
- Use secure random nicknames for anonymous users

#### Message Validation
- Sanitize all user input
- Validate IRC command formats
- Prevent command injection
- Rate limit connections and messages

## Rate Limiting

### API Rate Limits

```json
// Rate limit headers in responses
{
    "X-RateLimit-Limit": "100",
    "X-RateLimit-Remaining": "95",
    "X-RateLimit-Reset": "1640995260"
}
```

### WebSocket Rate Limits

- **Connection rate**: 10 connections per minute per IP
- **Message rate**: 100 messages per minute per user
- **Command rate**: 50 commands per minute per user

## Best Practices

### API Usage

1. **Use persistent connections** for JSON-RPC when possible
2. **Implement proper error handling** for all API calls
3. **Cache responses** when appropriate
4. **Use batch requests** for multiple operations
5. **Monitor API usage** and implement alerting

### WebSocket Usage

1. **Implement reconnection logic** with exponential backoff
2. **Handle all IRC numeric replies** appropriately
3. **Use SASL authentication** when available
4. **Implement message queuing** for offline scenarios
5. **Monitor connection health** and reconnect automatically

### Performance Optimization

1. **Use compression** for WebSocket connections
2. **Implement message batching** for high-volume scenarios
3. **Cache frequently accessed data** (user lists, channel info)
4. **Use efficient data structures** for message parsing
5. **Monitor memory usage** and implement cleanup routines

## Examples and Tutorials

### Complete IRC Bot

```python
import websocket
import json
import time
import threading

class IRCBot:
    def __init__(self, server='irc.atl.chat', port=8000, nickname='mybot'):
        self.server = server
        self.port = port
        self.nickname = nickname
        self.ws = None
        self.connected = False

    def connect(self):
        self.ws = websocket.WebSocketApp(
            f'wss://{self.server}:{self.port}',
            on_open=self.on_open,
            on_message=self.on_message,
            on_error=self.on_error,
            on_close=self.on_close
        )

        # Start in thread
        threading.Thread(target=self.ws.run_forever, daemon=True).start()

    def on_open(self, ws):
        self.connected = True
        print("Connected to IRC server")

        # Register with server
        self.send(f'NICK {self.nickname}')
        self.send('USER bot 0 * :IRC Bot')

    def on_message(self, ws, message):
        print(f"Raw message: {message}")

        # Parse IRC message
        irc_msg = self.parse_irc_message(message)

        if irc_msg['command'] == '001':  # Welcome
            self.send('JOIN #test')
            self.send('PRIVMSG #test :Hello! I am a bot.')

        elif irc_msg['command'] == 'PRIVMSG':
            target = irc_msg['params'][0]
            text = irc_msg.get('trailing', '')

            if text.startswith('!hello'):
                self.send(f'PRIVMSG {target} :Hello {irc_msg["prefix"].split("!")[0]}!')

            elif text.startswith('!time'):
                import datetime
                now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                self.send(f'PRIVMSG {target} :Current time: {now}')

    def on_error(self, ws, error):
        print(f"Error: {error}")

    def on_close(self, ws, close_status_code, close_msg):
        self.connected = False
        print("Disconnected")

        # Reconnect after 5 seconds
        time.sleep(5)
        if not self.connected:
            self.connect()

    def send(self, message):
        if self.ws and self.connected:
            self.ws.send(message + '\r\n')

    def parse_irc_message(self, message):
        msg = {'raw': message}

        if message.startswith(':'):
            prefix_end = message.find(' ')
            msg['prefix'] = message[1:prefix_end]
            message = message[prefix_end + 1:]

        space_pos = message.find(' ')
        if space_pos == -1:
            msg['command'] = message
            return msg

        msg['command'] = message[:space_pos]
        message = message[space_pos + 1:]

        if message.startswith(':'):
            msg['trailing'] = message[1:]
        else:
            parts = message.split(' ')
            colon_pos = -1
            for i, part in enumerate(parts):
                if part.startswith(':'):
                    colon_pos = i
                    break

            if colon_pos != -1:
                msg['params'] = parts[:colon_pos]
                msg['trailing'] = ' '.join(parts[colon_pos:])[1:]
            else:
                msg['params'] = parts

        return msg

# Usage
if __name__ == '__main__':
    bot = IRCBot()
    bot.connect()

    # Keep running
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Shutting down...")
```

### Web Dashboard

```javascript
class IRCDashboard {
    constructor() {
        this.ws = null;
        this.rpc = null;
        this.connected = false;
    }

    async init() {
        await this.connectRPC();
        this.connectWebSocket();
        this.setupUI();
    }

    async connectRPC() {
        this.rpc = new UnrealIRCRPC('localhost', 8600, 'rpcuser', 'rpcpass');
        try {
            const serverInfo = await this.rpc.call('server.info');
            this.updateServerInfo(serverInfo);
        } catch (error) {
            console.error('RPC connection failed:', error);
        }
    }

    connectWebSocket() {
        this.ws = new WebSocket('wss://irc.atl.chat:8000');

        this.ws.onopen = () => {
            this.connected = true;
            this.ws.send('NICK dashboard\r\n');
            this.ws.send('USER dashboard 0 * :Dashboard Client\r\n');
        };

        this.ws.onmessage = (event) => {
            this.handleIRCMessage(event.data);
        };

        this.ws.onclose = () => {
            this.connected = false;
            setTimeout(() => this.connectWebSocket(), 5000);
        };
    }

    handleIRCMessage(message) {
        const ircMsg = parseIRCMessage(message);

        switch(ircMsg.command) {
            case '001':
                this.ws.send('JOIN #dashboard\r\n');
                break;
            case 'PRIVMSG':
                this.addMessage(ircMsg);
                break;
            case 'JOIN':
                this.updateUserList();
                break;
        }
    }

    async updateServerInfo(info) {
        document.getElementById('server-name').textContent = info.name;
        document.getElementById('server-version').textContent = info.version;
        document.getElementById('user-count').textContent = info.online_users;
    }

    async updateUserList() {
        try {
            const users = await this.rpc.call('user.list', { limit: 50 });
            this.renderUserList(users.users);
        } catch (error) {
            console.error('Failed to get user list:', error);
        }
    }

    renderUserList(users) {
        const userList = document.getElementById('user-list');
        userList.innerHTML = '';

        users.forEach(user => {
            const li = document.createElement('li');
            li.textContent = user.nickname;
            li.className = user.modes.includes('o') ? 'operator' : '';
            userList.appendChild(li);
        });
    }

    addMessage(ircMsg) {
        const messageDiv = document.createElement('div');
        messageDiv.className = 'message';

        const timestamp = new Date().toLocaleTimeString();
        const nick = ircMsg.prefix.split('!')[0];
        const text = ircMsg.trailing;

        messageDiv.innerHTML = `
            <span class="timestamp">${timestamp}</span>
            <span class="nick">${nick}:</span>
            <span class="text">${text}</span>
        `;

        document.getElementById('messages').appendChild(messageDiv);
        messageDiv.scrollIntoView();
    }

    setupUI() {
        // Refresh buttons
        document.getElementById('refresh-users').onclick = () => this.updateUserList();

        // Send message
        document.getElementById('send-message').onclick = () => {
            const input = document.getElementById('message-input');
            const message = input.value.trim();
            if (message) {
                this.ws.send(`PRIVMSG #dashboard :${message}\r\n`);
                input.value = '';
            }
        };
    }
}

// Initialize dashboard
document.addEventListener('DOMContentLoaded', () => {
    const dashboard = new IRCDashboard();
    dashboard.init();
});
```

## Related Documentation

- [UNREALIRCD.md](UNREALIRCD.md) - IRC server configuration
- [WEBPANEL.md](WEBPANEL.md) - Web administration interface
- [GAMJA.md](GAMJA.md) - Web IRC client
- [TESTING.md](TESTING.md) - API testing and validation
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - API troubleshooting