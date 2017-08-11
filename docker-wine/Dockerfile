FROM ubuntu:17.04
MAINTAINER Panard <panard@inzenet.org>
ENV DEBIAN_FRONTEND noninteractive
ENV WINEARCH win32
RUN	dpkg --add-architecture i386 && \
	apt-get update && \
	apt-get install -y --no-install-recommends \
        software-properties-common \
        cabextract \
        libasound2-plugins:i386 \
        pulseaudio:i386 \
        wget && \
    wget https://dl.winehq.org/wine-builds/Release.key && \
    apt-key add Release.key && rm Release.key && \
    apt-add-repository 'http://dl.winehq.org/wine-builds/ubuntu/' && \
    apt-get autoremove -y --purge software-properties-common && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

ARG WINE_BUILD
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        winehq-$WINE_BUILD && \
	wget -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

