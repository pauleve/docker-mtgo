FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@backzone.net>
CMD mtgo

ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER
WORKDIR /home/wine

# Winetricks
ADD https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks /usr/local/bin/winetricks
RUN chmod 755 /usr/local/bin/winetricks

ENV DEBIAN_FRONTEND noninteractive
RUN	apt-get update \
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
        cabextract \
        winehq-staging \
    && apt remove -y --purge gnupg \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        xauth \
        xvfb \
    && su - $WINE_USER -c winecfg \
    && su - $WINE_USER -c 'xvfb-run -a taskset -c 0 winetricks -q corefonts dotnet462 win7' \
    && rm -rf /home/wine/.cache \
    && apt remove -y --purge xauth xvfb \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

ENV WINEDEBUG -all

ADD --chown=wine:wine http://mtgoclientdepot.onlinegaming.wizards.com/setup.exe /opt/mtgo/mtgo.exe

COPY extra/mtgo.sh /usr/local/bin/mtgo

USER wine

# hack to allow mounting of user.reg and system.reg from host
# see https://github.com/pauleve/docker-mtgo/issues/6
RUN cd .wine && mkdir host \
    && mv user.reg system.reg host/ \
    && ln -s host/*.reg .
