#!/usr/bin/env bash
# Statusline for swaybar: network, volume, brightness, battery, clock.
#
# Event-driven: the clock reprints every second, and volume/brightness changes
# wake the loop immediately (pactl + udev subscriptions) so they update in real
# time instead of waiting for the next tick. Network is the slow poll
# (nmcli/D-Bus), so it's refreshed at most every few seconds and cached.

net() {
    if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^ethernet:connected'; then
        printf '󰈀 Ethernet'
        return
    fi
    # Terse single-field reads avoid the escaped-colon mess of multi-field
    # output and stay locale-independent.
    ssid=$(nmcli -t -f ACTIVE,SSID device wifi 2>/dev/null | sed -n 's/^yes://p' | head -1)
    if [ -n "$ssid" ]; then
        printf '󰖩 %s' "$ssid"
    else
        printf '󰖪 Disconnected'
    fi
}

vol() {
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    case "$out" in
        *MUTED*) printf '󰖁 muted' ;;
        *) printf '󰕾 %s%%' "$(printf '%s' "$out" | awk '{printf "%d", $2*100}')" ;;
    esac
}

bri() {
    printf '󰃟 %s' "$(brightnessctl -m 2>/dev/null | cut -d, -f4)"
}

bat() {
    cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)
    case "$(cat /sys/class/power_supply/BAT0/status 2>/dev/null)" in
        Charging|Full) ic='󰂄' ;;
        *)             ic='󰁹' ;;
    esac
    printf '%s %s%%' "$ic" "$cap"
}

# Wake channel: the watchers write here on volume/brightness changes; the main
# loop reads it with a per-second timeout so the clock still ticks on its own.
fifo="${XDG_RUNTIME_DIR:-/tmp}/swaybar-status.$$"
rm -f "$fifo"; mkfifo "$fifo" || exit 1
exec 3<>"$fifo"

pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT
trap 'exit 0' INT TERM

# Write-only opens, so a watcher dies on SIGPIPE if the main loop ever goes away
# (e.g. swaybar restarts it) even when the EXIT trap doesn't run.
stdbuf -oL pactl subscribe >"$fifo" 2>/dev/null &
pids+=($!)
stdbuf -oL udevadm monitor --udev --subsystem-match=backlight >"$fifo" 2>/dev/null &
pids+=($!)

net_cache=""
net_last=0
net_every=5

render() {
    now=$(date +%s)
    if [ $((now - net_last)) -ge "$net_every" ]; then
        net_cache=$(net)
        net_last=$now
    fi
    printf '%s   %s   %s   %s   %s\n' \
        "$net_cache" "$(vol)" "$(bri)" "$(bat)" "$(date '+%a %d/%m/%Y   %H:%M:%S')"
}

render
while true; do
    # Wake on the next whole second (clock tick) or on an event. Aligning to the
    # second keeps per-iteration work from drifting and skipping seconds.
    timeout=$(date +%N | awk '{ s = 1 - $1 / 1e9; if (s <= 0) s = 0.001; printf "%.3f", s }')
    if read -t "$timeout" -u 3 -r line; then
        # Re-render only for sink (volume/mute) and backlight events. Ignore the
        # client churn our own wpctl polling triggers, or it self-feeds forever.
        case $line in
            *"on sink "*|*backlight*) render ;;
        esac
    else
        render
    fi
done
