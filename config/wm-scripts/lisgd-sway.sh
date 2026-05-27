#!/usr/bin/env bash
# Touchscreen gestures via lisgd. Watches libinput touch events without
# grabbing them, so normal taps still pass through.
#
# Touch axes follow the sway output transform on their own (driver/
# libinput via `map_to_output` in sway's input config), so a user
# swipe-up lands as raw DU in every rotation. No remap needed.

set -u

pkill -x lisgd 2>/dev/null || true

# Touchscreen event nodes aren't stable across boots; resolve by name.
dev=""
for namefile in /sys/class/input/event*/device/name; do
    name=$(cat "$namefile" 2>/dev/null) || continue
    case "$name" in
        *Wacom*Finger*|*HID*Finger*|*Finger*)
            ev=$(printf '%s' "$namefile" | grep -oE 'event[0-9]+')
            dev="/dev/input/$ev"
            break
            ;;
    esac
done

if [[ -z "$dev" ]]; then
    echo "lisgd-sway: no touchscreen 'Finger' device found" >&2
    exit 1
fi

# Gesture spec: fingercount,direction,edge,distance,actmode,command
# direction is start->end (swipe up = "DU"); actmode R = fire on release.
exec lisgd -d "$dev" \
    -g "3,DU,*,*,R,grid-toggle" \
    -g "4,UD,*,*,R,swaymsg kill" \
    -g "2,DU,*,*,R,wtype -k Up" \
    -g "2,UD,*,*,R,wtype -k Down" \
    -g "3,RL,*,*,R,sway-ws-shift next" \
    -g "3,LR,*,*,R,sway-ws-shift prev"
