#!/usr/bin/env bash

BASE_PATH="$REPOS_HOME"

if [ $# -eq 0 ]; then
    if [ -z "$BASE_PATH" ]; then
        echo "Error: REPOS_HOME is not set."
        exit 1
    fi

    ACTIVE_SESSIONS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    REPOS=$(ls "$BASE_PATH")

    # Active sessions last so they appear at the bottom near the prompt
    INACTIVE=$(echo "$REPOS" | while read -r repo; do
        if ! echo "$ACTIVE_SESSIONS" | grep -qx "$repo"; then
            echo "$repo"
        fi
    done)
    ACTIVE=$(echo "$ACTIVE_SESSIONS" | while read -r session; do
        if [ -n "$session" ] && [ "$session" != "_launcher" ]; then
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

SESSION_NAME="$REPO_NAME"

setup_window() {
    local SESSION="$1"
    local WINDOW_INDEX="$2"
    local REPO_PATH="$3"
    local CMD="$4"

    if [ -f "$REPO_PATH/flake.nix" ]; then
        if [ "$CMD" = "bash" ]; then
            tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "nix develop" C-m
            tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "clear && sleep 2" C-m
            tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "clear" C-m
        else
            tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "nix develop --command $CMD" C-m
        fi
    else
        if [ "$CMD" != "bash" ]; then
            tmux send-keys -t "$SESSION":"$WINDOW_INDEX" "$CMD" C-m
        fi
    fi
}

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    if [ -n "$TMUX" ]; then
        tmux switch-client -t "$SESSION_NAME"
    else
        tmux attach -t "$SESSION_NAME"
    fi
    exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -c "$REPO_PATH" -n "editor"
setup_window "$SESSION_NAME" "1" "$REPO_PATH" "nvim ."

tmux new-window -t "$SESSION_NAME" -c "$REPO_PATH" -n "terminal"
setup_window "$SESSION_NAME" "2" "$REPO_PATH" "bash"
tmux split-window -h -c "$REPO_PATH" -t "$SESSION_NAME:2"
setup_window "$SESSION_NAME" "2" "$REPO_PATH" "bash"

if [ -d "$REPO_PATH/.git" ]; then
    tmux new-window -t "$SESSION_NAME" -c "$REPO_PATH" -n "git"
    setup_window "$SESSION_NAME" "3" "$REPO_PATH" "lazygit"
fi

tmux select-window -t "$SESSION_NAME:1"
if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SESSION_NAME"
else
    tmux attach -t "$SESSION_NAME"
fi
