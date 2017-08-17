FROM panard/wine:mtgo as builder
MAINTAINER Panard <panard@backzone.net>
ENV WINEPREFIX /dist/dotwine

RUN	apt-get update && \
	apt-get install -y --no-install-recommends \
        curl \
        xauth \
        xvfb

RUN mkdir -p $WINEPREFIX && \
    winecfg && \
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


# replace by your user id
ENV HOME /home/wine
WORKDIR /home/wine
ENV WINEPREFIX /home/wine/.wine
ENV WINEDEBUG -all

ENV WINE_UID 1000
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash wine

# Adding the link to the pulseaudio server for the client to find it.
ENV PULSE_SERVER unix:/run/user/$WINE_UID/pulse/native

USER wine
COPY --from=builder /dist/dotwine $WINEPREFIX
COPY --from=builder /dist/mtgo.exe $HOME/mtgo.exe
COPY extra/mtgo.sh $HOME/mtgo

USER root
RUN chown -R wine: $HOME && \
    chmod +x $HOME/mtgo

USER wine
CMD $HOME/mtgo
