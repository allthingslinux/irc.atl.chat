# UnrealIRCd WebPanel Dockerfile
# Provides web-based administration interface for UnrealIRCd
# Based on official documentation: https://www.unrealircd.org/docs/UnrealIRCd_webpanel

FROM php:8.2-apache

# Add metadata labels
LABEL maintainer="AllThingsLinux IRC Infrastructure" \
    description="UnrealIRCd WebPanel - Web-based administration interface" \
    version="1.0.0" \
    org.opencontainers.image.source="https://github.com/allthingslinux/irc.atl.chat"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    APACHE_DOCUMENT_ROOT=/var/www/html/unrealircd-webpanel

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git=1:2.39.2-1.1 \
    curl=7.88.1-10+deb12u12 \
    unzip=6.0-28 \
    libzip-dev=1.9.2-1 \
    libcurl4-openssl-dev=7.88.1-10+deb12u12 \
    libonig-dev=6.9.8-1 \
    libmbstring-dev=8.2.7-1 \
    libxml2-dev=2.9.14+dfsg-1.1 \
    libssl-dev=3.0.17-1~deb12u2 \
    pkg-config=1.8.1-1 \
    ca-certificates=20230311+deb12u1 && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install PHP extensions
RUN docker-php-ext-install \
    zip \
    curl \
    mbstring \
    xml \
    pdo \
    pdo_mysql \
    mysqli

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configure Apache
RUN a2enmod rewrite && \
    sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/000-default.conf && \
    sed -ri -e 's!Directory /var/www/!Directory ${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf

# Create webpanel user
RUN groupadd --system --gid 1001 webpanel && \
    useradd --create-home --system --uid 1001 --gid webpanel webpanel

# Set working directory
WORKDIR /var/www/html

# Clone UnrealIRCd webpanel repository
RUN git clone --depth 1 https://github.com/unrealircd/unrealircd-webpanel.git && \
    chown -R webpanel:webpanel unrealircd-webpanel

# Switch to webpanel user for composer operations
USER webpanel:webpanel

# Install PHP dependencies
WORKDIR /var/www/html/unrealircd-webpanel
RUN composer install --no-dev --optimize-autoloader

# Switch back to root for final setup
USER root

# Set proper permissions
RUN chown -R webpanel:webpanel /var/www/html/unrealircd-webpanel && \
    chmod -R 755 /var/www/html/unrealircd-webpanel && \
    chmod -R 775 /var/www/html/unrealircd-webpanel/data && \
    chmod -R 775 /var/www/html/unrealircd-webpanel/config

# Create startup script
RUN echo '#!/bin/bash\n\
    # Wait for UnrealIRCd to be ready\n\
    echo "Waiting for UnrealIRCd JSON-RPC API..."\n\
    until curl -f "http://${UNREALIRCD_HOST:-ircd}:${UNREALIRCD_PORT:-8600}/" >/dev/null 2>&1; do\n\
    echo "Waiting for UnrealIRCd..."\n\
    sleep 5\n\
    done\n\
    echo "UnrealIRCd is ready!"\n\
    \n\
    # Start Apache in foreground\n\
    exec apache2-foreground' > /usr/local/bin/start-webpanel.sh && \
    chmod +x /usr/local/bin/start-webpanel.sh

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/unrealircd-webpanel/ || exit 1

# Default command
CMD ["/usr/local/bin/start-webpanel.sh"]
