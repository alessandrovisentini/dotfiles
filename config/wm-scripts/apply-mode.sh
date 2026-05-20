#!/usr/bin/env bash
# apply-mode <laptop|tablet>
# Idempotent. Called by the mode-daemon on each confirmed transition.

set -u

mode="${1:-laptop}"
case "$mode" in
    laptop|tablet) ;;
    *) echo "usage: $0 <laptop|tablet>" >&2; exit 64 ;;
esac

# iio-hyprland runs in tablet mode only. The laptop-mode reload also
# wipes runtime hyprgrass binds, so re-source them.
if command -v systemctl >/dev/null 2>&1; then
    if [[ "$mode" == "tablet" ]]; then
        systemctl --user start iio-hyprland.service 2>/dev/null || true
    else
        systemctl --user stop iio-hyprland.service 2>/dev/null || true
        if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
            hyprctl reload >/dev/null 2>&1 || true
            hyprctl keyword source /etc/hypr/gestures-binds.conf >/dev/null 2>&1 || true
        fi
    fi
fi

# Disable the folio's touchpad while detached.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    TP="device:darfon-thinkpad-x12-detachable-gen-1-folio-case-1-touchpad:enabled"
    if [[ "$mode" == "tablet" ]]; then
        hyprctl keyword "$TP" false >/dev/null 2>&1 || true
    else
        hyprctl keyword "$TP" true  >/dev/null 2>&1 || true
    fi
fi

# OSK auto-popup, tablet only (live gsetting toggle). In laptop mode
# also force-hide via D-Bus in case a field is focused.
if command -v gsettings >/dev/null 2>&1; then
    KEY="org.gnome.desktop.a11y.applications screen-keyboard-enabled"
    if [[ "$mode" == "tablet" ]]; then
        gsettings set $KEY true  >/dev/null 2>&1 || true
    else
        gsettings set $KEY false >/dev/null 2>&1 || true
        busctl --user call sm.puri.OSK0 /sm/puri/OSK0 \
            sm.puri.OSK0 SetVisible b false >/dev/null 2>&1 || true
    fi
fi

# Notification. "manual" means a bar/keybind override holds the mode
# and hardware changes are ignored.
src=$(cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mode-source" 2>/dev/null || echo "auto")
suffix=""
[[ "$src" == "manual" ]] && suffix=" (manual)"

if command -v notify-send >/dev/null 2>&1; then
    if [[ "$mode" == "tablet" ]]; then
        if [[ "$src" == "manual" ]]; then desc="Tablet mode held manually"
        else                              desc="Folio detached — touch UI active"; fi
        notify-send -t 1500 -i input-tablet \
            -a "mode-state" "Tablet mode${suffix}" "$desc"
    else
        if [[ "$src" == "manual" ]]; then desc="Laptop mode held manually"
        else                              desc="Folio attached"; fi
        notify-send -t 1500 -i input-keyboard \
            -a "mode-state" "Laptop mode${suffix}" "$desc"
    fi
fi
