
### build wine-wow64
FROM archlinux:latest as builder

RUN pacman -Syy
RUN pacman -S --noconfirm git base-devel

RUN useradd -d /home/user -m user
RUN echo 'user ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/user
RUN echo 'MAKEFLAGS="-j4"' >> /etc/makepkg.conf

USER user
WORKDIR /home/user
RUN git clone https://aur.archlinux.org/wine-wow64.git
WORKDIR /home/user/wine-wow64

RUN makepkg --syncdeps --noconfirm -o
RUN makepkg


###
### main image
###

FROM archlinux:latest
COPY --from=builder /home/user/wine-wow64/*.zst /tmp
CMD mtgo
ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine

RUN pacman -Syy && \
    pacman -S --noconfirm \
        cabextract \
        libunwind \
        libwbclient \
        libxinerama \
        libxcomposite \
        /tmp/*.zst \
    && pacman -Scc

RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER

WORKDIR /home/wine

COPY extra/host-webbrowser /usr/local/bin/xdg-open
COPY extra/live-mtgo /usr/local/bin/live-mtgo

# Winetricks
ADD https://raw.githubusercontent.com/calheb/winetricks/e3d25a174d27ef5109803e597af2d65085755334/src/winetricks /usr/local/bin/winetricks
RUN chmod 755 /usr/local/bin/winetricks

ENV WINEDEBUG -all,err+all,warn+chain,warn+cryptnet

USER wine
WORKDIR /home/wine
RUN wineboot -i \
    && winetricks -q corefonts calibri tahoma \
    && taskset -c 0 winetricks -q dotnet48 \
    && wineboot -s \
    && rm -rf /home/wine/.cache

RUN winetricks -q sound=alsa ddr=gdi renderer=gdi

USER root

COPY extra/mtgo.sh /usr/local/bin/mtgo
ADD --chown=wine:wine https://mtgo.patch.daybreakgames.com/patch/mtg/live/client/setup.exe?v=8 /opt/mtgo/mtgo.exe

USER user

# hack to allow mounting of user.reg and system.reg from host
# see https://github.com/pauleve/docker-mtgo/issues/6
RUN cd .wine && mkdir host \
    && mv user.reg system.reg host/ \
    && ln -s host/*.reg .
RUN mkdir -p \
    /home/wine/.wine/drive_c/users/wine/Documents\
    /home/wine/.wine/host/wine/Documents
