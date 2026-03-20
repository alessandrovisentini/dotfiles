#!/usr/bin/env bash

BASE_PATH="$REPOS_HOME"

if [ $# -eq 0 ]; then
    if [ -z "$BASE_PATH" ]; then
        echo "Error: REPOS_HOME is not set."
        exit 1
    fi

    ACTIVE_SESSIONS=$(zellij list-sessions 2>/dev/null | perl -pe 's/\x1b\[[0-9;]*m//g' | awk '{print $1}')
    REPOS=$(ls "$BASE_PATH")

    # Active sessions last so they appear at the bottom near the prompt
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

SESSION_NAME="$REPO_NAME"

# If session already exists, switch/attach to it
if zellij list-sessions 2>/dev/null | perl -pe 's/\x1b\[[0-9;]*m//g' | awk '{print $1}' | grep -qx "$SESSION_NAME"; then
    if [ -n "$ZELLIJ" ]; then
        zellij action switch-session --name "$SESSION_NAME"
    else
        zellij attach "$SESSION_NAME"
    fi
    exit 0
fi

# Detect project features
HAS_FLAKE=false
[ -f "$REPO_PATH/flake.nix" ] && HAS_FLAKE=true

HAS_GIT=false
[ -d "$REPO_PATH/.git" ] && HAS_GIT=true

# Build commands based on flake detection
if $HAS_FLAKE; then
    EDITOR_CMD="nix develop --command nvim --listen /tmp/nvim-${SESSION_NAME}.sock ."
    SHELL_CMD="nix develop --command bash"
else
    EDITOR_CMD="nvim --listen /tmp/nvim-${SESSION_NAME}.sock ."
    SHELL_CMD="bash"
fi

# Generate KDL layout for the new session
LAYOUT_FILE="/tmp/zellij-layout-${SESSION_NAME}.kdl"

generate_layout() {
    cat > "$LAYOUT_FILE" << EOF
layout {
    tab name="editor" focus=true {
        pane cwd="$REPO_PATH" command="bash" {
            args "-c" "$EDITOR_CMD"
        }
    }
    tab name="terminal" {
        pane split_direction="vertical" {
            pane cwd="$REPO_PATH" command="bash" {
                args "-c" "$SHELL_CMD"
            }
            pane cwd="$REPO_PATH" command="bash" {
                args "-c" "$SHELL_CMD"
            }
        }
    }
EOF

    if $HAS_GIT; then
        cat >> "$LAYOUT_FILE" << EOF
    tab name="git" {
        pane cwd="$REPO_PATH" command="lazygit" {}
    }
EOF
    fi

    echo "}" >> "$LAYOUT_FILE"
}

generate_layout

# Launch or switch to the new session
if [ -n "$ZELLIJ" ]; then
    zellij action new-session --name "$SESSION_NAME" --layout "$LAYOUT_FILE"
else
    zellij --session "$SESSION_NAME" --layout "$LAYOUT_FILE"
fi
