# ================================================================================
# UnrealIRCd Docker Build (Alpine-based)
# Based on proven patterns from example repositories
# ================================================================================

# Build stage
FROM alpine:3.20 AS builder

# Build arguments
ARG UNREALIRCD_VERSION=6.1.10
ARG UID=0
ARG GID=0

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

# Create unrealircd user (skip if UID is 0)
RUN if [ "${UID}" != "0" ]; then \
    addgroup -g ${GID} unrealircd && \
    adduser -D -u ${UID} -G unrealircd -s /bin/false unrealircd; \
    fi

# Create installation directory
RUN mkdir -p /home/unrealircd/unrealircd

# Download and extract
WORKDIR /tmp
RUN wget --progress=dot:giga https://www.unrealircd.org/downloads/unrealircd-${UNREALIRCD_VERSION}.tar.gz && \
    tar xzf unrealircd-${UNREALIRCD_VERSION}.tar.gz

# Create build user for UnrealIRCd (it refuses to build as root)
RUN addgroup -g 1000 builduser && \
    adduser -D -u 1000 -G builduser builduser && \
    mkdir -p /home/unrealircd && \
    chown -R builduser:builduser /tmp/unrealircd-${UNREALIRCD_VERSION} /home/unrealircd

# Build as builduser
WORKDIR /tmp/unrealircd-${UNREALIRCD_VERSION}
USER builduser

# Copy config.settings file for UnrealIRCd configuration
COPY config.settings .

# Configure UnrealIRCd using the config.settings file
RUN ./Config -quick

# Build
RUN make -j"$(nproc)"

# Install as builduser (same user who configured)
RUN make install

# Switch back to root for final setup
USER root
RUN chown -R root:root /home/unrealircd/unrealircd

# Runtime stage
FROM alpine:3.20

# Runtime arguments
ARG UID=0
ARG GID=0

# Install runtime dependencies
RUN apk update && apk add --no-cache \
    openssl \
    pcre2 \
    c-ares \
    curl \
    ca-certificates \
    ca-certificates-bundle \
    tini \
    su-exec \
    netcat-openbsd \
    argon2-libs \
    libsodium \
    jansson

# Create unrealircd user with specific UID/GID
RUN if [ "${UID}" = "0" ]; then \
    addgroup -g 1000 unrealircd && \
    adduser -D -u 1000 -G unrealircd -s /bin/false unrealircd; \
    else \
    addgroup -g ${GID} unrealircd && \
    adduser -D -u ${UID} -G unrealircd -s /bin/false unrealircd; \
    fi

# Copy built application from builder stage
COPY --from=builder /home/unrealircd/unrealircd /home/unrealircd/unrealircd

# Set ownership to unrealircd user
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

# Switch to unrealircd user for runtime
USER unrealircd

# Expose ports
EXPOSE 6667 6697 6900 8600 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD nc -z localhost 6667 || exit 1

# Use tini as init system with child subreaper
ENTRYPOINT ["/sbin/tini", "-s", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["start"]