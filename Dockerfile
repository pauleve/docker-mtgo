FROM panard/wine:mtgo as builder
MAINTAINER Panard <panard@backzone.net>
ENV WINEPREFIX /dist/dotwine

RUN	apt-get update && \
	apt-get install -y --no-install-recommends \
        curl \
        xauth \
        xvfb

USER $WINE_USER
RUN winecfg && \
    xvfb-run -a winetricks -q corefonts vcrun2015 dotnet452 win7

RUN curl -L http://mtgoclientdepot.onlinegaming.wizards.com/setup.exe -o /dist/mtgo.exe

FROM panard/wine:mtgo
MAINTAINER Panard <panard@backzone.net>

# This Dockerfile is heavily inspired by
# https://github.com/webanck/docker-wine-steam

# Installation of winbind to stop ntlm error messages.
#RUN apt-get install -y --no-install-recommends \
#        winbind

# Installation of p11 to stop p11 kit error messages.
#RUN apt-get install -y --no-install-recommends \
#        p11-kit-modules:i386 \
#        libp11-kit-gnome-keyring:i386


ENV WINEDEBUG -all

#ENV PULSE_SERVER unix:/run/user/$WINE_UID/pulse/native

COPY extra/mtgo.sh /usr/local/bin/mtgo
RUN chmod +x /usr/local/bin/mtgo

COPY --from=builder /dist/mtgo.exe /opt/mtgo/mtgo.exe

USER wine
COPY --from=builder /dist/dotwine $WINEPREFIX
CMD mtgo
