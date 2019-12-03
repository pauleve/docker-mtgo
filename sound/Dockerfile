FROM panard/mtgo:latest

USER root

RUN apt update && apt install -y --no-install-recommends \
        gstreamer1.0-plugins-good \
        gstreamer1.0-tools \
        gstreamer1.0-pulseaudio \
        pulseaudio-utils \
    && apt autoremove -y --purge \
    && apt clean -y && rm -rf /var/lib/apt/lists/* \
    && for x in alpha avi cutter gio; do \
        rm /usr/lib/i386-linux-gnu/gstreamer-1.0/libgst$x.so; done

COPY pulse-client.conf /etc/pulse/client.conf

USER wine

RUN gst-inspect-1.0

