#!/usr/bin/env bash
# TTRPG Notes Game Launcher

TTRPG_ROOT="$REPOS_HOME/ttrpg-notes"
CONFIG_FILE="$TTRPG_ROOT/.config/games.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

# Sync rules into game folder via hardlinks
sync_rules() {
    local game_path="$1"
    shift
    local rules=("$@")

    [ ${#rules[@]} -eq 0 ] && return 0

    for rule in "${rules[@]}"; do
        local src_dir="$TTRPG_ROOT/Rules/$rule"
        local dest_dir="$game_path/Rules/$rule"

        if [ -d "$src_dir" ]; then
            mkdir -p "$dest_dir"
            # -a: archive, -l: hardlink, -f: force overwrite
            cp -alf "$src_dir/." "$dest_dir/" 2>/dev/null || \
            cp -auf "$src_dir/." "$dest_dir/"  # fallback if cross-filesystem
        fi
    done
}

# Read game names from JSON and select with fzf
GAME=$(jq -r '.games[].name' "$CONFIG_FILE" | fzf --prompt="Select Game: ")

if [ -z "$GAME" ]; then
    echo "No game selected."
    exit 1
fi

# Get path and rules for selected game
GAME_PATH=$(jq -r --arg name "$GAME" '.games[] | select(.name == $name) | .path' "$CONFIG_FILE")
readarray -t GAME_RULES < <(jq -r --arg name "$GAME" '.games[] | select(.name == $name) | .rules[]' "$CONFIG_FILE")

FULL_PATH="$TTRPG_ROOT/$GAME_PATH"

# Sync rules into game folder
sync_rules "$FULL_PATH" "${GAME_RULES[@]}"

# Export for nvim to read (kept for potential status line use)
export TTRPG_GAME_NAME="$GAME"

cd "$FULL_PATH" && nvim .
