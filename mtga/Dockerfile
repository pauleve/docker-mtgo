FROM panard/mtgo:2018-12-20
MAINTAINER Panard <panard@backzone.net>
CMD mtga

ENV WINEDEBUG $WINEDEBUG,err-ole,err-mmdevapi,err-dsound

RUN mkdir -p /home/wine/.wine/host/wine/Temp

RUN winetricks ddr=opengl

USER root

RUN apt-get update \
    && apt-get install -y \
        mesa-utils mesa-utils-extra \
    && apt clean -y && rm -rf /var/lib/apt/lists/*

ADD --chown=wine:wine https://mtgarena.downloads.wizards.com/Live/Windows32/MTGAInstaller.exe /opt/mtga/MTGAInstaller.exe

COPY bin/mtga /usr/local/bin/mtga

USER wine
