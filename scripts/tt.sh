#!/usr/bin/env bash
# TTRPG Notes Game Launcher

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

# Sync rules into game folder via hardlinks
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
            # -a: archive, -l: hardlink, -f: force overwrite
            cp -alf "$src_dir/." "$dest_dir/" 2>/dev/null || \
            cp -auf "$src_dir/." "$dest_dir/"  # fallback if cross-filesystem
        fi
    done

    # Create .ignore file to ensure Rules folder is indexed by obsidian.nvim
    # (overrides any gitignore that might exclude Rules/)
    echo '!Rules/' > "$game_path/.ignore"
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

# Expand $TTRPG_NOTES_HOME in path
FULL_PATH="${GAME_PATH//\$TTRPG_NOTES_HOME/$TTRPG_NOTES_HOME}"

# Sync rules into game folder
sync_rules "$FULL_PATH" "${GAME_RULES[@]}"

# Disable markdownlint for vault
cat > "$FULL_PATH/.markdownlint.jsonc" << 'EOF'
{
  "default": false
}
EOF

# Export for nvim to read
export TTRPG_GAME_NAME="$GAME"
export TTRPG_GAMES_CONFIG="$CONFIG_FILE"

cd "$FULL_PATH" && nvim .
