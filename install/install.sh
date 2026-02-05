#!/usr/bin/env bash

# Main installation entry point
# Detects OS and dispatches to the appropriate OS-specific installer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [ -f /etc/nixos/configuration.nix ] || command -v nixos-rebuild &> /dev/null; then
        echo "nixos"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "nixos" ]]; then
            echo "nixos"
        else
            echo "linux"
        fi
    else
        echo "linux"
    fi
}

# Install git if not available
install_git() {
    local os="$1"

    log_info "Git not found. Installing git..."

    case "$os" in
        "nixos")
            log_info "Using nix-shell to provide git temporarily..."
            return 0
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
        *)
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm git
            else
                log_error "No supported package manager found. Please install git manually."
                exit 1
            fi
            ;;
    esac

    log_success "Git installed successfully"
}

# Main execution
main() {
    DETECTED_OS=$(detect_os)
    export DETECTED_OS

    log_info "Detected operating system: $DETECTED_OS"

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
    exec "$installer"
}

main "$@"
