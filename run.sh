#!/bin/bash

image=panard/mtgo:latest
cmd=""
opts=""

args="$(getopt --longoptions winecfg,cmd:,name: -- "${0}" "${@}")"
eval set -- $args

defaultcmd="bash mtgo.sh"

while [ -n "${1:-}" ]; do
case "${1:-}" in
    --winecfg)
        cmd="${defaultcmd} $1" ;;
    --cmd) shift;
        cmd="$1" ;;
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
#-v /etc/localtime:/etc/localtime:ro \
#-v $HOME/.Xauthority:/home/wine/.Xauthority:ro \
#-v /dev/snd:/dev/snd \
#--net=host \

run docker run --privileged --rm -it -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    ${opts} ${image} ${cmd}

