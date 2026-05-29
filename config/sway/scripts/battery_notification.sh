#!/usr/bin/env bash

# Single-instance guard: sway's `exec_always` re-runs this script on
# every config reload, so without a lock the loops pile up and the
# critical notification fires once per running copy.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/battery_notification.lock"
flock -n 9 || exit 0

LOW_BATTERY_THRESHOLD=15
NOTIFY_ICON="battery-caution"
ALREADY_NOTIFIED=false

while true; do
    BATTERY_LEVEL=$(cat /sys/class/power_supply/BAT0/capacity)
    BATTERY_STATUS=$(cat /sys/class/power_supply/BAT0/status)

    if [[ "$BATTERY_LEVEL" -le "$LOW_BATTERY_THRESHOLD" && "$BATTERY_STATUS" == "Discharging" ]]; then
        if [[ "$ALREADY_NOTIFIED" == false ]]; then
            notify-send -u critical -i "$NOTIFY_ICON" "Battery" "${BATTERY_LEVEL}%"
            ALREADY_NOTIFIED=true
        fi
    else
        ALREADY_NOTIFIED=false
    fi

    sleep 60
done

