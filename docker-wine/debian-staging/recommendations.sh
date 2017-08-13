#!/bin/bash
#
# Script to generate recommendations for Wine.
#
# Copyright (C) 2016 Michael Müller
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
#

set -eu

cc_flags="$1"
config="$2"
varfile="$3"


ignore_list=("libodbc.so" "libnetapi.so" "libGL.so.1")
lib_list=()

contains_element()
{
	local e
	for e in "${@:2}"; do
		[[ "$e" == "$1" ]] && return 0
	done
	return 1
}

# Find library names
for lib in $(grep "^#define SONAME_" "$config" | cut -d '"' -f2); do
	if ! contains_element "$lib" "${ignore_list[@]}"; then
		lib_list+=("$lib")
	fi
done

# Generate dummy executable
tmp_file=$(mktemp)
echo "int main(){return 0;}" | "$CC" "$cc_flags" -x c -o "$tmp_file" - \
	-Wl,--no-as-needed -Wl,--no-copy-dt-needed-entries "${lib_list[@]/#/-l:}"

# Verify that the linking was really successful
list_imports=$(ldd "$tmp_file")

for lib in "${lib_list[@]}"; do
	if ! [[ "$list_imports" == *"$lib"* ]]; then
		echo "ERROR: Something went wrong, dummy program was not linked against $lib" >&2
		exit 1
	fi
done

# Let dpkg-shlibdeps generate a dependency list
dpkg-shlibdeps -T"$varfile" -pwine -dRecommends --warnings=0 -e "$tmp_file"

rm "$tmp_file"
exit 0
