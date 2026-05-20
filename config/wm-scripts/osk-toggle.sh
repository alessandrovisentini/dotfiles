#!/usr/bin/env bash
# Toggle squeekboard visibility via its D-Bus property.

set -u

BUS="sm.puri.OSK0"
OBJ="/sm/puri/OSK0"

current=$(busctl --user get-property "$BUS" "$OBJ" "$BUS" Visible 2>/dev/null \
            | awk '{print $2}')
new="true"
[[ "$current" == "true" ]] && new="false"
exec busctl --user call "$BUS" "$OBJ" "$BUS" SetVisible b "$new"
