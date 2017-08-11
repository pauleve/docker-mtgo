FROM wine:stable
MAINTAINER Panard <panard@backzone.net>

# This Dockerfile is heavily inspired by
# https://github.com/webanck/docker-wine-steam

ENV WINE_UID 1000

# Creating the wine user and setting up dedicated non-root environment: replace 1001 by your user id (id -u) for X sharing.
RUN useradd -u $WINE_UID -d /home/wine -m -s /bin/bash wine
ENV HOME /home/wine
WORKDIR /home/wine

# Setting up the wineprefix to force 32 bit architecture.
ENV WINEPREFIX /home/wine/.wine
ENV WINEARCH win32

# Disabling warning messages from wine, comment for debug purpose.
ENV WINEDEBUG -all

# Adding the link to the pulseaudio server for the client to find it.
ENV PULSE_SERVER unix:/run/user/$WINE_UID/pulse/native

RUN	apt-get update && \
	apt-get install -y --no-install-recommends \
        wget \
        winbind \
        xvfb \
        zenity

USER wine
RUN winecfg && \
	xvfb-run -a winetricks -q corefonts vcrun2015 dotnet452 win7

RUN wget http://mtgoclientdepot.onlinegaming.wizards.com/setup.exe -O mtgo.exe

RUN xvfb-run -a wine mtgo.exe

USER root
RUN apt-get autoremove -y --purge xvfb && \
	apt-get autoremove -y --purge && \
	apt-get clean -y && \
	rm -rf /home/wine/.cache && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER wine
COPY extra/mtgo.sh $HOME/mtgo.sh
CMD bash $HOME/mtgo.sh
