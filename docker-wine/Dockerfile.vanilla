FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@backzone.net>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
    && echo "deb http://dl.winehq.org/wine-builds/debian/ stretch main" \
        > /etc/apt/sources.list.d/winehq.list \
    && curl -LO https://dl.winehq.org/wine-builds/Release.key \
    && apt-key add Release.key \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        winehq-staging \
    && apt remove -y --purge gnupg \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

