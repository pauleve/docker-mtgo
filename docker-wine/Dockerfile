FROM i386/debian:stretch-slim as builder
MAINTAINER Panard <panard@inzenet.org>

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /usr/src

RUN apt-get update && \
    apt-get install -y devscripts build-essential

ENV WINE_GIT 46fdc6bf9c1be800935440b7b55a5b6d3dfd9b79
RUN curl -L https://github.com/theli-ua/wine/archive/${WINE_GIT}.tar.gz \
    | tar xvz
WORKDIR /usr/src/wine-$WINE_GIT

ENV WINE_DIST devel
COPY debian-${WINE_DIST} /usr/src/wine-$WINE_GIT/debian
RUN if [ ${WINE_DIST} = staging ]; then \
    curl -L https://github.com/wine-compholio/wine-staging/archive/master.tar.gz \
    | tar xvz --strip-components 1; fi

RUN mk-build-deps -i -r -t "apt-get -y --no-install-recommends" debian/control
RUN debuild --no-lintian -us -uc -b -j3
RUN rm -v /usr/src/wine-$WINE_DIST-d*

FROM i386/debian:stretch-slim
MAINTAINER Panard <panard@inzenet.org>
ENV DEBIAN_FRONTEND noninteractive
ENV WINEARCH win32

COPY --from=builder /usr/src/*.deb /usr/src/

ENV WINE_DIST devel
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

