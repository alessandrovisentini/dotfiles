#!/usr/bin/env bash

SCRIPT="$REPOS_HOME/dotfiles/scripts/tmux_env.sh"

if [ -n "$TMUX" ]; then
    tmux display-popup -E "$SCRIPT"
elif tmux list-sessions 2>/dev/null; then
    tmux attach \; display-popup -E "$SCRIPT"
else
    tmux new-session -s _launcher \; display-popup -E "$SCRIPT" \; kill-session -t _launcher
fi
