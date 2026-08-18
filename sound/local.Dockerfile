# Sound image built on top of an already available base image (by default the
# one published on the hub), so that the wine audio support of issue #217 can be
# used without rebuilding the whole wine/dotnet base.
#
#   make sound-local
#   ./run-mtgo --sound panard/mtgo:sound-local
#
# This is the docker context of the repository, not of the sound/ directory.
ARG BASE=panard/mtgo:sound-base
FROM ${BASE}

USER root
COPY extra/mtgo.sh /usr/local/bin/mtgo
COPY extra/mtgo-audio-patch.py /usr/local/bin/mtgo-audio-patch
RUN chmod 755 /usr/local/bin/mtgo /usr/local/bin/mtgo-audio-patch
USER wine
