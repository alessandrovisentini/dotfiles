#!/usr/bin/env bash

# Generic Linux installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/packages.sh"

DETECTED_OS="linux"

# Parse which steps to run
parse_install_steps "$@"

log_info "Starting Linux installation..."

# Ensure jq is available
ensure_jq

# Install packages based on detected package manager
if should_run "packages"; then
    log_info "Installing packages..."
    install_linux_packages "$JSON_FILE"
fi

# Create config symlinks
if should_run "symlinks"; then
    create_config_symlinks "$JSON_FILE" "linux" "$REPO_DIR"
fi

# Setup shell environment
if should_run "shell"; then
    setup_shell_env
fi

# Run post-install commands
if should_run "post"; then
    run_post_install "$JSON_FILE" "linux"
fi

log_success "Linux installation complete!"
