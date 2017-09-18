FROM panard/wine:mtgo-2017-09-18
MAINTAINER Panard <panard@backzone.net>
CMD mtgo

RUN	apt-get update \
    && apt-get install -y --no-install-recommends \
        curl \
        xauth \
        xvfb \
    && su - $WINE_USER -c winecfg \
    && su - $WINE_USER -c 'xvfb-run -a winetricks -q corefonts vcrun2015 dotnet452 win7' \
    && rm -rf /home/wine/.cache \
    && apt remove -y --purge xauth xvfb \
    && apt autoremove -y --purge \
	&& apt clean -y && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/mtgo \
    && curl -L http://mtgoclientdepot.onlinegaming.wizards.com/setup.exe -o /opt/mtgo/mtgo.exe

COPY extra/mtgo.sh /usr/local/bin/mtgo
RUN chmod +x /usr/local/bin/mtgo

USER wine
ENV WINEDEBUG -all

# hack to allow mounting of user.reg and system.reg from host
# see https://github.com/pauleve/docker-mtgo/issues/6
RUN cd .wine && mkdir host \
    && mv user.reg system.reg host/ \
    && ln -s host/*.reg .
