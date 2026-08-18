ARG BASE=panard/mtgo:latest
FROM ${BASE}

USER root

RUN apt update && apt install -y --no-install-recommends \
        python3-minimal \
        gstreamer1.0-plugins-good \
        gstreamer1.0-tools \
        gstreamer1.0-pulseaudio \
        pulseaudio-utils \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/* \
    && for x in alpha avi cutter gio; do \
        rm /usr/lib/*/gstreamer-1.0/libgst$x.so; done

COPY pulse-client.conf /etc/pulse/client.conf

USER wine

RUN gst-inspect-1.0

