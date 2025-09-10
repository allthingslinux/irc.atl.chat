# SSL Setup - Simple & Automatic! 🎉

## What You Get

✅ **One-command setup**: `make ssl-setup`
✅ **Automatic renewal**: Every day at 2 AM
✅ **Docker-based monitoring**: No host cron jobs needed
✅ **Zero maintenance**: Just works forever

## Quick Start (3 Steps)

```bash
# 1. Setup credentials
cp cloudflare-credentials.ini.template cloudflare-credentials.ini
vim cloudflare-credentials.ini  # Add your API token

# 2. Set your domain in .env (already there)
echo "IRC_ROOT_DOMAIN=yourdomain.com" >> .env

# 3. One command does everything
make ssl-setup
```

## Everyday Usage

```bash
# Check if SSL is working
make ssl-status

# View monitoring logs
make ssl-logs
```

## How It Works

The `ssl-monitor` container runs **automatically** (don't manually start/stop it):

1. **Checks certificates** every 4 hours
2. **Renews automatically** at 2 AM when certificates expire soon
3. **Restarts services** after renewal
4. **Logs everything** to Docker logs

## Files Involved

- `compose.yaml`: Has the ssl-monitor container
- `scripts/ssl-manager.sh`: The simple SSL script
- `unrealircd/conf/tls/`: Where certificates are stored
- `data/letsencrypt/`: Let's Encrypt data

## Environment Variables Used

From your `.env` file:
- `IRC_ROOT_DOMAIN`: Your domain (e.g., `irc.atl.chat`) - **already defined above**
- `LETSENCRYPT_EMAIL`: Your email for Let's Encrypt - **only SSL variable needed**

## Commands Available

```bash
make ssl-setup     # One-time setup
make ssl-status    # Check status
make ssl-logs      # View logs
make ssl-renew     # Force renewal
```

## That's It!

No complex configuration, no host cron jobs, no manual management.
SSL certificates are now completely automatic and Docker-based. 🚀
