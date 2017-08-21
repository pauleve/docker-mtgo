FROM i386/debian:stretch-slim as builder
MAINTAINER Panard <panard@inzenet.org>

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /usr/src

RUN apt-get update && \
    apt-get install -y devscripts build-essential

ENV WINE_GIT 92c20d4b55de2bb8017c34c4d29c7410fad2424e
RUN curl -L https://github.com/theli-ua/wine/archive/${WINE_GIT}.tar.gz \
    | tar xvz
WORKDIR /usr/src/wine-$WINE_GIT

ENV WINE_DIST staging
COPY debian-${WINE_DIST} /usr/src/wine-$WINE_GIT/debian
RUN mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control

ENV WINE_STAGING ea6cb581031dd8c78437708ecf7a08a93a27d534
RUN if [ ${WINE_DIST} = staging ]; then \
    curl -L https://github.com/wine-compholio/wine-staging/archive/$WINE_STAGING.tar.gz \
    | tar xvz --strip-components 1; fi
RUN if [ ${WINE_DIST} = staging ]; then \
	./patches/patchinstall.sh DESTDIR="$PWD" --all \
        -W windowscodecs-GIF_Encoder \
        -W windowscodecs-Palette_Images \
        -W windowscodecs-32bppPRGBA \
        -W windowscodecs-TIFF_Support \
        -W windowscodecs-IWICPalette_InitializeFromBitmap \
        -W gdiplus-Grayscale_PNG \
    ; fi

RUN debuild --no-lintian -us -uc -b -j7
RUN rm -v /usr/src/wine-$WINE_DIST-d*

FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@inzenet.org>
ENV DEBIAN_FRONTEND noninteractive
ENV WINEARCH win32

COPY --from=builder /usr/src/*.deb /usr/src/

ENV WINE_DIST staging
RUN apt-get update && \
    apt install -y --no-install-recommends \
        ca-certificates \
        cabextract \
        curl \
        /usr/src/wine-${WINE_DIST}-i386_2.2.0~stretch_i386.deb \
        /usr/src/wine-${WINE_DIST}_2.2.0~stretch_i386.deb \
        /usr/src/winehq-${WINE_DIST}_2.2.0~stretch_i386.deb && \
	apt clean -y && \
	rm -rf /var/lib/apt/lists/* && \
    rm /usr/src/*

RUN	curl -L -o /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

ENV WINE_USER wine
ENV WINE_UID 1000
ENV WINEPREFIX /home/wine/.wine
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash $WINE_USER
WORKDIR /home/wine

