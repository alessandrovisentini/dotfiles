#!/usr/bin/env bash

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
        # Reset notification flag when battery is charging or above threshold
        ALREADY_NOTIFIED=false
    fi

    sleep 60
done

