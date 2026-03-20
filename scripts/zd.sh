#!/usr/bin/env bash

SCRIPT="$REPOS_HOME/dotfiles/scripts/zellij_env.sh"

if [ $# -gt 0 ]; then
    "$SCRIPT" "$@"
elif [ -n "$ZELLIJ" ]; then
    # Inside zellij: open floating pane with session picker
    zellij action new-pane --floating --name "session-picker" -- bash -c "exec $SCRIPT"
else
    "$SCRIPT"
fi
