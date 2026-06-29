#!/usr/bin/env bash

# Notifies you that Claude wants attention. Sends a desktop notification using
# whatever the host provides (notify-send on Linux, osascript on macOS, same
# path as the rest of the dotfiles' notifications) and, when running inside
# tmux, also rings the bell on Claude's pane so the window gets flagged in the
# status bar. Both signals are best-effort and skipped when unavailable, so
# this stays safe on any machine.

# Headless/one-shot Claude runs (e.g. the code companion) export this so their
# own Stop/Notification hooks don't pop a desktop notification on every call.
[ -n "$CLAUDE_NO_NOTIFY" ] && exit 0

MSG="${1:-Claude needs you}"

if command -v notify-send >/dev/null; then
    notify-send \
        --app-name "Claude Code" \
        --expire-time 5000 \
        --icon dialog-information \
        --hint string:x-canonical-private-synchronous:claude-code \
        "Claude Code" \
        "$MSG"
elif command -v osascript >/dev/null; then
    # Escape backslashes and double quotes so the message can't break out of
    # the AppleScript string literal.
    ESCAPED=${MSG//\\/\\\\}
    ESCAPED=${ESCAPED//\"/\\\"}
    osascript -e "display notification \"$ESCAPED\" with title \"Claude Code\""
fi

# Inside tmux, a bell character on the pane tty makes tmux flag the window via
# monitor-bell, so you notice it from another window/pane too.
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
    PANE_TTY=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
    [ -n "$PANE_TTY" ] && printf '\a' > "$PANE_TTY"
    tmux display-message "$MSG" 2>/dev/null
fi

exit 0
