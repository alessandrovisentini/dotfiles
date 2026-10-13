#!/usr/bin/env bash

# Desktop notification that Claude wants attention, plus a tmux bell so the window gets flagged.

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
    # Keep the message inside the AppleScript string literal.
    ESCAPED=${MSG//\\/\\\\}
    ESCAPED=${ESCAPED//\"/\\\"}
    osascript -e "display notification \"$ESCAPED\" with title \"Claude Code\""
fi

# The bell on the pane tty makes tmux flag the window via monitor-bell.
if [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; then
    PANE_TTY=$(tmux display-message -p -t "$TMUX_PANE" '#{pane_tty}' 2>/dev/null)
    [ -n "$PANE_TTY" ] && printf '\a' > "$PANE_TTY"
    tmux display-message "$MSG" 2>/dev/null
fi

exit 0
