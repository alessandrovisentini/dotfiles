#!/usr/bin/env bash
# apply-mode <laptop|tablet|external>
# Idempotent. Called on each confirmed mode transition. external (external
# keyboard) behaves like laptop; only its notification differs.

set -u

mode="${1:-laptop}"
case "$mode" in
    laptop|tablet|external) ;;
    *) echo "usage: $0 <laptop|tablet|external>" >&2; exit 64 ;;
esac

# Sway input identifier for the detachable keyboard's touchpad. Empty
# disables the toggle.
SWAY_TP="${DETACHABLE_TOUCHPAD_SWAY_ID:-}"

# Auto-rotation: tablet only.
if command -v systemctl >/dev/null 2>&1; then
    rotsvc=""
    [[ -n "${SWAYSOCK:-}" ]] && rotsvc="sway-rotate.service"

    if [[ "$mode" == "tablet" ]]; then
        [[ -n "$rotsvc" ]] && systemctl --user start "$rotsvc" 2>/dev/null || true
    else
        [[ -n "$rotsvc" ]] && systemctl --user stop "$rotsvc" 2>/dev/null || true
        if [[ -n "${SWAYSOCK:-}" ]]; then
            swaymsg output eDP-1 transform 0 >/dev/null 2>&1 || true
        fi
    fi
fi

# Detachable touchpad: disabled while detached.
if [[ -n "$SWAY_TP" && -n "${SWAYSOCK:-}" ]]; then
    if [[ "$mode" == "tablet" ]]; then
        swaymsg input "$SWAY_TP" events disabled >/dev/null 2>&1 || true
    else
        swaymsg input "$SWAY_TP" events enabled  >/dev/null 2>&1 || true
    fi
fi

# OSK auto-popup gsetting; force-hide on laptop in case a field is focused.
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

# "manual" means a user override holds the mode and hardware changes are ignored.
src=$(cat "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mode-source" 2>/dev/null || echo "auto")
suffix=""
[[ "$src" == "manual" ]] && suffix=" (manual)"

if [[ "${MODE_QUIET:-0}" != "1" ]] && command -v notify-send >/dev/null 2>&1; then
    case "$mode" in
        tablet)
            if [[ "$src" == "manual" ]]; then desc="Tablet mode held manually"
            else                              desc="Keyboard detached — touch UI active"; fi
            notify-send -t 1500 -i input-tablet \
                -a "mode-state" "Tablet mode${suffix}" "$desc" ;;
        external)
            if [[ "$src" == "manual" ]]; then desc="External-keyboard mode held manually"
            else                              desc="External keyboard connected"; fi
            notify-send -t 1500 -i input-keyboard \
                -a "mode-state" "External keyboard mode${suffix}" "$desc" ;;
        *)
            if [[ "$src" == "manual" ]]; then desc="Laptop mode held manually"
            else                              desc="Keyboard attached"; fi
            notify-send -t 1500 -i input-keyboard \
                -a "mode-state" "Laptop mode${suffix}" "$desc" ;;
    esac
fi
