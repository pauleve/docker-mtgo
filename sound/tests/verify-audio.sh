#!/usr/bin/env bash
# Verify that MTGO audio works in the container, without logging into MTGO.
#
#   sound/tests/verify-audio.sh [IMAGE] [DOCKER_VOLUME]
#
# It works on a *copy* of the MTGO installation taken from the (read-only
# mounted) docker volume, so the real installation is never touched, and:
#
#   1. compiles two C# harnesses with the csc.exe of the wine prefix;
#   2. JITs MTGO's audio methods before and after the patch (invalid IL shows
#      up here as InvalidProgramException);
#   3. plays real MTGO sounds through MTGO's own NAudio pipeline into a
#      throw-away PulseAudio sink and measures what comes out;
#   4. replays the same thing the way MTGO ships it, which must fail.
#
# Requirements on the host: docker, pactl, parec, python3.
set -u

IMAGE="${1:-panard/mtgo:sound-local}"
VOLUME="${2:-mtgo64-data-$USER}"
NAME=mtgo-audio-verify
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="$(mktemp -d)"
SINK=mtgoverify
rc=0

cleanup() {
    docker rm -f $NAME >/dev/null 2>&1
    local mod
    mod=$(pactl list short modules 2>/dev/null | awk "/module-null-sink.*$SINK/ {print \$1}")
    [ -n "$mod" ] && pactl unload-module "$mod" >/dev/null 2>&1
    rm -rf "$WORK"
}
trap cleanup EXIT

say() { echo; echo "=== $*"; }
fail() { echo "FAIL: $*" >&2; rc=1; }

say "container $IMAGE, volume $VOLUME (read only)"
docker run -d --name $NAME \
    -v "$VOLUME":/data:ro \
    -v "$REPO/extra":/extra:ro \
    -v "$REPO/sound/tests":/tests:ro \
    -v "/run/user/$(id -u)/pulse/native:/run/user/1000/pulse/native" \
    --entrypoint bash "$IMAGE" -c 'sleep infinity' >/dev/null || exit 1

incontainer() { docker exec ${1:+-e PULSE_SINK=$SINK} $NAME bash -c "$2"; }

say "copying the newest MTGO installation and compiling the harnesses"
docker exec $NAME bash -c '
set -e
export WINEDEBUG=-all
APPSRC=$(find /data -name SharedResources.dll -printf "%T@ %h\n" | sort -n | tail -1 | cut -d" " -f2-)
echo "using $APPSRC"
mkdir -p ~/app && cp -a "$APPSRC/." ~/app/ && cp /tests/*.cs ~/app/
# start from the pristine client when this installation is already patched
BACKUP=$(find /data -path "*mtgo-audio-patch*" -name "SharedResources.dll.orig" \
    -newermt "1970-01-01" | grep -F "$(basename "$APPSRC")" | head -1)
if [ -n "$BACKUP" ]; then echo "restoring pristine DLL from $BACKUP"; cp "$BACKUP" ~/app/SharedResources.dll; fi
wine reg add "HKCU\Software\Wine\Drivers" /v Audio /t REG_SZ /d pulse /f >/dev/null 2>&1
cd ~/app
CSC=$HOME/.wine/drive_c/windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe
wine "$CSC" -nologo -out:JitCheck.exe JitCheck.cs 2>&1 | grep -i "error" || true
wine "$CSC" -nologo -out:PlayTest.exe -r:NAudio.Core.dll -r:NAudio.WinMM.dll \
    -r:NAudio.Wasapi.dll -r:netstandard.dll PlayTest.cs 2>&1 | grep -i "error" || true
test -f JitCheck.exe -a -f PlayTest.exe' || { fail "could not build the harnesses"; exit 1; }

jit() {
    docker exec $NAME bash -c 'cd ~/app && WINEDEBUG=-all timeout 300 wine JitCheck.exe \
        "$HOME/app/SharedResources.dll" "$HOME/app" 2>&1' | grep -v -e '^0[0-9a-f]*:err:'
}

say "unpatched client (baseline: valid IL, and audio effectively muted)"
out=$(jit); echo "$out"
echo "$out" | grep -q 'JIT: .* 0 failed' || fail "the unpatched client does not JIT"
echo "$out" | grep -qE 'GetWindowsVolume\(\) = 0' \
    || echo "note: wine reported a non-zero master volume here"

say "applying the patch"
docker exec $NAME python3 /extra/mtgo-audio-patch.py --app-dir /home/wine/app || fail "patch failed"

say "patched client (must JIT and report a usable volume)"
out=$(jit); echo "$out"
echo "$out" | grep -q 'JIT: .* 0 failed' || fail "the patched client produces invalid IL"
echo "$out" | grep -q 'GetWindowsVolume() = 1' || fail "GetWindowsVolume() is still muting"

say "playing MTGO sounds into a throw-away sink"
pactl load-module module-null-sink sink_name=$SINK \
    sink_properties=device.description=$SINK >/dev/null || exit 1
( timeout 20 parec -d $SINK.monitor --format=s16le --rate=44100 --channels=2 \
    --file-format=raw > "$WORK/capture.raw" 2>/dev/null & )
out=$(incontainer sink 'cd ~/app && WINEDEBUG=-all timeout 300 wine PlayTest.exe patched \
    Audio/Alerts/GAME_BEGIN.wav Audio/Duel/WIN.wav Audio/Card/CARD_TAP_01.wav 2>&1' \
    | grep -v -e '^0[0-9a-f]*:err:')
echo "$out"
echo "$out" | grep -q 'RESULT: OK' || fail "the patched pipeline could not play"
wait 2>/dev/null
sleep 1
python3 - "$WORK/capture.raw" <<'PY' || fail "no audible samples reached PulseAudio"
import array, math, sys
a = array.array('h')
a.frombytes(open(sys.argv[1], 'rb').read())
n = len(a) or 1
peak = max((abs(x) for x in a), default=0)
rms = math.sqrt(sum(float(x) * x for x in a) / n)
print('captured %.1f s, peak=%d rms=%.1f' % (len(a) / 2 / 44100, peak, rms))
sys.exit(0 if peak > 1000 else 1)
PY

say "control: the pipeline as MTGO ships it (must fail under wine)"
out=$(incontainer sink 'cd ~/app && WINEDEBUG=-all timeout 300 wine PlayTest.exe orig \
    Audio/Alerts/GAME_BEGIN.wav 2>&1' | grep -v -e '^0[0-9a-f]*:err:')
echo "$out"
echo "$out" | grep -q 'RESULT: FAILED' \
    || echo "note: the unpatched pipeline worked here, wine may have gained Media Foundation support"

echo
[ $rc -eq 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $rc
