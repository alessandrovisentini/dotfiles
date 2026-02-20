#!/usr/bin/env bash

SCRIPT="$REPOS_HOME/dotfiles/scripts/tmux_env.sh"

if [ $# -gt 0 ]; then
    "$SCRIPT" "$@"
elif [ -n "$TMUX" ]; then
    tmux display-popup -E "$SCRIPT"
else
    tmux new-session -d -s _launcher 2>/dev/null
    tmux attach -t _launcher \; display-popup -E "$SCRIPT" \; kill-session -t _launcher
fi
