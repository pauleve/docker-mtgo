FROM panard/wine:custom
MAINTAINER Panard <panard@backzone.net>
CMD mtgo

ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER
WORKDIR /home/wine

COPY extra/host-webbrowser /usr/local/bin/xdg-open
COPY extra/live-mtgo /usr/local/bin/live-mtgo

# Winetricks
ARG WINETRICKS_VERSION=master
ADD https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_VERSION/src/winetricks /usr/local/bin/winetricks
RUN chmod 755 /usr/local/bin/winetricks

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        cabextract \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

RUN su - $WINE_USER -c 'wineboot -i' \
    && su - $WINE_USER -c 'winetricks -q gdiplus gdiplus=native' \
    && su - $WINE_USER -c 'winetricks -q corefonts' \
    && su - $WINE_USER -c 'taskset -c 0 winetricks -f -q dotnet46' \
    && su - $WINE_USER -c 'winetricks win7 sound=alsa ddr=gdi'\
    && su - $WINE_USER -c 'wineboot -s' \
    && rm -rf /home/wine/.cache

ENV WINEDEBUG -all,err+all

COPY extra/mtgo.sh /usr/local/bin/mtgo

ADD --chown=wine:wine http://mtgoclientdepot.onlinegaming.wizards.com/setup.exe /opt/mtgo/mtgo.exe

USER wine

# hack to allow mounting of user.reg and system.reg from host
# see https://github.com/pauleve/docker-mtgo/issues/6
RUN cd .wine && mkdir host \
    && mv user.reg system.reg host/ \
    && ln -s host/*.reg .

