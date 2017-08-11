#!/bin/bash

image=${1:-panard/mtgo:latest}

run() {
    echo "${@}"
    "${@}"
}

opts=""
    #-v /run/user/`id -u`/pulse/native:/run/user/1000/pulse/native \

xhost +si:localuser:$(whoami)
run docker run --privileged --rm -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /dev/snd:/dev/snd \
    ${opts} \
    -it $image
