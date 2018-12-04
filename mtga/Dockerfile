FROM panard/mtgo:latest
MAINTAINER Panard <panard@backzone.net>
CMD mtga

USER root

RUN apt-get update \
    && apt-get install -y \
        mesa-utils mesa-utils-extra \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

ADD --chown=wine:wine https://mtgarena.downloads.wizards.com/Live/Windows32/MTGAInstaller.exe /opt/mtga/MTGAInstaller.exe

COPY bin/mtga /usr/local/bin/mtga

USER wine

RUN mkdir -p /home/wine/.wine/host/wine/Temp
