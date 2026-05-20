#!/usr/bin/env bash
# Toggle a HyprPanel menu (dashboardmenu, notificationsmenu, calendarmenu, ...)
# via its IPC. Used by gestures and keybinds.

set -u

menu="${1:-dashboardmenu}"

if command -v hyprpanel >/dev/null 2>&1; then
    exec hyprpanel t "$menu"
fi

# D-Bus fallback if the CLI is missing.
exec busctl --user call \
    com.github.Aylur.ags \
    /com/github/Aylur/ags \
    com.github.Aylur.ags ToggleWindow "s" "$menu"
