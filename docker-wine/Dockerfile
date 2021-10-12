FROM i386/debian:stable as builder

ENV DEBIAN_FRONTEND noninteractive

WORKDIR /usr/src/wine

RUN apt-get update && \
    apt-get install -y devscripts build-essential wget curl

COPY debian/control /tmp/control
RUN mk-build-deps -i -r -t "apt-get -y --no-install-recommends" /tmp/control

ARG WINE_GIT=wine-mirror/wine
ARG WINE_TAG=wine-6.13
ARG WINE_DIST=devel

RUN curl -L https://github.com/$WINE_GIT/archive/$WINE_TAG.tar.gz \
    | tar xz --strip-components 1

COPY *.patch /usr/src/wine/
RUN for p in *.patch; do patch -p1 < $p; done

COPY debian /usr/src/wine/debian
RUN debuild --no-lintian -us -uc -b -j7
RUN rm -v /usr/src/wine-$WINE_DIST-d*

FROM i386/debian:stable-slim
ENV DEBIAN_FRONTEND noninteractive
ENV WINEARCH win32

COPY --from=builder /usr/src/*.deb /usr/src/

ENV WINE_DIST devel
RUN apt-get update && \
    apt install -y --no-install-recommends \
        libxcomposite1 \
        libxinerama1 \
        libxrandr2 \
        /usr/src/wine-${WINE_DIST}-i386_*_i386.deb \
        /usr/src/wine-${WINE_DIST}_*_i386.deb \
        /usr/src/winehq-${WINE_DIST}_*_i386.deb && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

