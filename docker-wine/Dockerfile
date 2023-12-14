FROM debian:stable as builder

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update &&\
    apt-get install -y devscripts build-essential wget curl


ENV CFLAGS="-O2 -pipe"

WORKDIR /usr/src/wine

COPY debian/control /tmp/control
RUN mk-build-deps -i -r -t "apt-get -y --no-install-recommends" /tmp/control

ARG WINE_GIT=wine-mirror/wine
ARG WINE_TAG=wine-9.0-rc1
ARG WINE_DIST=devel
ARG INSTALL_PREFIX=/opt/wine
RUN curl -L https://github.com/$WINE_GIT/archive/$WINE_TAG.tar.gz \
    | tar xz --strip-components 1

COPY *.patch /usr/src/wine/
RUN for p in *.patch; do patch -p1 < $p; done

WORKDIR /usr/src/wine/build
RUN ../configure \
    --without-tests \
    --prefix=$INSTALL_PREFIX \
    --libdir=$INSTALL_PREFIX/lib \
    --enable-archs=x86_64,i386
RUN make
RUN make install
RUN i686-w64-mingw32-strip --strip-unneeded "$INSTALL_PREFIX"/lib/wine/i386-windows/*.dll
RUN x86_64-w64-mingw32-strip --strip-unneeded "$INSTALL_PREFIX"/lib/wine/x86_64-windows/*.dll

FROM debian:stable-slim
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt install -y --no-install-recommends \
        libxcomposite1 \
        libxinerama1 \
        libxrandr2 && \
    apt clean -y && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/wine/ /opt/wine/

ENV PATH=/opt/wine/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
