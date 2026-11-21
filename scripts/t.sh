#!/usr/bin/env bash

# tmux session per repo

run_session() {
    local BASE_PATH="$REPOS_HOME"

    local REPO_PATH REPO_NAME
    if [ $# -eq 0 ]; then
        if [ -z "$BASE_PATH" ]; then
            echo "Error: REPOS_HOME is not set."
            exit 1
        fi

        local ACTIVE_SESSIONS REPOS INACTIVE ACTIVE LIST SELECTION
        ACTIVE_SESSIONS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
        REPOS=$(ls "$BASE_PATH")

        INACTIVE=$(echo "$REPOS" | while read -r repo; do
            if ! echo "$ACTIVE_SESSIONS" | grep -qx "$repo"; then
                echo "$repo"
            fi
        done)
        ACTIVE=$(echo "$ACTIVE_SESSIONS" | while read -r session; do
            if [ -n "$session" ]; then
                printf '\033[32m%s (active)\033[0m\n' "$session"
            fi
        done)

        LIST=$(printf '%s\n%s' "$ACTIVE" "$INACTIVE" | sed '/^$/d')

        SELECTION=$(echo "$LIST" | fzf --ansi)

        if [ -z "$SELECTION" ]; then
            echo "No repository selected."
            exit 1
        fi

        REPO_NAME="${SELECTION% (active)}"
        REPO_PATH="$BASE_PATH/$REPO_NAME"
    else
        REPO_PATH="$(realpath "$1")"
        REPO_NAME="$(basename "$REPO_PATH")"
    fi

    local SESSION_NAME="$REPO_NAME"
    # Exact match. The trailing ":" stops a "." in the name being read as window.pane
    local TARGET="=$SESSION_NAME:"

    if tmux has-session -t "$TARGET" 2>/dev/null; then
        if [ -n "$TMUX" ]; then
            tmux switch-client -t "$TARGET"
        else
            tmux attach -t "$TARGET"
        fi
        exit 0
    fi

    tmux new-session -d -s "$SESSION_NAME" -c "$REPO_PATH" -n "editor"
    tmux send-keys -t "${TARGET}1" "nvim ." C-m

    tmux new-window -t "$TARGET" -c "$REPO_PATH" -n "terminal"
    tmux split-window -h -c "$REPO_PATH" -t "${TARGET}2"

    tmux select-window -t "${TARGET}1"
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$TARGET"
    else
        tmux attach -t "$TARGET"
    fi
}

run_session "$@"
