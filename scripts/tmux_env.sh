#!/usr/bin/env bash

BASE_PATH="$REPOS_HOME"

if [ $# -eq 0 ]; then
    if [ -z "$BASE_PATH" ]; then
        echo "Error: REPOS_HOME is not set."
        exit 1
    fi

    REPO_NAME=$(ls "$BASE_PATH" | fzf)

    if [ -z "$REPO_NAME" ]; then
        echo "No repository selected."
        exit 1
    fi

    REPO_PATH="$BASE_PATH/$REPO_NAME"
else
    REPO_PATH="$(realpath "$1")"
    REPO_NAME="$(basename "$REPO_PATH")"
fi

SESSION_NAME="$REPO_NAME"

setup_window() {
    local SESSION="$1"
    local WINDOW_INDEX="$2"
    local REPO_PATH="$3"
    local CMD="$4"

    if [ -f "$REPO_PATH/flake.nix" ]; then
        tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "nix develop --command $CMD" C-m
    else
        tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "$CMD" C-m
    fi
}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux attach -t "$SESSION_NAME"
    exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -c "$REPO_PATH" -n "terminal"
tmux split-window -v -c "$REPO_PATH" -t "$SESSION_NAME:1"
tmux resize-pane -t "$SESSION_NAME:1.1" -D 15
setup_window "$SESSION_NAME" "1.1" "$REPO_PATH" "lazygit"

tmux new-window -t "$SESSION_NAME" -c "$REPO_PATH" -n "editor"
setup_window "$SESSION_NAME" "2" "$REPO_PATH" "nvim ."

tmux attach -t "$SESSION_NAME"
