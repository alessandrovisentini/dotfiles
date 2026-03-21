#!/usr/bin/env bash

BASE_PATH="$REPOS_HOME"

# Returns active session names only (excludes dead/exited sessions and error messages)
_zellij_sessions() {
    zellij list-sessions 2>/dev/null \
        | perl -pe 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
        | grep -iv "exited\|no active" \
        | awk 'NF {print $1}'
}

# Returns all session names including dead ones (excludes only error messages)
_zellij_all_sessions() {
    zellij list-sessions 2>/dev/null \
        | perl -pe 's/\x1b\[[0-9;?]*[A-Za-z]//g' \
        | grep -iv "no active" \
        | awk 'NF {print $1}'
}

if [ $# -eq 0 ]; then
    if [ -z "$BASE_PATH" ]; then
        echo "Error: REPOS_HOME is not set."
        exit 1
    fi

    ACTIVE_SESSIONS=$(_zellij_sessions)
    REPOS=$(ls "$BASE_PATH")

    # Active sessions last so they appear at the bottom near the prompt
    INACTIVE=$(echo "$REPOS" | while read -r repo; do
        if ! echo "$ACTIVE_SESSIONS" | grep -qxF "$repo"; then
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

# If session is active, attach to it
if _zellij_sessions | grep -qxF "$SESSION_NAME"; then
    env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
        zellij attach "$SESSION_NAME"
    printf '\033[1A\033[2K\r'
    exit 0
fi

# If session is dead, delete it so we can recreate with fresh layout
if _zellij_all_sessions | grep -qxF "$SESSION_NAME"; then
    zellij delete-session "$SESSION_NAME" 2>/dev/null || true
fi

# Detect project features
HAS_FLAKE=false
[ -f "$REPO_PATH/flake.nix" ] && HAS_FLAKE=true

HAS_GIT=false
[ -d "$REPO_PATH/.git" ] && HAS_GIT=true

# Build commands based on flake detection
if $HAS_FLAKE; then
    EDITOR_CMD="nix develop --command nvim ."
    SHELL_CMD="nix develop --command bash"
    LAZYGIT_CMD="nix develop --command lazygit"
else
    EDITOR_CMD="nvim ."
    SHELL_CMD="bash"
    LAZYGIT_CMD="lazygit"
fi

# Generate KDL layout for the new session
LAYOUT_FILE="/tmp/zellij-layout-${SESSION_NAME}.kdl"

generate_layout() {
    cat > "$LAYOUT_FILE" << EOF
layout {
    default_tab_template {
        pane size=1 borderless=true {
            plugin location="tab-bar"
        }
        children
    }
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
        pane cwd="$REPO_PATH" command="bash" {
            args "-c" "$LAZYGIT_CMD"
        }
    }
EOF
    fi

    echo "}" >> "$LAYOUT_FILE"
}

generate_layout

# Create and launch the new session.
# Use -n/--new-session-with-layout which always creates a new session.
# (-l/--layout combined with -s would instead add tabs to an existing session.)
# Unset ZELLIJ env vars so zellij renders its full UI (tab bar etc.) even
# when called from inside an existing session.
env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID \
    zellij -s "$SESSION_NAME" -n "$LAYOUT_FILE"
printf '\033[1A\033[2K\r'
