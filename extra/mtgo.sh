#!/bin/bash
do_winecfg=false
do_sound=false
while [ -n "${1:-}" ]; do
   case "${1:-}" in
     --winecfg)
        do_winecfg=true
        ;;
     --sound)
        do_sound=true
        ;;
   esac
   shift
done

trap "exit" INT

$do_winecfg && (winecfg ; wineserver -kw; sleep 1)
if $do_sound; then
    winetricks sound=pulse
    wineserver -kw
else
    winetricks sound=disabled
    wineserver -kw
fi
wine /opt/mtgo/mtgo.exe
started=0
s=1
while :; do
    sleep $s
    pidof MTGO.exe >/dev/null
    r=$?
    if [ $started -eq 0 ] && [ $r -eq 0 ]; then
        echo "====== MTGO.exe has started."
        started=1
        s=3
    elif [ $started -eq 1 ] && [ $r -eq 1 ]; then
        echo "====== shuting down"
        wineserver -kw
        exit
    fi
done
