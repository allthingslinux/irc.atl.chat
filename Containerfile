# Use a more specific and stable base image
FROM debian:bookworm-slim AS base

# Add metadata labels
LABEL maintainer="All Things Linux IRC Infrastructure" \
    description="Optimized IRC services with UnrealIRCd and Atheme" \
    version="1.0.0" \
    org.opencontainers.image.source="https://github.com/allthingslinux/irc.atl.chat"

# Set environment variables for non-interactive package installation
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    # Set build arguments as environment variables for better caching
    UNREALIRCD_VERSION="6.1.10" \
    ATHEME_VERSION="7.2.12"

# Install system dependencies in a single layer with cleanup
# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential \
    gdb \
    gettext \
    libargon2-dev \
    libc-ares-dev \
    libcurl4-openssl-dev \
    libpcre2-dev \
    libssl-dev \
    libsodium-dev \
    pkg-config \
    wget \
    ca-certificates \
    git \
    # Additional Atheme dependencies for better functionality
    libidn2-dev \
    nettle-dev \
    libqrencode-dev \
    # Development tools for better builds
    autoconf \
    automake \
    libtool \
    # Perl development libraries for Atheme Perl support
    libperl-dev \
    # Environment variable substitution tool
    gettext && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Builder stage for compiling UnrealIRCd and Atheme
FROM base AS builder

# Create non-root user for building
RUN groupadd --system --gid 1001 builder && \
    useradd --create-home --system --uid 1001 --gid builder builder

# Set build arguments
ARG UNREALIRCD_VERSION
ARG ATHEME_VERSION

# Set environment variables for the build
ENV UNREALIRCD_BASENAME="unrealircd-${UNREALIRCD_VERSION}" \
    ATHEME_BASENAME="atheme-services-v${ATHEME_VERSION}" \
    # Compiler optimization flags
    CFLAGS="-O2 -march=native -mtune=native -fstack-protector-strong -D_FORTIFY_SOURCE=2" \
    CXXFLAGS="-O2 -march=native -mtune=native -fstack-protector-strong -D_FORTIFY_SOURCE=2" \
    LDFLAGS="-Wl,-z,relro,-z,now" \
    # Build optimization
    MAKEFLAGS="-j$(nproc)" \
    # Atheme-specific build flags
    ATHEME_CFLAGS="-O2 -march=native -mtune=native" \
    ATHEME_LDFLAGS="-Wl,-z,relro,-z,now"

# Create necessary directories
RUN mkdir -p /usr/src/unrealircd /usr/src/atheme /usr/local/unrealircd /usr/local/atheme

# Download and extract UnrealIRCd (with better error handling)
WORKDIR /usr/src/unrealircd
RUN wget --quiet --show-progress --timeout=30 --tries=3 \
    "https://www.unrealircd.org/downloads/${UNREALIRCD_BASENAME}.tar.gz" && \
    tar xf "${UNREALIRCD_BASENAME}.tar.gz" && \
    rm "${UNREALIRCD_BASENAME}.tar.gz" && \
    chown -R builder:builder /usr/src/unrealircd /usr/local/unrealircd

# Download and extract Atheme (with better error handling)
WORKDIR /usr/src/atheme
RUN wget --quiet --show-progress --timeout=30 --tries=3 \
    "https://github.com/atheme/atheme/releases/download/v${ATHEME_VERSION}/${ATHEME_BASENAME}.tar.xz" && \
    tar xf "${ATHEME_BASENAME}.tar.xz" && \
    rm "${ATHEME_BASENAME}.tar.xz" && \
    chown -R builder:builder /usr/src/atheme /usr/local/atheme

# Ensure proper ownership
RUN chown builder:builder /usr/local/unrealircd

# Switch to builder user
USER builder:builder

# Build UnrealIRCd
WORKDIR "/usr/src/unrealircd/${UNREALIRCD_BASENAME}"
COPY --chown=builder:builder ./unrealircd/config.settings .
RUN ./Config -quick && \
    make -j"$(nproc)" && \
    make install && \
    make clean

# Set up UnrealIRCd contrib modules repository
WORKDIR /usr/local/unrealircd
RUN git clone --depth 1 https://github.com/unrealircd/unrealircd-contrib.git contrib && \
    chown -R builder:builder contrib

# Build Atheme with optimized configuration
WORKDIR "/usr/src/atheme/${ATHEME_BASENAME}"
RUN ./configure \
    --prefix=/usr/local/atheme \
    --enable-compiler-sanitizers \
    --disable-heap-allocator \
    --disable-linker-defs \
    --enable-large-net \
    --enable-contrib \
    --enable-nls \
    --enable-reproducible-builds \
    --with-perl \
    --with-pkg-config && \
    make -j"$(nproc)" && \
    make install && \
    make clean

# Final runtime stage
FROM base AS runtime

# Create runtime user
RUN groupadd --system --gid 1001 ircd && \
    useradd --system --uid 1001 --gid ircd ircd

# Create necessary directories
RUN mkdir -p /usr/local /var/log /var/run

# Copy compiled binaries from builder stage
COPY --from=builder --chown=ircd:ircd /usr/local/atheme /usr/local/atheme
COPY --from=builder --chown=ircd:ircd /usr/local/unrealircd /usr/local/unrealircd

# Copy startup script
COPY --chown=ircd:ircd scripts/start-services.sh /usr/local/bin/start-services

# Copy module management scripts
COPY --chown=ircd:ircd scripts/manage-modules.sh /usr/local/bin/manage-modules
COPY --chown=ircd:ircd scripts/module-config.sh /usr/local/bin/module-config
COPY --chown=ircd:ircd scripts/start-webpanel.sh /usr/local/bin/start-webpanel

# Create directory for prepare-config script and copy it
RUN mkdir -p /opt/irc/scripts
COPY --chown=ircd:ircd scripts/prepare-config.sh /opt/irc/scripts/prepare-config.sh

# Set proper permissions and create necessary symlinks
RUN chmod 755 /usr/local/atheme/bin/* /usr/local/unrealircd/bin/* /opt/irc/scripts/* && \
    chown -R ircd:ircd /var/log /var/run && \
    # Create symlinks for easier access
    ln -sf /usr/local/atheme/bin/atheme-services /usr/local/bin/atheme-services && \
    ln -sf /usr/local/unrealircd/bin/unrealircd /usr/local/bin/unrealircd && \
    # Create Atheme database directory
    mkdir -p /usr/local/atheme/var && \
    chown -R ircd:ircd /usr/local/atheme/var

# Switch to runtime user
USER ircd:ircd

# Set working directory
WORKDIR /usr/local/unrealircd

# Expose default IRC ports
EXPOSE 6667 6697 6900 8600

# Health check for both services
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f unrealircd && pgrep -f atheme-services || exit 1

# Add Atheme-specific environment variables
ENV ATHEME_CONF="/usr/local/atheme/etc/atheme.conf" \
    ATHEME_DATA="/usr/local/atheme/var" \
    ATHEME_MODULES="/usr/local/atheme/modules" \
    # UnrealIRCd module management
    UNREALIRCD_CONTRIB="/usr/local/unrealircd/contrib" \
    UNREALIRCD_MODULES="/usr/local/unrealircd/modules"

# Default command - use our startup script
CMD ["/usr/local/bin/start-services", "start"]
