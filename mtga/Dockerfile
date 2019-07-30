FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@backzone.net>
ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER
WORKDIR /home/wine
CMD mtga

ENV WINEDEBUG $WINEDEBUG,err-ole,err-mmdevapi,err-dsound

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cabextract \
        gnupg \
        wget \
    && wget -nc https://dl.winehq.org/wine-builds/winehq.key \
    && apt-key add winehq.key && rm winehq.key \
    && apt remove -y --purge gnupg \
    && apt autoremove -y --purge \
    && apt-get install -y \
        mesa-utils mesa-utils-extra \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

RUN echo "deb http://dl.winehq.org/wine-builds/debian/ stretch main" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        winehq-devel \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

# Winetricks
ARG WINETRICKS_VERSION=20190615
ADD https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_VERSION/src/winetricks /usr/local/bin/winetricks
RUN chmod 755 /usr/local/bin/winetricks

USER wine

RUN mkdir -p /home/wine/.wine/host/wine/Temp

RUN winetricks d3dx11_43 win10 ddr=opengl

USER root

ADD --chown=wine:wine https://mtgarena.downloads.wizards.com/Live/Windows32/MTGAInstaller.exe /opt/mtga/MTGAInstaller.exe

COPY bin/mtga /usr/local/bin/mtga

USER wine

