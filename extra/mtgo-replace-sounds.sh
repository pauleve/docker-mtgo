#!/usr/bin/env bash
WP="${HOME}/.wine"
if [ -e "${WINEPREFIX}" ]; then
	WP="${WINEPREFIX}"
fi
SOUND=`realpath "$1"`
find ${WP}/drive_c -name MTGO.exe -printf '%h\0' | xargs -0 -i find {} -name '*.wav' -exec cp -v ${SOUND} {} \;
