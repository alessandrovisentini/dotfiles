#!/usr/bin/env bash

set -euo pipefail

# Packages
# lazygit is not in the Fedora repos
sudo dnf copr enable -y atim/lazygit
sudo dnf install -y git git-delta git-lfs neovim tmux fzf ripgrep fd-find alacritty \
    gcc make tree-sitter-cli nodejs npm unzip curl jq lazygit nethack whipper flac

# Font
mkdir -p ~/.local/share/fonts/DejaVuSansMono
curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/DejaVuSansMono.tar.xz \
    | tar -xJ -C ~/.local/share/fonts/DejaVuSansMono
fc-cache -f
