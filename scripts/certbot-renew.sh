#!/bin/bash

# ============================================================================
# CERTBOT CERTIFICATE RENEWAL SCRIPT
# ============================================================================
# Renews SSL certificates using Cloudflare DNS challenge
# ============================================================================

set -euo pipefail

# Copy credentials to correct location
mkdir -p /etc/letsencrypt
cp /tmp/cloudflare-credentials.ini /etc/letsencrypt/cloudflare-credentials.ini
chmod 600 /etc/letsencrypt/cloudflare-credentials.ini

# Renew certificates
certbot renew --quiet --no-random-sleep-on-renew
