FROM debian@sha256:f527627d07c18abf87313c341ee8ef1b36f106baa8b6b6dc33f4c872d988b651 AS builder

ARG ATHEME_VERSION="7.2.12"
ARG BUILDUSER="atheme_bld"

RUN apt update \
 && apt upgrade -y

RUN groupadd -r -g 1000 $BUILDUSER \
 && useradd -m -r -u 1000 -g $BUILDUSER $BUILDUSER

RUN apt install -y libsodium-dev \
    libqrencode-dev \
    libpcre2-dev \
    nettle-dev \
    libidn-dev \
    libssl-dev \
    libargon2-dev \
    build-essential \
    gettext \
    wget

USER $BUILDUSER:$BUILDUSER
WORKDIR /home/$BUILDUSER

RUN wget -q https://github.com/atheme/atheme/releases/download/v${ATHEME_VERSION}/atheme-services-v${ATHEME_VERSION}.tar.xz \
 && tar xvf atheme-services-v${ATHEME_VERSION}.tar.xz
WORKDIR atheme-services-v${ATHEME_VERSION}

RUN ./configure \
 && make \
 && make install
