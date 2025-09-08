#!/bin/bash

# Let's Encrypt SSL Certificate Setup for IRC.atl.chat
# This script sets up Let's Encrypt certificates for the IRC server

set -euo pipefail

# Configuration
DOMAIN="irc.atl.chat"
EMAIL="admin@allthingslinux.org"
CERT_DIR="/home/kaizen/dev/allthingslinux/irc.atl.chat/unrealircd/conf/tls"
WEBROOT="/var/www/html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root for security reasons"
fi

# Check if certbot is installed
if ! command -v certbot &>/dev/null; then
    log "Installing certbot..."
    sudo apt update
    sudo apt install -y certbot
fi

# Create webroot directory if it doesn't exist
sudo mkdir -p "$WEBROOT"

# Create certificate directory if it doesn't exist
mkdir -p "$CERT_DIR"

# Generate Let's Encrypt certificate
log "Requesting Let's Encrypt certificate for $DOMAIN..."

if sudo certbot certonly \
    --webroot \
    --webroot-path="$WEBROOT" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --domains "$DOMAIN" \
    --non-interactive; then

    log "Certificate obtained successfully!"

    # Copy certificates to our TLS directory
    log "Copying certificates to $CERT_DIR..."
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/server.cert.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/server.key.pem"

    # Set proper permissions
    sudo chown $USER:$USER "$CERT_DIR/server.cert.pem" "$CERT_DIR/server.key.pem"
    chmod 644 "$CERT_DIR/server.cert.pem"
    chmod 600 "$CERT_DIR/server.key.pem"

    log "Certificates installed successfully!"
    log "Certificate location: $CERT_DIR/server.cert.pem"
    log "Private key location: $CERT_DIR/server.key.pem"

    # Show certificate info
    log "Certificate information:"
    openssl x509 -in "$CERT_DIR/server.cert.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"

else
    error "Failed to obtain Let's Encrypt certificate"
fi

# Create renewal script
log "Creating certificate renewal script..."
cat >"$CERT_DIR/renew-certificates.sh" <<'EOF'
#!/bin/bash

# Certificate renewal script for IRC.atl.chat
set -euo pipefail

DOMAIN="irc.atl.chat"
CERT_DIR="/home/kaizen/dev/allthingslinux/irc.atl.chat/unrealircd/conf/tls"
WEBROOT="/var/www/html"

# Renew certificate
if sudo certbot renew --webroot --webroot-path="$WEBROOT" --quiet; then
    # Copy renewed certificates
    sudo cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_DIR/server.cert.pem"
    sudo cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$CERT_DIR/server.key.pem"
    
    # Set proper permissions
    sudo chown $USER:$USER "$CERT_DIR/server.cert.pem" "$CERT_DIR/server.key.pem"
    chmod 644 "$CERT_DIR/server.cert.pem"
    chmod 600 "$CERT_DIR/server.key.pem"
    
    # Reload UnrealIRCd if running
    if docker-compose ps ircd | grep -q "Up"; then
        echo "Reloading UnrealIRCd configuration..."
        docker-compose exec ircd /usr/local/unrealircd/bin/unrealircd rehash
    fi
    
    echo "Certificate renewed successfully!"
else
    echo "Certificate renewal failed!"
    exit 1
fi
EOF

chmod +x "$CERT_DIR/renew-certificates.sh"

# Set up cron job for automatic renewal
log "Setting up automatic certificate renewal..."
(
    crontab -l 2>/dev/null
    echo "0 12 * * * $CERT_DIR/renew-certificates.sh >> /var/log/letsencrypt-renewal.log 2>&1"
) | crontab -

log "Setup complete!"
log "Certificate will be automatically renewed via cron job"
log "Manual renewal: $CERT_DIR/renew-certificates.sh"
