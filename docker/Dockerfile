FROM debian:unstable-20250811-slim AS base


ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y \
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
        wget && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives/* && \
    rm -rf /var/lib/apt/lists/*

FROM base AS builder

RUN groupadd --system --gid 1001 builder && \
    useradd --create-home --system --uid 1001 --gid builder builder

ARG UNREALIRCD_VERSION="6.1.10"
ARG ATHEME_VERSION="7.2.12"

ENV UNREALIRCD_BASENAME="unrealircd-${UNREALIRCD_VERSION}"
ENV ATHEME_BASENAME="atheme-services-v${ATHEME_VERSION}"

RUN mkdir -p /usr/src/unrealircd /usr/src/atheme /usr/local/unrealircd /usr/local/atheme
WORKDIR /usr/src/unrealircd
RUN wget --quiet https://www.unrealircd.org/downloads/${UNREALIRCD_BASENAME}.tar.gz && \
    tar xvf "$UNREALIRCD_BASENAME".tar.gz && \
    chown -R builder:builder /usr/src/unrealircd /usr/local/unrealircd

WORKDIR /usr/src/atheme
RUN wget --quiet https://github.com/atheme/atheme/releases/download/v${ATHEME_VERSION}/${ATHEME_BASENAME}.tar.xz && \
    tar xvf "$ATHEME_BASENAME".tar.xz && \
    chown -R builder:builder /usr/src/atheme /usr/local/atheme

RUN chown builder:builder /usr/local/unrealircd

USER builder:builder

WORKDIR /usr/src/unrealircd/"$UNREALIRCD_BASENAME"
COPY ./unrealircd/config.settings .
RUN ./Config -quick && \
    make && \
    make install && \
    make clean

WORKDIR /usr/src/atheme/"$ATHEME_BASENAME"
RUN ./configure --prefix=/usr/local/atheme && \
    make && \
    make install && \
    make clean

FROM base AS dev

RUN groupadd --system --gid 1001 ircd && \
    useradd --system --uid 1001 --gid ircd ircd

RUN mkdir -p /usr/local
COPY --from=builder --chown=ircd:ircd /usr/local/atheme /usr/local/atheme
COPY --from=builder --chown=ircd:ircd /usr/local/unrealircd /usr/local/unrealircd
