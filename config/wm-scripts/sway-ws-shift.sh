#!/usr/bin/env bash
# sway-ws-shift <next|prev>
# Move to the adjacent workspace by number, creating it on demand.
# `swaymsg workspace next/prev` only cycles existing workspaces.

set -u

dir="${1:-next}"
cur=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .num' 2>/dev/null)
[[ "$cur" =~ ^[0-9]+$ ]] || exit 0

if [[ "$dir" == "prev" ]]; then
    target=$((cur - 1))
    ((target < 1)) && target=1
else
    target=$((cur + 1))
fi

exec swaymsg workspace number "$target"
