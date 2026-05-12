#!/usr/bin/env bash
#
# Bootstrap entry point — meant to be invoked via `curl … | bash`. It detects the OS,
# installs git if needed, clones the dotfiles repo, then hands off to install/install.sh.
# Local invocations skip the clone (or pull if the repo is already present).

set -e

REPO_URL="https://github.com/alessandrovisentini/dotfiles.git"
TARGET_DIR="$HOME/Development/repos/dotfiles"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

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

run_git() {
    if command -v git &>/dev/null; then
        git "$@"
    elif [[ "$DETECTED_OS" == "nixos" ]]; then
        local args
        args=$(printf '%q ' "$@")
        nix-shell -p git --run "git $args"
    else
        log_error "git is not available"
        return 1
    fi
}

install_git() {
    log_info "Git not found. Installing git..."
    case "$DETECTED_OS" in
        nixos)
            # Provided on-demand via nix-shell in run_git.
            return 0
            ;;
        macos)
            if command -v brew &>/dev/null; then
                brew install git || { log_error "Failed to install git with brew"; exit 1; }
            elif command -v xcode-select &>/dev/null; then
                log_info "Triggering Xcode Command Line Tools install (provides git)..."
                # xcode-select --install can exit non-zero even when the GUI launches; don't trip `set -e`.
                xcode-select --install 2>/dev/null || true
                cat <<EOF

============================================================
The Command Line Tools GUI installer has been triggered.
Wait for it to finish (it can take several minutes), then
re-run this script:
  curl -fsSL https://raw.githubusercontent.com/alessandrovisentini/dotfiles/main/install.sh | bash
============================================================
EOF
                exit 0
            else
                log_error "Neither Homebrew nor Xcode Command Line Tools available. Install git manually."
                exit 1
            fi
            ;;
        fedora)
            sudo dnf install -y git || { log_error "Failed to install git with dnf"; exit 1; }
            ;;
        *)
            log_error "Unsupported OS. This installer supports NixOS, macOS, and Fedora."
            exit 1
            ;;
    esac
    log_success "Git installed successfully"
}

DETECTED_OS=$(detect_os)
if [[ "$DETECTED_OS" == "unsupported" ]]; then
    log_error "Unsupported OS. This installer supports NixOS, macOS, and Fedora."
    exit 1
fi

if ! command -v git &>/dev/null && [[ "$DETECTED_OS" != "nixos" ]]; then
    install_git
fi

log_info "Creating directory structure..."
mkdir -p "$HOME/Development/repos"

if [[ -d "$TARGET_DIR" ]]; then
    log_info "Repository exists at $TARGET_DIR. Updating..."
    cd "$TARGET_DIR"
    run_git pull origin main || log_warning "Failed to update repository. Continuing with existing files."
else
    log_info "Cloning dotfiles repository..."
    run_git clone "$REPO_URL" "$TARGET_DIR" || {
        log_error "Failed to clone repository. Check your internet connection."
        exit 1
    }
fi

cd "$TARGET_DIR"
chmod +x ./install/install.sh
exec ./install/install.sh "$@"
