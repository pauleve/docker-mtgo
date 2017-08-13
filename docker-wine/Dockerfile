FROM i386/debian:stretch-slim as builder
MAINTAINER Panard <panard@inzenet.org>

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /usr/src

RUN apt-get update && \
    apt-get install -y devscripts build-essential

#ENV WINE_GIT 178104b59b0415fd24f48a14f921a30d03fcef3e
ENV WINE_GIT mtgo
RUN curl -LO https://github.com/theli-ua/wine/archive/${WINE_GIT}.zip && \
    unzip ${WINE_GIT}.zip
WORKDIR /usr/src/wine-$WINE_GIT

COPY debian-devel /usr/src/wine-$WINE_GIT/debian
RUN curl -L https://source.winehq.org/patches/data/136421 \
    | patch -p1

RUN mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control
RUN debuild --no-lintian -us -uc -b -j3
RUN rm -v /usr/src/wine-devel-d*

FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@inzenet.org>
ENV DEBIAN_FRONTEND noninteractive
ENV WINEARCH win32

COPY --from=builder /usr/src/*.deb /usr/src/
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        cabextract \
        curl \
        libglib2.0-0 \
        libgphoto2-6 \
        libgphoto2-port12 \
        libgstreamer-plugins-base1.0-0 \
        libgstreamer1.0-0 \
        liblcms2-2 \
        libldap-2.4-2 \
        libmpg123-0 \
        libopenal1 \
        libpcap0.8 \
        libxml2 \
        libncurses5 \
        libasound2-plugins && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/* && \
    dpkg -i \
        /usr/src/wine-devel-i386_2.2.0~stretch_i386.deb \
        /usr/src/wine-devel_2.2.0~stretch_i386.deb \
        /usr/src/winehq-devel_2.2.0~stretch_i386.deb && \
    rm /usr/src/*

RUN	curl -L -o /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

