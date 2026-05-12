#!/usr/bin/env bash
#
# Dispatches to the per-OS installer. Supported: nixos, macos, fedora.
#
# Usage:
#   ./install.sh                  Run all steps (default)
#   ./install.sh <step> ...       Run only the specified steps
#   ./install.sh --de=<value>     Fedora: pick desktop env (gnome|sway|both)
#
# Steps: symlinks, packages, nixos, gnome, shell, post, all

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/common.sh"

detect_os() {
    [[ "$OSTYPE" == "darwin"* ]] && { echo macos; return; }
    if [[ -f /etc/nixos/configuration.nix ]] || command -v nixos-rebuild &>/dev/null; then
        echo nixos; return
    fi
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            nixos)  echo nixos ;;
            fedora) echo fedora ;;
            *)      echo unsupported ;;
        esac
        return
    fi
    echo unsupported
}

show_help() {
    cat <<EOF
Usage: $(basename "$0") [step ...] [--de=gnome|sway|both]

Run the dotfiles installer. With no arguments, runs all steps.

Steps:
  symlinks   Create config symlinks (~/.config/*)
  packages   Install software packages
  nixos      Setup NixOS system config symlinks (/etc/nixos)
  gnome      Apply GNOME dconf settings (non-NixOS, when GNOME is active)
  shell      Setup shell environment sourcing (.bashrc/.zshrc)
  post       Run post-install commands
  all        Run everything (default)

Fedora-only flag:
  --de=gnome|sway|both   Skip the desktop-environment prompt and filter packages/symlinks.

Examples:
  $(basename "$0")                       # everything (prompts for DE on Fedora)
  $(basename "$0") symlinks              # only recreate symlinks
  $(basename "$0") symlinks post         # symlinks + post-install
  $(basename "$0") --de=sway packages    # install only Sway-side packages
EOF
}

main() {
    case "${1:-}" in -h|--help) show_help; exit 0 ;; esac

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
