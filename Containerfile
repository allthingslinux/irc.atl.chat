# ================================================================================
# UnrealIRCd Docker Build (Alpine-based)
# Based on proven patterns from example repositories
# ================================================================================

# Build stage
FROM alpine:3.20 AS builder

# Build arguments
ARG UNREALIRCD_VERSION=6.1.10
ARG UID=1000
ARG GID=1000

# Install build dependencies
RUN apk update && apk add --no-cache \
    build-base \
    wget \
    pkgconfig \
    openssl \
    openssl-dev \
    pcre2-dev \
    c-ares-dev \
    curl-dev \
    argon2-dev \
    libsodium-dev \
    jansson-dev \
    cmake \
    file

# Create unrealircd user
RUN addgroup -g ${GID} unrealircd && \
    adduser -D -u ${UID} -G unrealircd -s /bin/false unrealircd

# Create installation directory with proper ownership
RUN mkdir -p /home/unrealircd/unrealircd && \
    chown -R unrealircd:unrealircd /home/unrealircd

# Download and extract as root, then fix ownership
WORKDIR /tmp
RUN wget --progress=dot:giga https://www.unrealircd.org/downloads/unrealircd-${UNREALIRCD_VERSION}.tar.gz && \
    tar xzf unrealircd-${UNREALIRCD_VERSION}.tar.gz && \
    chown -R unrealircd:unrealircd /tmp/unrealircd-${UNREALIRCD_VERSION}

# Switch to unrealircd user for building
USER unrealircd
WORKDIR /tmp/unrealircd-${UNREALIRCD_VERSION}

# Configure UnrealIRCd with the correct installation paths
RUN ./Config \
    --with-showlistmodes \
    --enable-ssl \
    --enable-ipv6 \
    --enable-libcurl \
    --with-nick-history=2000 \
    --with-sendq=3000000 \
    --with-bufferpool=18 \
    --with-hostname=localhost \
    --with-listen=6667 \
    --with-prefix=/home/unrealircd/unrealircd \
    --with-modulesdir=/home/unrealircd/unrealircd/modules \
    --with-logdir=/home/unrealircd/unrealircd/logs \
    --with-cachedir=/home/unrealircd/unrealircd/cache \
    --with-datadir=/home/unrealircd/unrealircd/data \
    --with-docdir=/home/unrealircd/unrealircd/doc \
    --with-tmpdir=/home/unrealircd/unrealircd/tmp \
    --with-privatelibdir=/home/unrealircd/unrealircd/lib \
    --with-bindir=/home/unrealircd/unrealircd/bin \
    --with-scriptdir=/home/unrealircd/unrealircd \
    --with-controlfile=/run/unrealircd/unrealircd.ctl

# Build
RUN make -j"$(nproc)"

# Switch to root to run installer
USER root
RUN make install && \
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd

# Runtime stage
FROM alpine:3.20

# Runtime arguments
ARG UID=1000
ARG GID=1000

# Install runtime dependencies
RUN apk update && apk add --no-cache \
    openssl \
    pcre2 \
    c-ares \
    curl \
    ca-certificates \
    tini \
    su-exec \
    netcat-openbsd \
    argon2-libs \
    libsodium \
    jansson

# Create unrealircd user with specific UID/GID
RUN addgroup -g ${GID} unrealircd && \
    adduser -D -u ${UID} -G unrealircd -s /bin/false unrealircd

# Copy built application from builder stage
COPY --from=builder /home/unrealircd/unrealircd /home/unrealircd/unrealircd

# Set ownership
RUN chown -R unrealircd:unrealircd /home/unrealircd/unrealircd

# Create directory structure
RUN mkdir -p /home/unrealircd/unrealircd/conf \
    /home/unrealircd/unrealircd/logs \
    /home/unrealircd/unrealircd/data \
    /home/unrealircd/unrealircd/cache \
    /home/unrealircd/unrealircd/tmp \
    /run/unrealircd && \
    chown -R unrealircd:unrealircd /home/unrealircd/unrealircd && \
    chown -R unrealircd:unrealircd /run/unrealircd

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Set working directory
WORKDIR /home/unrealircd/unrealircd

# Expose ports
EXPOSE 6667 6697 6900 8600

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 6667 || exit 1

# Run as root initially to handle permissions, then drop privileges in entrypoint
# Use tini as init system
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["start"]