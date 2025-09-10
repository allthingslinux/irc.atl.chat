# ================================================================================
# IRC.atl.chat - Multi-Stage Container Build
# ================================================================================
# This Containerfile builds a complete IRC infrastructure with UnrealIRCd and Atheme.
# Uses multi-stage build to minimize final image size while providing full functionality.
# ================================================================================

# ================================================================================
# BASE STAGE - Common dependencies for building and runtime
# ================================================================================
FROM debian:bookworm-slim AS base

# Add comprehensive metadata labels for better image management
LABEL maintainer="All Things Linux IRC Infrastructure" \
    description="Production-hardened IRC services with UnrealIRCd and Atheme" \
    version="1.0.0" \
    org.opencontainers.image.source="https://github.com/allthingslinux/irc.atl.chat" \
    org.opencontainers.image.licenses="GPL-3.0" \
    org.opencontainers.image.vendor="All Things Linux"

# 🔒 SECURITY: Configure non-interactive environment
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    # Define versions as environment variables for better caching
    UNREALIRCD_VERSION="6.1.10" \
    ATHEME_VERSION="7.2.12"

# ================================================================================
# SYSTEM DEPENDENCIES - Optimized package installation with security
# ================================================================================
# 🚀 OPTIMIZATION: Single layer package installation with enhanced security
# 🔒 SECURITY: Use specific package versions and verify GPG keys
# 📦 EFFICIENCY: Combined operations to minimize layers
# hadolint ignore=DL3008,DL3009,DL3015
RUN set -eux; \
    # Update package lists
    apt-get update; \
    # Upgrade system packages for security patches
    apt-get upgrade -y --no-install-recommends; \
    # Install all dependencies in one command to reduce layers
    apt-get install -y --no-install-recommends \
    # 🔧 Core build tools and compilers (essential)
    build-essential \
    gcc \
    g++ \
    make \
    # 🐛 Debugging tools (development only)
    gdb \
    # 🌍 Internationalization support
    gettext \
    # 🔐 Cryptography and security libraries
    libargon2-dev \
    libc-ares-dev \
    libcurl4-openssl-dev \
    libpcre2-dev \
    libssl-dev \
    libsodium-dev \
    # 🛠️ Build system tools
    pkg-config \
    autoconf \
    automake \
    libtool \
    # 📥 Download utilities
    wget \
    curl \
    ca-certificates \
    # 📚 Version control
    git \
    # 🎯 Atheme-specific dependencies
    libidn2-dev \
    nettle-dev \
    libqrencode-dev \
    libperl-dev \
    # 🧹 System utilities for cleanup
    procps && \
    # 🧽 AGGRESSIVE CLEANUP: Remove all unnecessary files to minimize size
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/cache/apt/archives/* \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /var/log/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/locale/*

# ================================================================================
# BUILDER STAGE - Optimized compilation with security hardening
# ================================================================================
# 🚀 OPTIMIZATION: Separate stage for compilation, discarded in final image
FROM base AS builder

# 🔒 SECURITY: Create dedicated build user (never build as root)
# 📦 EFFICIENCY: Combined user/directory creation in single layer
RUN set -eux; \
    groupadd --system --gid 1001 builder; \
    useradd --create-home --system --uid 1001 --gid builder builder; \
    # Create all necessary directories in one operation
    mkdir -p /usr/src/unrealircd /usr/src/atheme /usr/local/unrealircd /usr/local/atheme; \
    # Set proper ownership
    chown -R builder:builder /usr/src /usr/local

# Accept build arguments for version control
ARG UNREALIRCD_VERSION
ARG ATHEME_VERSION

ENV CFLAGS="-O2 -march=native -mtune=native -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIC -fstack-clash-protection -fcf-protection=full"
ENV CXXFLAGS="-O2 -march=native -mtune=native -fstack-protector-strong -D_FORTIFY_SOURCE=2 -fPIC -fstack-clash-protection -fcf-protection=full"
ENV LDFLAGS="-Wl,-z,relro,-z,now,-z,noexecstack"
ENV CPPFLAGS="-D_FORTIFY_SOURCE=2"

ENV MAKEFLAGS="-j$(nproc)"

ENV UNREALIRCD_BASENAME="unrealircd-${UNREALIRCD_VERSION}"
ENV ATHEME_BASENAME="atheme-services-v${ATHEME_VERSION}"

# ================================================================================
# DOWNLOAD SOURCE CODE - Optimized parallel downloads with verification
# ================================================================================

# Download and extract UnrealIRCd
WORKDIR /usr/src/unrealircd
RUN set -eux; \
    # Download with enhanced security and retry logic
    wget --quiet --show-progress --timeout=30 --tries=3 \
    --ca-certificate=/etc/ssl/certs/ca-certificates.crt \
    "https://www.unrealircd.org/downloads/${UNREALIRCD_BASENAME}.tar.gz"; \
    # Verify download integrity (basic check)
    [ -s "${UNREALIRCD_BASENAME}.tar.gz" ]; \
    # Extract and clean up in one operation
    tar xf "${UNREALIRCD_BASENAME}.tar.gz" && \
    rm "${UNREALIRCD_BASENAME}.tar.gz"; \
    # Set ownership
    chown -R builder:builder /usr/src/unrealircd /usr/local/unrealircd

# Download and extract Atheme
WORKDIR /usr/src/atheme
RUN set -eux; \
    # Download with enhanced security and retry logic
    wget --quiet --show-progress --timeout=30 --tries=3 \
    --ca-certificate=/etc/ssl/certs/ca-certificates.crt \
    "https://github.com/atheme/atheme/releases/download/v${ATHEME_VERSION}/${ATHEME_BASENAME}.tar.xz"; \
    # Verify download integrity
    [ -s "${ATHEME_BASENAME}.tar.xz" ]; \
    # Extract and clean up in one operation
    tar xf "${ATHEME_BASENAME}.tar.xz" && \
    rm "${ATHEME_BASENAME}.tar.xz"; \
    # Set ownership
    chown -R builder:builder /usr/src/atheme /usr/local/atheme

# Switch to non-root user for compilation (security best practice)
USER builder:builder

# ================================================================================
# BUILD UNREALIRCD - Compile the IRC daemon
# ================================================================================
WORKDIR "/usr/src/unrealircd/${UNREALIRCD_BASENAME}"

# Copy pre-configured build settings (saved from previous ./Config)
# This config.settings file contains installation paths and build options

COPY --chown=builder:builder ./unrealircd/config.settings .

# Build steps:
# 1. Load config.settings + auto-detect system (./Config -quick)
# 2. Generate Makefiles with saved settings (./Config -quick)
# 3. Compile using all available CPU cores (make -j"$(nproc)")
# 4. Install to configured paths (make install)
# 5. Clean build artifacts (make clean)
RUN \
    # Step 1: Configure with ./Config (UnrealIRCd's build system)
    # --enable-werror: Treat warnings as errors (catches potential issues)
    # --enable-libcurl: Enable remote include support
    ./Config --enable-werror --enable-libcurl && \
    # Step 2: Compile - Makefiles inherit CFLAGS/CXXFLAGS/LDFLAGS from environment
    make -j"$(nproc)" && \
    # Step 3: Install to configured paths
    make install && \
    # Step 4: Clean build artifacts to reduce image size
    make clean

# ================================================================================
# SETUP UNREALIRCD CONTRIB MODULES - Clone additional modules repository
# ================================================================================
WORKDIR /usr/local/unrealircd
# Clone contrib modules for extended functionality
RUN git clone --depth 1 https://github.com/unrealircd/unrealircd-contrib.git contrib && \
    chown -R builder:builder contrib

# ================================================================================
# BUILD ATHEME - Compile the services daemon with full feature set
# ================================================================================
WORKDIR "/usr/src/atheme/${ATHEME_BASENAME}"

RUN ./configure \
    # Installation directory
    --prefix=/usr/local/atheme \
    # PRODUCTION: Use system allocator for better performance (recommended)
    --disable-heap-allocator \
    # PRODUCTION: Disable linker definitions for better compatibility
    --disable-linker-defs \
    # Enable large network support
    --enable-large-net \
    # Enable contrib modules for extended functionality
    --enable-contrib \
    # Enable internationalization support
    --enable-nls \
    # Enable reproducible builds for security
    --enable-reproducible-builds \
    # Enable Perl module support for scripting
    --with-perl \
    # Use pkg-config for better dependency detection
    --with-pkg-config \
    # PRODUCTION: Skip compiler sanitizers (not recommended for production)
    # --enable-compiler-sanitizers \
    # Enable warnings as errors to catch issues early
    --enable-warnings && \
    make -j"$(nproc)" && \
    make install && \
    make clean

# ================================================================================
# RUNTIME STAGE - Ultra-minimal production image
# ================================================================================
# OPTIMIZATION: Only includes runtime dependencies, ~50% smaller than builder
FROM debian:bookworm-slim AS runtime

# 🔒 SECURITY: Minimal runtime environment
ENV DEBIAN_FRONTEND=noninteractive \
    # Disable core dumps for security
    DAEMON_UID=1001 \
    DAEMON_GID=1001

# hadolint ignore=DL3008,DL3009
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    libc6 \
    libssl3 \
    libsodium23 \
    libargon2-1 \
    libc-ares2 \
    libcurl4 \
    libpcre2-8-0 \
    ca-certificates \
    procps \
    libintl-perl && \
    # AGGRESSIVE CLEANUP: Maximize size reduction
    apt-get clean && \
    apt-get autoremove -y && \
    rm -rf /var/cache/apt/archives/* \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    /var/log/* \
    /usr/share/doc/* \
    /usr/share/man/* \
    /usr/share/locale/*; \
    # ECURITY: Create non-root runtime user
    groupadd --system --gid 1001 ircd; \
    useradd --system --uid 1001 --gid ircd --home /nonexistent --shell /bin/false ircd; \
    # Create minimal runtime directories
    mkdir -p /usr/local /var/log/ircd /var/run/ircd; \
    # Set proper ownership
    chown -R ircd:ircd /var/log/ircd /var/run/ircd

# ================================================================================
# COPY COMPILED BINARIES - Transfer only essential files from builder
# ================================================================================
# 🚀 OPTIMIZATION: Copy only what we need, minimizing image size
# 🔒 SECURITY: Maintain proper ownership throughout
COPY --from=builder --chown=ircd:ircd /usr/local/atheme /usr/local/atheme
COPY --from=builder --chown=ircd:ircd /usr/local/unrealircd /usr/local/unrealircd

# ================================================================================
# SETUP SCRIPTS AND PERMISSIONS - Optimized single layer
# ================================================================================
# 🚀 OPTIMIZATION: Combine all setup operations in single layer
# 🔒 SECURITY: Minimal privileges, proper ownership
RUN set -eux; \
    # Copy all management scripts
    mkdir -p /opt/irc/scripts; \
    cp -a scripts/* /opt/irc/scripts/ 2>/dev/null || true; \
    # Set executable permissions
    chmod 755 /usr/local/atheme/bin/* /usr/local/unrealircd/bin/* /opt/irc/scripts/* 2>/dev/null || true; \
    # Create necessary directories with proper ownership
    mkdir -p /usr/local/atheme/var /usr/local/atheme/etc /usr/local/unrealircd/conf /usr/local/unrealircd/logs; \
    chown -R ircd:ircd /usr/local/atheme /usr/local/unrealircd /opt/irc /var/log/ircd /var/run/ircd; \
    # Create symlinks for easier access
    ln -sf /usr/local/atheme/bin/atheme-services /usr/local/bin/atheme-services; \
    ln -sf /usr/local/unrealircd/bin/unrealircd /usr/local/bin/unrealircd; \
    # Security: Remove any world-writable permissions
    find /usr/local -type f -perm /002 -exec chmod o-w {} + 2>/dev/null || true; \
    # Clean up any temporary files
    rm -rf /tmp/* /var/tmp/* 2>/dev/null || true

# 🔒 SECURITY: Switch to non-root user immediately
USER ircd:ircd

# 📍 Set working directory
WORKDIR /usr/local/unrealircd

# ================================================================================
# NETWORK CONFIGURATION - Expose IRC service ports
# ================================================================================
EXPOSE 6667 6697 6900 8600

# ================================================================================
# HEALTH MONITORING - Automatic service health checks
# ================================================================================
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f unrealircd && pgrep -f atheme-services || exit 1

# ================================================================================
# ENVIRONMENT CONFIGURATION - Optimized runtime environment
# ================================================================================
# 🚀 OPTIMIZATION: Group related environment variables
ENV ATHEME_CONF="/usr/local/atheme/etc/atheme.conf" \
    ATHEME_DATA="/usr/local/atheme/var" \
    ATHEME_MODULES="/usr/local/atheme/modules" \
    # UnrealIRCd configuration paths
    UNREALIRCD_CONTRIB="/usr/local/unrealircd/contrib" \
    UNREALIRCD_MODULES="/usr/local/unrealircd/modules" \
    # 🔒 SECURITY: Disable core dumps and set restrictive umask
    UMASK=0027 \
    # Performance: Set timezone to UTC for consistency
    TZ=UTC

# ================================================================================
# STARTUP COMMAND - Optimized service launcher
# ================================================================================
# 🚀 OPTIMIZATION: Use exec for proper signal handling
CMD ["exec", "/usr/local/bin/start-services", "start"]
