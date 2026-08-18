#!/bin/bash
do_winecfg=false
do_sound=false
do_nosound=false
do_audio_patch=true
audio_patch_opts=""
while [ -n "${1:-}" ]; do
   case "${1:-}" in
     --winecfg) do_winecfg=true ;;
     --sound) do_sound=true ;;
     --disable-sound) do_nosound=true ;;
     --no-audio-patch) do_audio_patch=false ;;
     --force-volume) audio_patch_opts="${audio_patch_opts} --force-volume" ;;
   esac
   shift
done

$do_sound || do_audio_patch=false

# MTGO's own audio code does not work under wine; see
# https://github.com/pauleve/docker-mtgo/issues/217
audio_patch() {
    $do_audio_patch || return 0
    if ! command -v mtgo-audio-patch >/dev/null; then
        echo "warning: mtgo-audio-patch is missing, sound will not work" >&2
        do_audio_patch=false
        return 0
    fi
    mtgo-audio-patch ${audio_patch_opts} "${@}"
}

if [ ! -d "${HOME}/.wine/drive_c/windows/syswow64" ]; then
    echo
    echo
    echo "IMPORTANT: This image now uses Windows in 64bit mode (WoW64)"
    echo "You have to reset your settings: "
    echo "       ./run-mtgo --reset"
    echo
    exit 1
fi

trap "exit" INT

run() {
    echo "${@}"
    "${@}"
}

commontricks="gdiplus=builtin"

if $do_sound; then
    gst-inspect-1.0 # seems to help avoiding wine crash when loading gstreamer
    run winetricks ${commontricks} sound=pulse winegstreamer=builtin wmp=builtin
else
    run winetricks ${commontricks} sound=alsa winegstreamer=disabled wmp=disabled
fi
$do_winecfg && (run winecfg ; run wineserver -kw; sleep 1)

run wineboot

# workaround EULA picture
#find ~/.wine/drive_c/ -name 'EULA_en.rtf' -exec sed '/^{\\pict/,/^}/ d' -i "{}" \;

# workaround cert verification crash (wine 6.19)
mkdir -pv ~/.wine/host/wine/AppData/LocalLow

# workaround Z: causing crashes
rm -vf ~/.wine/dosdevices/z\:

cd ~/.wine/drive_c/

workaround_dotnet() {
    D="/home/wine/.wine/drive_c/windows/Microsoft.NET/Framework/v4.0.30319"
    F="mscoreei.dll"
    if [ ! -f "${D}/${F}" ]; then
        echo "THERE IS AN ISSUE WITH DOTNET!"
        echo "Trying to fix it..., wait a moment"
        run wineserver -k
        cd ${D}
        run curl -fOL https://github.com/pauleve/docker-mtgo/raw/master/extra/mscoreei.dll
        return 1
    fi
}
workaround_dotnet

setup="/opt/mtgo/mtgo.exe"

audio_patch

run wine ${setup}
started=0
s=6
while :; do
    sleep $s
    # the client updates itself: patch any freshly installed copy as well, so
    # that sound keeps working after an update (from the next start on)
    audio_patch --quiet
    winedbg --command "info proc"|grep MTGO.exe >/dev/null
    r=$?
    if [ $started -eq 0 ] && [ $r -eq 0 ]; then
        echo "====== MTGO.exe has started."
        started=1
    elif [ $started -eq 1 ] && [ $r -eq 1 ]; then
        echo "====== shutting down"
        run wineserver -kw
        exit
    fi
done
