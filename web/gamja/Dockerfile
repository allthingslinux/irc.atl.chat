# Setup phase
FROM node:current-alpine3.22@sha256:51dbfc749ec3018c7d4bf8b9ee65299ff9a908e38918ce163b0acfcd5dd931d9 AS base

LABEL maintainer="AllThingsLinux IRC Infrastructure" \
    description="UnrealIRCd WebPanel - Web-based administration interface" \
    version="1.0.0" \
    org.opencontainers.image.source="https://github.com/allthingslinux/irc.atl.chat"

ENV GAMJA_VERSION="1.0.0-beta.11"
ENV GAMJA_PORT=8080

RUN addgroup -S gamja && \
    adduser -S -G gamja gamja

# Building phase
FROM base AS builder

RUN mkdir -p /var/www/html && \
    chgrp gamja /var/www/html && \
    chmod 775 /var/www/html

WORKDIR /var/www/html

USER gamja:gamja

RUN wget -q "https://codeberg.org/emersion/gamja/archive/v${GAMJA_VERSION}.tar.gz" && \
    tar xvf v${GAMJA_VERSION}.tar.gz

WORKDIR /var/www/html/gamja

RUN npm install --omit=dev

# Development server phase
FROM base AS dev

COPY --from=builder --chown=gamja:gamja /var/www/html/gamja/ /var/www/html/gamja
COPY --chown=gamja:gamja web/gamja/conf/config.json /var/www/html/gamja/config.json

WORKDIR /var/www/html/gamja

EXPOSE 8080
