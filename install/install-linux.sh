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

log_info "Starting Linux installation..."

# Ensure jq is available
ensure_jq

# Install packages based on detected package manager
log_info "Installing packages..."
install_linux_packages "$JSON_FILE"

# Create config symlinks
create_config_symlinks "$JSON_FILE" "linux" "$REPO_DIR"

# Setup shell environment
setup_shell_env

# Run post-install commands
run_post_install "$JSON_FILE" "linux"

log_success "Linux installation complete!"
