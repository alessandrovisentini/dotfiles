#!/usr/bin/env bash
# Per-OS installer dispatcher. Supported: nixos, macos, fedora.
# Steps: symlinks, packages, nixos, rebuild, shell, post, all

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/lib/common.sh"

show_help() {
    cat <<EOF
Usage: $(basename "$0") [step ...]

Run the dotfiles installer. With no arguments, runs all steps.

Steps:
  symlinks   Create config symlinks (~/.config/*)
  packages   Install software packages
  nixos      Setup NixOS system config symlinks (/etc/nixos)
  rebuild    Run \`sudo nixos-rebuild switch\` (NixOS)
  shell      Setup shell environment sourcing (.bashrc/.zshrc)
  post       Run post-install commands
  all        Run everything (default)

Examples:
  $(basename "$0")                       # everything
  $(basename "$0") symlinks              # only recreate symlinks
  $(basename "$0") symlinks post         # symlinks + post-install
  $(basename "$0") packages              # install packages only
EOF
}

main() {
    local a
    for a in "$@"; do
        case "$a" in -h|--help) show_help; exit 0 ;; esac
    done

    DETECTED_OS=$(detect_os)
    export DETECTED_OS
    log_info "Detected operating system: $DETECTED_OS"

    if [[ "$DETECTED_OS" == "unsupported" ]]; then
        log_error "Unsupported OS. This installer supports NixOS, macOS, and Fedora."
        exit 1
    fi

    local installer="$SCRIPT_DIR/install-$DETECTED_OS.sh"
    if [[ ! -f "$installer" ]]; then
        log_error "No installer found for OS: $DETECTED_OS"
        exit 1
    fi

    log_info "Running $DETECTED_OS installer..."
    exec "$installer" "$@"
}

main "$@"
