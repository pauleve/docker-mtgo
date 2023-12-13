
### build wine-wow64
FROM archlinux:latest as builder

RUN pacman -Syy && pacman -S --noconfirm base-devel curl

RUN useradd -d /home/user -m user
RUN echo 'user ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/user
RUN echo 'MAKEFLAGS="-j4"' >> /etc/makepkg.conf

USER user
WORKDIR /home/user

# 9.0-rc1
# https://aur.archlinux.org/packages/wine-wow64
# https://aur.archlinux.org/cgit/aur.git/commit/?h=wine-wow64
ARG AUR_TAG=5373213607fdc07dcadcc0e18f8ba09b90ae984c

RUN curl -fL https://aur.archlinux.org/cgit/aur.git/snapshot/aur-${AUR_TAG}.tar.gz | tar xzv\
    && mv aur-${AUR_TAG} wine-wow64

WORKDIR /home/user/wine-wow64

USER root
RUN pacman -Syy
USER user
RUN makepkg --syncdeps --noconfirm -o
RUN sed -i 's,$srcdir/$_name-$pkgver,$srcdir/$_name-$_pkgver,' PKGBUILD
RUN cat PKGBUILD; makepkg


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
    && pacman -Scc

RUN pacman -U --noconfirm \
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
