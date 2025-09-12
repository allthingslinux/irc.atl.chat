# Secret Management

## 🎯 **Single Source of Truth**

**Everything is managed through `.env`** - one file, one system, done.

## 📁 **File Structure**

```
.env                          # 🔑 Single source of truth for all secrets
src/backend/unrealircd/conf/
├── unrealircd.conf.template  # 📋 Template with ${VARIABLE} syntax
└── unrealircd.conf           # ⚙️  Generated configuration
scripts/
└── prepare-config.sh         # 🔧 Substitutes variables from .env
```

## 🔑 **How It Works**

1. **Set secrets in `.env`**:
   ```bash
   IRC_DOMAIN=irc.atl.chat
   IRC_SERVICES_PASSWORD=test1234
   IRC_OPER_PASSWORD='$argon2id$v=19$m=6144,t=2,p=2$...'
   ```

2. **Template uses variables**:
   ```conf
   me {
       name "${IRC_DOMAIN}";
   }
   password "${IRC_SERVICES_PASSWORD}";
   ```

3. **Script substitutes variables**:
   ```bash
   ./scripts/prepare-config.sh
   ```

4. **Generated config**:
   ```conf
   me {
       name "irc.atl.chat";
   }
   password "test1234";
   ```

## ✅ **Benefits**

- **Simple**: One file for all secrets
- **Secure**: `.env` is gitignored
- **Clear**: Easy to understand and maintain
- **Flexible**: Easy to change any value
- **Standard**: Uses common environment variable approach

## 🚀 **Usage**

```bash
# 1. Edit secrets
vim .env

# 2. Generate configuration
./scripts/prepare-config.sh

# 3. Start server
docker compose up unrealircd
```

## 🔧 **Available Variables**

### **Core Configuration**
- `IRC_DOMAIN` - IRC server domain
- `IRC_NETWORK_NAME` - Network name
- `IRC_CLOAK_PREFIX` - Hostname cloaking prefix
- `IRC_ADMIN_NAME` - Administrator name
- `IRC_ADMIN_EMAIL` - Administrator email
- `IRC_SERVICES_SERVER` - Services server hostname

### **Secrets**
- `IRC_OPER_PASSWORD` - IRC operator password hash
- `IRC_SERVICES_PASSWORD` - Services link password
- `WEBPANEL_RPC_USER` - Webpanel username
- `WEBPANEL_RPC_PASSWORD` - Webpanel password
- `IRC_DB_PASSWORD` - Database password (if used)

### **SSL/TLS**
- `IRC_SSL_CERT_PATH` - SSL certificate path
- `IRC_SSL_KEY_PATH` - SSL key path

### **Atheme Services**
- `ATHEME_SERVER_NAME` - Services server name
- `ATHEME_SERVER_DESC` - Services server description
- `ATHEME_UPLINK_HOST` - IRC server hostname/IP
- `ATHEME_UPLINK_PORT` - IRC server port
- `ATHEME_SEND_PASSWORD` - Password sent to IRC server
- `ATHEME_RECEIVE_PASSWORD` - Password received from IRC server
- `ATHEME_HELP_CHANNEL` - Help channel for users
- `ATHEME_HELP_URL` - Help website URL

### **Webpanel**
- `WEBPANEL_RPC_USER` - RPC username for webpanel
- `WEBPANEL_RPC_PASSWORD` - RPC password for webpanel

## 📝 **Making Configuration Changes**

### **✅ DO: Edit the Template**
```bash
# Edit the template file
vim src/backend/unrealircd/conf/unrealircd.conf.template

# Add new settings
loadmodule "newmodule";
set {
    new-setting "value";
}
```

### **❌ DON'T: Edit the Generated Config**
```bash
# DON'T edit this file - it gets overwritten!
vim src/backend/unrealircd/conf/unrealircd.conf
```

### **🔄 Workflow for Changes**
```bash
# 1. Edit template
vim src/backend/unrealircd/conf/unrealircd.conf.template

# 2. Regenerate config
./scripts/prepare-config.sh

# 3. Test changes
docker compose up unrealircd
```

## 🔐 **Security Best Practices**

1. **Never commit `.env`** - It's gitignored for a reason
2. **Use strong passwords** - Generate secure operator passwords
3. **Rotate secrets regularly** - Change passwords periodically
4. **Test configurations** - Validate before deploying
5. **Backup secrets securely** - Not in git repositories

## 🛠️ **Troubleshooting**

### **Configuration Not Updating**
```bash
# Check if template exists
ls -la src/backend/unrealircd/conf/unrealircd.conf.template

# Regenerate config
./scripts/prepare-config.sh

# Check if variables are substituted
grep -n '\${' src/backend/unrealircd/conf/unrealircd.conf
```

### **Missing Environment Variables**
```bash
# Check .env file
cat .env

# Verify variables are loaded
./scripts/prepare-config.sh
```

### **Template vs Generated Config**
```bash
# Template (has variables)
grep "IRC_DOMAIN" src/backend/unrealircd/conf/unrealircd.conf.template

# Generated config (has values)
grep "irc.atl.chat" src/backend/unrealircd/conf/unrealircd.conf
```

## 🎯 **Summary**

- **One file**: `.env` contains all secrets
- **One script**: `prepare-config.sh` substitutes variables
- **One template**: `unrealircd.conf.template` uses `${VARIABLE}` syntax
- **One result**: Clean, generated configuration

**Always edit the template, never the generated config!** 🎉