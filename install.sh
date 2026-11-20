#!/usr/bin/env bash
# Links the dotfiles. On NixOS, also links the system config and rebuild.

set -euo pipefail

REPO_URL="https://github.com/alessandrovisentini/dotfiles.git"
# config/shell/env.sh expects the repo here
REPO_DIR="$HOME/Development/repos/dotfiles"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

run_git() {
    # Fresh NixOS has no git from the start
    if ! command -v git >/dev/null && command -v nix-shell >/dev/null; then
        nix-shell -p git --run "git $(printf '%q ' "$@")"
    else
        git "$@"
    fi
}

link() {
    local source="$1" target="$2" sudo="${3:-}"

    if [ "$(readlink "$target")" = "$source" ]; then
        echo "ok      $target"
        return
    fi

    $sudo mkdir -p "$(dirname "$target")"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup
        backup="$target.backup.$(date +%Y%m%d%H%M%S)"
        $sudo mv "$target" "$backup"
        echo "backup  $target -> $backup"
    fi

    $sudo ln -sfn "$source" "$target"
    echo "linked  $target"
}

add_source_line() {
    local rc="$1" file="$2"
    local line="[ -f \"$file\" ] && . \"$file\""

    if [ -f "$rc" ] && grep -qF "$line" "$rc"; then
        echo "ok      $rc sources $(basename "$file")"
        return
    fi

    echo "$line" >> "$rc"
    echo "added   $(basename "$file") to $rc"
}

main() {
    if [ "$EUID" -eq 0 ]; then
        echo "Do not run as root, sudo is used only where needed." >&2
        exit 1
    fi

    local self="${BASH_SOURCE[0]:-}"
    if [ -f "$self" ] && [ -f "$(dirname "$self")/config/shell/env.sh" ]; then
        DOTFILES="$(cd "$(dirname "$self")" && pwd)"
    else
        DOTFILES="$REPO_DIR"
        if [ ! -e "$DOTFILES/.git" ]; then
            run_git clone "$REPO_URL" "$DOTFILES"
        fi
    fi

    add_source_line "$HOME/.bashrc" "$DOTFILES/config/shell/env.sh"
    add_source_line "$HOME/.profile" "$DOTFILES/config/shell/env.sh"
    add_source_line "$HOME/.bashrc" "$DOTFILES/config/shell/interactive.sh"

    for name in alacritty git lazygit nvim tmux gtk-3.0/settings.ini; do
        link "$DOTFILES/config/$name" "$CONFIG_DIR/$name"
    done

    if command -v sway >/dev/null; then
        for name in rofi sway swaylock swaync waybar xdg-desktop-portal; do
            link "$DOTFILES/config/$name" "$CONFIG_DIR/$name"
        done
    fi

    if [ -e /etc/NIXOS ]; then
        link "$DOTFILES/nixos/configuration.nix" /etc/nixos/configuration.nix sudo
        sudo nixos-rebuild switch
    fi

    echo
    echo "Done."
}

main
