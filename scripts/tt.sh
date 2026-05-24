#!/usr/bin/env bash

if [ -z "$TTRPG_NOTES_HOME" ]; then
    echo "Error: TTRPG_NOTES_HOME environment variable not set"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/games.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found at $CONFIG_FILE"
    exit 1
fi

sync_rules() {
    local game_path="$1"
    shift
    local rules=("$@")

    [ ${#rules[@]} -eq 0 ] && return 0

    for rule in "${rules[@]}"; do
        local src_dir="$TTRPG_NOTES_HOME/Rules/$rule"
        local dest_dir="$game_path/Rules/$rule"

        if [ -d "$src_dir" ]; then
            mkdir -p "$dest_dir"
            cp -alf "$src_dir/." "$dest_dir/" 2>/dev/null || \
            cp -auf "$src_dir/." "$dest_dir/"  # cross-filesystem fallback
        fi
    done

    # Force-index Rules/ in obsidian.nvim even if .gitignore excludes it.
    echo '!Rules/' > "$game_path/.ignore"
}

GAME=$(jq -r '.games[].name' "$CONFIG_FILE" | fzf --prompt="Select Game: ")

if [ -z "$GAME" ]; then
    echo "No game selected."
    exit 1
fi

GAME_PATH=$(jq -r --arg name "$GAME" '.games[] | select(.name == $name) | .path' "$CONFIG_FILE")
readarray -t GAME_RULES < <(jq -r --arg name "$GAME" '.games[] | select(.name == $name) | .rules[]' "$CONFIG_FILE")

FULL_PATH="${GAME_PATH//\$TTRPG_NOTES_HOME/$TTRPG_NOTES_HOME}"

sync_rules "$FULL_PATH" "${GAME_RULES[@]}"

cat > "$FULL_PATH/.markdownlint.jsonc" << 'EOF'
{
  "default": false
}
EOF

export TTRPG_GAME_NAME="$GAME"
export TTRPG_GAMES_CONFIG="$CONFIG_FILE"

cd "$FULL_PATH" && nvim .
