#!/usr/bin/env bash

# Main installation entry point
# Detects OS and dispatches to the appropriate OS-specific installer
#
# Usage:
#   ./install.sh              Run all install steps
#   ./install.sh <step> ...   Run only the specified steps
#
# Available steps:
#   symlinks   Create config symlinks (~/.config/*)
#   packages   Install software packages
#   nixos      Setup NixOS system config symlinks (/etc/nixos)
#   gnome      Apply GNOME dconf settings (non-NixOS, when GNOME is active)
#   shell      Setup shell environment sourcing (.bashrc/.zshrc)
#   post       Run post-install commands
#   all        Run everything (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

# Detect operating system. Supported: nixos, macos, fedora.
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
        return
    fi
    if [ -f /etc/nixos/configuration.nix ] || command -v nixos-rebuild &> /dev/null; then
        echo "nixos"
        return
    fi
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            nixos)  echo "nixos" ;;
            fedora) echo "fedora" ;;
            *)      echo "unsupported" ;;
        esac
        return
    fi
    echo "unsupported"
}

# Install git if not available
install_git() {
    local os="$1"

    log_info "Git not found. Installing git..."

    case "$os" in
        "nixos")
            log_info "Installing git via nix-env..."
            nix-env -iA nixpkgs.git || {
                log_error "Failed to install git. Try running: nix-env -iA nixpkgs.git"
                exit 1
            }
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install git || {
                    log_error "Failed to install git with brew"
                    exit 1
                }
            elif command -v xcode-select &> /dev/null; then
                log_info "Installing Xcode Command Line Tools (includes git)..."
                xcode-select --install
                log_info "Please complete the Xcode Command Line Tools installation and run this script again."
                exit 0
            else
                log_error "Neither Homebrew nor Xcode Command Line Tools available. Please install git manually."
                exit 1
            fi
            ;;
        "fedora")
            sudo dnf install -y git || {
                log_error "Failed to install git with dnf"
                exit 1
            }
            ;;
        *)
            log_error "Unsupported OS. Please install git manually."
            exit 1
            ;;
    esac

    log_success "Git installed successfully"
}

# Show usage help
show_help() {
    echo "Usage: $(basename "$0") [step ...]"
    echo ""
    echo "Run the dotfiles installer. With no arguments, runs all steps."
    echo "Specify one or more steps to run only those."
    echo ""
    echo "Steps:"
    echo "  symlinks   Create config symlinks (~/.config/*)"
    echo "  packages   Install software packages"
    echo "  nixos      Setup NixOS system config symlinks (/etc/nixos)"
    echo "  gnome      Apply GNOME dconf settings (non-NixOS, when GNOME is active)"
    echo "  shell      Setup shell environment sourcing (.bashrc/.zshrc)"
    echo "  post       Run post-install commands"
    echo "  all        Run everything (default)"
    echo ""
    echo "Fedora-only flags:"
    echo "  --de=gnome|sway|both   Which desktop environment(s) to install."
    echo "                         Skips prompt. Filters packages and config symlinks."
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                       # run everything (prompts for DE on Fedora)"
    echo "  $(basename "$0") symlinks              # only recreate symlinks"
    echo "  $(basename "$0") symlinks post         # symlinks + post-install"
    echo "  $(basename "$0") packages              # only install missing software"
    echo "  $(basename "$0") --de=gnome            # install everything, GNOME only"
    echo "  $(basename "$0") packages --de=sway    # install only Sway-side packages"
}

# Main execution
main() {
    # Handle help flag
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi

    DETECTED_OS=$(detect_os)
    export DETECTED_OS

    log_info "Detected operating system: $DETECTED_OS"

    if [[ "$DETECTED_OS" == "unsupported" ]]; then
        log_error "Unsupported OS. This installer supports NixOS, macOS, and Fedora."
        exit 1
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        install_git "$DETECTED_OS"
    fi

    # Dispatch to OS-specific installer
    local installer="$SCRIPT_DIR/install-$DETECTED_OS.sh"

    if [[ ! -f "$installer" ]]; then
        log_error "No installer found for OS: $DETECTED_OS"
        log_info "Available installers:"
        ls -1 "$SCRIPT_DIR"/install-*.sh 2>/dev/null || echo "  None found"
        exit 1
    fi

    log_info "Running $DETECTED_OS installer..."
    exec "$installer" "$@"
}

main "$@"
