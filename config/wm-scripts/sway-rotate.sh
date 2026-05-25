#!/usr/bin/env bash
# Auto-rotate the internal panel from the accelerometer. Touch + pen
# follow because they're map_to_output'd to the panel.

set -u

OUT="${1:-eDP-1}"

apply() {
    swaymsg output "$OUT" transform "$1" >/dev/null 2>&1 || true
    # Re-spawn lisgd so it reopens the touch device with the rotated axis
    # calibration that libinput just pushed. swaymsg exec runs in sway's
    # session env (this systemd service's PATH is too narrow for
    # lisgd-sway). The lisgd-sway script itself doesn't read any arg.
    swaymsg exec lisgd-sway >/dev/null 2>&1 || true
}

map_orientation() {
    # X12 panel: iio's left-up/right-up are inverted relative to sway's
    # transform direction, so a 90° tilt was landing on 270° (upside-down).
    case "$1" in
        normal)    echo 0 ;;
        bottom-up) echo 180 ;;
        left-up)   echo 270 ;;
        right-up)  echo 90 ;;
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
