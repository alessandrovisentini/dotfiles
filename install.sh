#!/usr/bin/env bash

# Root install.sh - Redirects to install/install.sh
# This file maintains backward compatibility for existing documentation

set -e

REPO_URL="https://github.com/alessandrovisentini/dotfiles.git"
TARGET_DIR="$HOME/Development/repos/dotfiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Detect OS for git installation
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

# Run git command, using nix-shell on NixOS if git is not installed
run_git() {
    if command -v git &> /dev/null; then
        git "$@"
    elif [[ "$DETECTED_OS" == "nixos" ]]; then
        nix-shell -p git --run "git $*"
    else
        log_error "git is not available"
        return 1
    fi
}

# Install git if not available
install_git() {
    log_info "Git not found. Installing git..."

    case "$DETECTED_OS" in
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
DETECTED_OS=$(detect_os)

# Check if git is available
if ! command -v git &> /dev/null && [[ "$DETECTED_OS" != "nixos" ]]; then
    install_git
fi

# Create Development directory structure
log_info "Creating directory structure..."
mkdir -p "$HOME/Development/repos"

# Clone or update repository
if [ -d "$TARGET_DIR" ]; then
    log_info "Repository exists at $TARGET_DIR. Updating..."
    cd "$TARGET_DIR"
    run_git pull origin main || {
        log_warning "Failed to update repository. Continuing with existing files."
    }
else
    log_info "Cloning dotfiles repository..."
    run_git clone "$REPO_URL" "$TARGET_DIR" || {
        log_error "Failed to clone repository. Please check your internet connection."
        exit 1
    }
fi

# Dispatch to main installer
cd "$TARGET_DIR"

if [[ -x "./install/install.sh" ]]; then
    exec ./install/install.sh "$@"
else
    chmod +x ./install/install.sh
    exec ./install/install.sh "$@"
fi
