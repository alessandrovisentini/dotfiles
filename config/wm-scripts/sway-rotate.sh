#!/usr/bin/env bash
# Auto-rotate the internal panel from the accelerometer. Touch + pen
# follow because they're map_to_output'd to the panel.

set -u

OUT="${1:-eDP-1}"

apply() {
    swaymsg output "$OUT" transform "$1" >/dev/null 2>&1 || true
}

map_orientation() {
    case "$1" in
        normal)    echo 0 ;;
        bottom-up) echo 180 ;;
        left-up)   echo 90 ;;
        right-up)  echo 270 ;;
        *)         echo "" ;;
    esac
}

# monitor-sensor prints both an initial "(orientation: X, ...)" line and
# later "orientation changed: X" lines; pull the token out of either.
stdbuf -oL monitor-sensor 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        *orientation*)
            orient=$(printf '%s' "$line" \
                | grep -oE 'orientation(:| changed:) [a-z-]+' \
                | grep -oE '[a-z-]+$')
            [[ -z "$orient" ]] && continue
            t=$(map_orientation "$orient")
            [[ -n "$t" ]] && apply "$t"
            ;;
    esac
done
