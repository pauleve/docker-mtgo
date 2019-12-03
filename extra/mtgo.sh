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

run() {
    echo "${@}"
    "${@}"
}

commontricks="gdiplus=native"

if $do_sound; then
    gst-inspect-1.0 # seems to help avoiding wine crash when loading gstreamer
    run winetricks ${commontricks} sound=pulse winegstreamer=builtin
else
    run winetricks ${commontricks} sound=disabled winegstreamer=disabled
fi
$do_winecfg && (run winecfg ; run wineserver -kw; sleep 1)

run wineboot

# workaround EULA picture
#find ~/.wine/drive_c/ -name 'EULA_en.rtf' -exec sed '/^{\\pict/,/^}/ d' -i "{}" \;

run wine /opt/mtgo/mtgo.exe
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
        run wineserver -kw
        exit
    fi
done
