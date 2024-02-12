FROM panard/wine:9.2-wow64
CMD mtgo

ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER
WORKDIR /home/wine

COPY extra/host-webbrowser /usr/local/bin/xdg-open
COPY extra/live-mtgo /usr/local/bin/live-mtgo

USER wine

RUN wineboot -i \
    && for f in arial32 times32 trebuc32 verdan32; do \
        curl -fL --output-dir /home/wine/.cache/winetricks/corefonts --create-dirs\
            -O https://github.com/pauleve/docker-mtgo/releases/download/artifacts/$f.exe; done \
    && curl -fL --output-dir /home/wine/.cache/winetricks/PowerPointViewer --create-dirs\
            -O https://github.com/pauleve/docker-mtgo/releases/download/artifacts/PowerPointViewer.exe \
    && winetricks -q corefonts calibri tahoma \
    && taskset -c 0 winetricks -f -q dotnet48 \
    && winetricks win7 sound=alsa \
    && winetricks renderer=gdi \
    && wineboot -s \
    && rm -rf /home/wine/.cache

ENV WINEDEBUG -all,err+all,warn+chain,warn+cryptnet

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
