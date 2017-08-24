#!/bin/bash
do_winecfg=false
while [ -n "${1:-}" ]; do
   case "${1:-}" in
     --winecfg)
        do_winecfg=true
        ;;
   esac
   shift
done

$do_winecfg && (winecfg ; wineserver -kw)
wine /opt/mtgo/mtgo.exe
echo "MTGO will start shortly. Press Enter when you have exited it."
read
wineserver -kw
