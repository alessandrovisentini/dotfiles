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

# Parse which steps to run
parse_install_steps "$@"

log_info "Starting macOS installation..."

# Install Homebrew if missing (needed for packages and jq)
if should_run "packages"; then
    install_homebrew_if_missing
fi

# Ensure jq is available
ensure_jq

# Install packages from Homebrew
if should_run "packages"; then
    log_info "Installing packages via Homebrew..."
    install_packages_homebrew "$JSON_FILE"
fi

# Create config symlinks
if should_run "symlinks"; then
    create_config_symlinks "$JSON_FILE" "macos" "$REPO_DIR"
fi

# Setup shell environment
if should_run "shell"; then
    setup_shell_env
fi

# Run post-install commands
if should_run "post"; then
    run_post_install "$JSON_FILE" "macos"
fi

log_success "macOS installation complete!"
