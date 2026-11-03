#!/usr/bin/env bash
# Link the dotfiles into place and load the shell vars and GNOME settings.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"

# Helpers

# Anything already at the target is moved to a .backup file, never deleted.
link() {
    local source="$1"
    local target="$2"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        echo "ok      $target"
        return
    fi

    mkdir -p "$(dirname "$target")"

    if [ -e "$target" ] || [ -L "$target" ]; then
        local backup
        backup="$target.backup.$(date +%Y%m%d%H%M%S)"
        mv "$target" "$backup"
        echo "backup  $target -> $backup"
    fi

    ln -s "$source" "$target"
    echo "linked  $target"
}

add_source_line() {
    local rc="$1"
    local file="$2"
    local line="[ -f \"$file\" ] && . \"$file\""

    if [ -f "$rc" ] && grep -qF "$line" "$rc"; then
        echo "ok      $rc sources $(basename "$file")"
        return
    fi

    echo "$line" >> "$rc"
    echo "added   $(basename "$file") to $rc"
}

# Shell
# ~/.profile too, some login screens read only that one.
add_source_line "$HOME/.bashrc" "$DOTFILES/config/shell/env.sh"
add_source_line "$HOME/.profile" "$DOTFILES/config/shell/env.sh"
add_source_line "$HOME/.bashrc" "$DOTFILES/config/shell/interactive.sh"

# Configs
for name in alacritty git lazygit nvim tmux gtk-3.0/settings.ini; do
    link "$DOTFILES/config/$name" "$CONFIG_DIR/$name"
done

# Sway
if command -v sway >/dev/null; then
    for name in rofi sway swaylock swaync waybar xdg-desktop-portal; do
        link "$DOTFILES/config/$name" "$CONFIG_DIR/$name"
    done
fi

# GNOME
if command -v gnome-shell >/dev/null; then
    for dir in "$DOTFILES"/config/gnome-extensions/*/; do
        name="$(basename "$dir")"
        link "$DOTFILES/config/gnome-extensions/$name" "$DATA_DIR/gnome-shell/extensions/$name"
    done

    dconf load / < "$DOTFILES/config/gnome/dconf-settings.ini"
    echo "loaded  GNOME settings"
fi

echo
echo "Done."
