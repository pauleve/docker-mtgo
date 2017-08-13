#!/bin/bash

defaultcmd="bash mtgo.sh"

image=panard/mtgo:latest
cmd=$defaultcmd
opts=""

args="$(getopt --longoptions winecfg,cmd:,name: -- "${0}" "${@}")"
eval set -- $args


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

#opts="${opts} -v /etc/localtime:/etc/localtime:ro"
opts="${opts} -v $HOME/.Xauthority:/home/wine/.Xauthority:ro"
opts="${opts} --net=host"

#-v /run/user/`id -u`/pulse/native:/run/user/1000/pulse/native \
#-v /dev/snd:/dev/snd \
#--net=host \

run docker run --privileged --rm -it -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    ${opts} ${image} ${cmd}

