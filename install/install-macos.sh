#!/usr/bin/env bash

# macOS-specific installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/packages.sh"

DETECTED_OS="macos"

log_info "Starting macOS installation..."

# Install Homebrew if missing
install_homebrew_if_missing

# Ensure jq is available
ensure_jq

# Install packages from Homebrew
log_info "Installing packages via Homebrew..."
install_packages_homebrew "$JSON_FILE"

# Create config symlinks
create_config_symlinks "$JSON_FILE" "macos" "$REPO_DIR"

# Setup shell environment
setup_shell_env

# Run post-install commands
run_post_install "$JSON_FILE" "macos"

log_success "macOS installation complete!"
