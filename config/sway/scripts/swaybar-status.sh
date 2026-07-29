#!/usr/bin/env bash
# Statusline for swaybar: network, brightness, volume, battery, date + clock.
#
# Event-driven: the clock only needs to reprint once a minute, so brightness,
# volume and network changes are picked up from udev/pactl/nmcli subscriptions
# instead of polling. Without them a volume keypress could sit unshown for the
# best part of a minute.

# First real battery. hidpp_battery_* (wireless mouse) and the ucsi-source-psy-*
# USB-C port supplies also live here, so match the plain BATn naming only.
battery=$(ls -d /sys/class/power_supply/BAT[0-9]* 2>/dev/null | head -1)

# Deliberately reads `device status` and not `device wifi`: listing access
# points makes NetworkManager rescan once its cached scan goes stale, and nmcli
# then blocks for about five seconds waiting on it. Device status is a cheap
# lookup that already carries the connection name.
#
# nmcli is gettext-localized, so the state match needs a pinned locale. Only
# this call gets it — the clock still wants the system locale for the day name.
net() {
    status=$(LC_ALL=C nmcli -t -f TYPE,STATE,CONNECTION device status 2>/dev/null)

    # The trailing colon matters: it keeps "connected (externally)" devices,
    # such as loopback and docker bridges, from matching.
    case $status in
        *"ethernet:connected:"*) printf '󰈀 Ethernet'; return ;;
    esac

    ssid=$(printf '%s\n' "$status" | sed -n 's/^wifi:connected://p' | head -1)
    if [ -n "$ssid" ]; then
        printf '󰖩 %s' "$ssid"
    else
        printf '󰖪 Disconnected'
    fi
}

bri() {
    printf '󰃟 %s' "$(brightnessctl -m 2>/dev/null | cut -d, -f4)"
}

vol() {
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
    case "$out" in
        *MUTED*) printf '󰖁 muted' ;;
        *)       printf '󰕾 %s%%' "$(printf '%s' "$out" | awk '{printf "%d", $2*100}')" ;;
    esac
}

bat() {
    [ -n "$battery" ] || return
    case "$(cat "$battery/status" 2>/dev/null)" in
        Charging|Full) ic='󰂄' ;;
        *)             ic='󰁹' ;;
    esac
    printf '%s %s%%' "$ic" "$(cat "$battery/capacity" 2>/dev/null)"
}

# Day name comes from LC_TIME, so it follows the system locale.
clock() {
    date '+%a %d/%m/%Y   %H:%M'
}

# Wake channel: the watchers write here on change; the main loop reads it with a
# timeout so the clock still ticks on its own.
fifo="${XDG_RUNTIME_DIR:-/tmp}/swaybar-status.$$"
rm -f "$fifo"; mkfifo "$fifo" || exit 1
exec 3<>"$fifo"

pids=()
cleanup() { kill "${pids[@]}" 2>/dev/null; rm -f "$fifo"; }
trap cleanup EXIT
trap 'exit 0' INT TERM

# Write-only opens, so a watcher dies on SIGPIPE if the main loop ever goes away
# (e.g. swaybar restarts it) even when the EXIT trap doesn't run.
stdbuf -oL udevadm monitor --udev --subsystem-match=backlight >"$fifo" 2>/dev/null &
pids+=($!)
stdbuf -oL pactl subscribe >"$fifo" 2>/dev/null &
pids+=($!)
stdbuf -oL nmcli monitor >"$fifo" 2>/dev/null &
pids+=($!)

# Network is the only read that spawns a process, so it's cached and refreshed
# on the minute tick or when NetworkManager reports a change — not on every
# volume or brightness keypress.
net_cache=$(net)

render() {
    printf '%s   %s   %s   %s   %s\n' "$net_cache" "$(bri)" "$(vol)" "$(bat)" "$(clock)"
}

render
while true; do
    # Wake on the next whole minute (clock tick) or on an event. Aligning to the
    # minute keeps the displayed time from lagging behind the real one.
    timeout=$(date '+%S %N' | awk '{ s = 60 - $1 - $2 / 1e9; if (s <= 0) s = 0.001; printf "%.3f", s }')
    if read -t "$timeout" -u 3 -r line; then
        case $line in
            # udev backlight change.
            *backlight*)  render ;;
            # pactl sink change (volume or mute).
            *"on sink "*) render ;;
            # Every other pactl line is churn, including the client new/remove
            # pair our own wpctl reads trigger — re-rendering on those would
            # self-feed forever.
            Event*) ;;
            # udevadm prints a three-line banner at startup; it carries no
            # event, so it must not count as a network change either.
            monitor*|UDEV*|"") ;;
            # What's left is nmcli monitor: NetworkManager state changed.
            *) net_cache=$(net); render ;;
        esac
    else
        net_cache=$(net)
        render
    fi
done
