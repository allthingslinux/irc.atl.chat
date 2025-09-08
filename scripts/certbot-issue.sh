#!/bin/bash

# ============================================================================
# CERTBOT CERTIFICATE ISSUANCE SCRIPT
# ============================================================================
# Issues SSL certificates using Cloudflare DNS challenge
# ============================================================================

set -euo pipefail

# Copy credentials to correct location
mkdir -p /etc/letsencrypt
cp /tmp/cloudflare-credentials.ini /etc/letsencrypt/cloudflare-credentials.ini
chmod 600 /etc/letsencrypt/cloudflare-credentials.ini

# Issue certificates
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials=/etc/letsencrypt/cloudflare-credentials.ini \
  --dns-cloudflare-propagation-seconds=60 \
  --email "${LETSENCRYPT_EMAIL:-admin@allthingslinux.org}" \
  --agree-tos \
  --no-eff-email \
  --expand \
  --non-interactive \
  -d "${IRC_DOMAIN:-irc.atl.chat}" \
  -d "*.${IRC_DOMAIN:-irc.atl.chat}"
