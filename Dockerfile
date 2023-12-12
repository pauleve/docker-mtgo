FROM archlinux:latest
CMD mtgo
ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine

RUN echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
RUN pacman -Syy && \
    pacman -S --noconfirm \
        cabextract \
        libunwind \
        libwbclient \
        libxinerama \
        libxcomposite \
        wine\
    && pacman -Scc

RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER

WORKDIR /home/wine

COPY extra/host-webbrowser /usr/local/bin/xdg-open
COPY extra/live-mtgo /usr/local/bin/live-mtgo

ENV WINEDEBUG -all,err+all,warn+chain,warn+cryptnet
ENV WINEARCH win32

# Winetricks
ARG WINETRICKS_VERSION=master
ADD https://raw.githubusercontent.com/Winetricks/winetricks/$WINETRICKS_VERSION/src/winetricks /usr/local/bin/winetricks
RUN chmod 755 /usr/local/bin/winetricks

USER wine
WORKDIR /home/wine
RUN wineboot -i \
    && for f in arial32 times32 trebuc32 verdan32; do \
        curl -fL --output-dir /home/wine/.cache/winetricks/corefonts --create-dirs\
            -O https://web.archive.org/web/20180219204401/https://mirrors.kernel.org/gentoo/distfiles/$f.exe; done\
    && winetricks -q corefonts calibri tahoma \
    && taskset -c 0 winetricks -q dotnet48 \
    && wineboot -s \
    && rm -rf /home/wine/.cache

RUN winetricks -q sound=alsa ddr=gdi renderer=gdi

USER root

COPY extra/mtgo.sh /usr/local/bin/mtgo
ADD --chown=wine:wine https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe?v=8 /opt/mtgo/mtgo.exe

USER wine

# hack to allow mounting of user.reg and system.reg from host
# see https://github.com/pauleve/docker-mtgo/issues/6
RUN cd .wine && mkdir host \
    && mv user.reg system.reg host/ \
    && ln -s host/*.reg .
RUN mkdir -p \
    /home/wine/.wine/drive_c/users/wine/Documents\
    /home/wine/.wine/host/wine/Documents
