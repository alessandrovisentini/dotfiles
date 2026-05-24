#!/usr/bin/env bash
# Lock with gtklock. In tablet mode load gtklock-virtkb-module so the
# keyboard is drawn inside the lock window (a GTK widget, not a
# layer-shell surface) — sway places ext-session-lock above all
# layer-shell clients with no override, so OSK-over-lock requires the
# locker itself to embed the keyboard.
#
# The virtkb module unconditionally reveals the keyboard, so it's only
# loaded in tablet mode; laptop mode gets a plain gtklock.
#
# LOCK_FORCE_OSK=1 forces the OSK path with the folio attached (testing).

set -u

if pidof gtklock >/dev/null 2>&1; then
    exit 0
fi

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mode=$(cat "$RUNTIME/mode-state" 2>/dev/null || echo laptop)
[[ "${LOCK_FORCE_OSK:-0}" == "1" ]] && mode=tablet

if [[ "$mode" == "tablet" ]]; then
    exec gtklock -m @VIRTKB@
else
    exec gtklock
fi
