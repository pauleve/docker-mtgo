#!/bin/bash

image=panard/mtgo:latest
cmd=""
opts=""

args="$(getopt --longoptions winecfg,shell,name: -- "${0}" "${@}")"
eval set -- $args

defaultcmd="bash mtgo.sh"

while [ -n "${1:-}" ]; do
case "${1:-}" in
    --winecfg)
        cmd="${defaultcmd} $1" ;;
    --shell)
        cmd="bash" ;;
     --name) shift;
        opts="${opts} --name $1" ;;
     --) shift ;
        if [ -n "${1:-}" ]; then
            image=$1
        fi ;;
esac
shift
done

run() {
    echo "${@}"
    "${@}"
}

#-v /run/user/`id -u`/pulse/native:/run/user/1000/pulse/native \

xhost +si:localuser:$(whoami)
run docker run --privileged --rm -it -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    -v /etc/localtime:/etc/localtime:ro \
    -v /dev/snd:/dev/snd \
    ${opts} ${image} ${cmd}

