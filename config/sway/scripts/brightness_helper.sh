#!/usr/bin/env bash

# brightness_helper.sh up|down [step]

STEP=${2:-5}
case $1 in
    up)   CHANGE="+${STEP}%" ;;
    down) CHANGE="${STEP}%-" ;;
    *)    echo "usage: $0 up|down [step]" >&2; exit 1 ;;
esac

# Machine output is "device,class,current,percent,max".
VALUE=$(brightnessctl -m set "$CHANGE" | cut -d, -f4 | tr -d '%')

command -v notify-send >/dev/null || exit 0
notify-send \
    --expire-time 800 \
    --hint string:x-canonical-private-synchronous:brightness \
    --hint "int:value:$VALUE" \
    --transient \
    "Brightness: ${VALUE}%"
