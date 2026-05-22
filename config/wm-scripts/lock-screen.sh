#!/usr/bin/env bash
# Lock with hyprlock; in tablet mode raise wvkbd over the lock so the
# password is typable on the touchscreen.
#
# wvkbd, not squeekboard: squeekboard's surface is tied to the
# input-method protocol and is torn down when the session locks, so it
# never appears over the lock. wvkbd maps a plain layer-shell surface
# that abovelock (window-rules.conf) can lift. It must be mapped before
# locking — ext-session-lock suppresses surfaces mapped during a lock.
# See https://github.com/hyprwm/Hyprland/issues/6195.
#
# LOCK_FORCE_OSK=1 forces the OSK path with the folio attached (testing).

set -u

# Don't stack a second locker.
if pidof hyprlock >/dev/null 2>&1; then
    exit 0
fi

RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
mode=$(cat "$RUNTIME/mode-state" 2>/dev/null || echo laptop)
[[ "${LOCK_FORCE_OSK:-0}" == "1" ]] && mode=tablet

wvkbd_pid=""
if [[ "$mode" == "tablet" ]]; then
    # Map wvkbd before the lock so abovelock can keep it on top.
    # Modifier keys (--fg-sp) are lighter than letters; shorter
    # landscape height (-L) keeps it from dominating the screen.
    wvkbd-mobintl -H 340 -L 220 -R 12 --fn "JetBrains Mono 18" \
        --bg 242424ff --fg 464448ff --fg-sp 605e65ff \
        --press 747077ff --press-sp 8a8891ff \
        --text dedddaff --text-sp dedddaff >/dev/null 2>&1 &
    wvkbd_pid=$!
    sleep 0.4
fi

# Block until unlocked.
hyprlock

# Tear down the OSK after unlock.
if [[ -n "$wvkbd_pid" ]]; then
    kill "$wvkbd_pid" 2>/dev/null || true
fi

# Restart hyprpanel after unlock. Under fractional scaling its bar comes
# back blurry (a stale scale-1 layer buffer gets upscaled), and its
# workspace widget loses sync with Hyprland's IPC across the lock. A
# clean restart fixes both, and unlike `hyprctl reload` it doesn't reset
# runtime monitor/rule state. Small settle delay so the lock has fully
# torn down before the new bar maps.
sleep 0.3
hyprpanel restart >/dev/null 2>&1 || true
