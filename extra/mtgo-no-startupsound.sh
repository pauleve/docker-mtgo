#!/usr/bin/env bash

MTGO_TOKEN="80e21eca2a0e1258_0003.0004_d2d18fb7f6dd1418" # TODO fetch it
MTGO_VERSION="3.4.113.4034"

LS_BASE="Application Data/Apps/2.0/Data"

WP="${HOME}/.wine"
echo "Debugging information, please include it in any bug report"
echo "----"
if [ -e "${WINEPREFIX}" ]; then
	WP="${WINEPREFIX}"
fi
uname -a
find "${WP}" -iname "local settings" -type d
find "${WP}" -name MTGO.exe
find "${WP}" -name user.config
echo "----"

set -e

write_user_config() {
	cat >"${1}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <userSettings>
        <Shiny.Properties.Settings>
            <setting name="PlayStartupSound" serializeAs="String">
                <value>False</value>
            </setting>
        </Shiny.Properties.Settings>
    </userSettings>
</configuration>
EOF
}

if [ ! -d "${WP}" ]; then
	echo "Cannot find your wine prefix, run wineboot first."
	exit 1
fi
cd "${WP}"
RND=$(grep StateStore_RandomString user.reg | cut -d= -f2 | tr -d '"')
if [ -z "${RND}" ]; then
    echo "Error: no StateStore_RandomString in registry"
    exit 1
fi
MTGO_LS=${RND:0:8}.${RND:8:3}/${RND:11:8}.${RND:19:3}


LS="$(find -iname 'local settings' -type d|head -n1)"
if [ -z "${LS}" ]; then
	echo "Cannot find local settings.. using default"
	LS="drive_c/users/${USER}/Local Settings"
	mkdir -pv "${LS}"
fi
echo "Local Settings: ${LS}"
cd "${LS}"
USER_CONFIG="${LS_BASE}/${MTGO_LS}/mtgo..tion_${MTGO_TOKEN}/Data/${MTGO_VERSION}/user.config"
if [ -f "${USER_CONFIG}" ]; then
	# TODO
	OK=$(grep -A1 PlayStartupSound "${USER_CONFIG}"|tail -n1|grep False|wc -l)
	if [ ${OK} -eq 0 ]; then
		echo "overwritting ${USER_CONFIG}"
		write_user_config "${USER_CONFIG}"
	else
		echo "user.config looks fine"
		cat "${USER_CONFIG}"
	fi
else
	USER_CONFIG_DIR="$(dirname "${USER_CONFIG}")"
	if [ ! -d "${USER_CONFIG_DIR}" ]; then
		mkdir -p "${USER_CONFIG_DIR}"
	fi
	echo "creating ${USER_CONFIG}"
	write_user_config "${USER_CONFIG}"
fi

wineserver -kw

