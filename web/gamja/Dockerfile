FROM node:current-alpine3.22@sha256:51dbfc749ec3018c7d4bf8b9ee65299ff9a908e38918ce163b0acfcd5dd931d9 AS base

ENV GAMJA_VERSION="1.0.0-beta.11"

LABEL maintainer="AllThingsLinux IRC Infrastructure" \
    description="UnrealIRCd WebPanel - Web-based administration interface" \
    version="1.0.0" \
    org.opencontainers.image.source="https://github.com/allthingslinux/irc.atl.chat"

RUN addgroup -S gamja && \
    adduser -S -G gamja gamja

FROM base AS builder

RUN mkdir -p /var/www/html && \
    chgrp gamja /var/www/html && \
    chmod 775 /var/www/html

WORKDIR /var/www/html

USER gamja:gamja

RUN wget -q https://codeberg.org/emersion/gamja/archive/v${GAMJA_VERSION}.tar.gz && \
    tar xvf v${GAMJA_VERSION}.tar.gz

WORKDIR /var/www/html/gamja

RUN npm install --omit=dev

FROM base AS dev

COPY --from=builder --chown=gamja:gamja /var/www/html/gamja/ /var/www/html/gamja
