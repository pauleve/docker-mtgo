#!/bin/bash
do_winecfg=false
do_sound=false
do_nosound=false
while [ -n "${1:-}" ]; do
   case "${1:-}" in
     --winecfg) do_winecfg=true ;;
     --sound) do_sound=true ;;
     --disable-sound) do_nosound=true ;;
   esac
   shift
done

trap "exit" INT

$do_sound && (winetricks sound=pulse; wineserver -kw)
$do_nosound && (winetricks sound=disabled; wineserver -kw)
$do_winecfg && (winecfg ; wineserver -kw; sleep 1)

wineboot
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
        echo "====== shutting down"
        wineserver -kw
        exit
    fi
done
