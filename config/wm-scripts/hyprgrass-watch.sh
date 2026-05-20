#!/usr/bin/env bash
# Re-source hyprgrass binds whenever the compositor reloads its config
# (reload wipes runtime-registered gesture binds).

set -u

SIG="${HYPRLAND_INSTANCE_SIGNATURE:-}"
if [[ -z "$SIG" ]]; then
    echo "hyprgrass-watch: no HYPRLAND_INSTANCE_SIGNATURE in env" >&2
    exit 1
fi

SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${SIG}/.socket2.sock"

# Lines are `EVENT>>data`; only configreloaded matters.
@SOCAT@ -u "UNIX-CONNECT:$SOCK" - | while IFS= read -r line; do
    case "$line" in
        configreloaded*)
            hyprctl keyword source /etc/hypr/gestures-binds.conf \
                >/dev/null 2>&1
            ;;
    esac
done
