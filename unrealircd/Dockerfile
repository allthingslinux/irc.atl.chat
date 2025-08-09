# build phase - unrealircd, atheme
FROM debian@sha256:f527627d07c18abf87313c341ee8ef1b36f106baa8b6b6dc33f4c872d988b651 AS builder

ARG UNREALIRCD_VERSION="6.1.10"
ENV UNREALIRCD_PATH="unrealircd-${UNREALIRCD_VERSION}"

RUN groupadd --system --gid 1001 unrealircd_bld \
 && useradd --create-home --system --uid 1001 --gid unrealircd_bld unrealircd_bld

RUN apt update \
 && apt upgrade --yes

RUN apt install --yes \
        build-essential \
        pkg-config \
        gdb \
        libssl-dev \
        libpcre2-dev \
        libargon2-dev \
        libsodium-dev \
        libc-ares-dev \
        libjansson-dev \
        libgeoip-dev \
        libcurl4-openssl-dev \
        wget

USER unrealircd_bld:unrealircd_bld
WORKDIR /home/unrealircd_bld

RUN wget --trust-server-names https://www.unrealircd.org/downloads/${UNREALIRCD_PATH}.tar.gz \
 && tar xvf ${UNREALIRCD_PATH}.tar.gz
WORKDIR $UNREALIRCD_PATH
COPY ./config.settings .
RUN ./Config -quick \
 && make \
 && make install
COPY 
