#!/usr/bin/env bash
# Toggle squeekboard visibility via D-Bus. Starts the service first if it's
# not running so the bar button still works after a crash or stuck startup.

set -u

BUS="sm.puri.OSK0"
OBJ="/sm/puri/OSK0"

if ! busctl --user get-property "$BUS" "$OBJ" "$BUS" Visible &>/dev/null; then
    systemctl --user start squeekboard.service &>/dev/null || true
    for _ in $(seq 1 50); do
        busctl --user get-property "$BUS" "$OBJ" "$BUS" Visible &>/dev/null && break
        sleep 0.05
    done
fi

current=$(busctl --user get-property "$BUS" "$OBJ" "$BUS" Visible 2>/dev/null \
            | awk '{print $2}')
new="true"
[[ "$current" == "true" ]] && new="false"
exec busctl --user call "$BUS" "$OBJ" "$BUS" SetVisible b "$new"
