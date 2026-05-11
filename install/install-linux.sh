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

# Parse step args + --de=<value>
parse_install_steps "$@"

log_info "Starting Linux installation..."

# Ensure jq is available before we read DE-related JSON
ensure_jq

# Determine which DE(s) to install
prompt_de_selection

# Install packages based on detected package manager
if should_run "packages"; then
    log_info "Installing packages (DE=$DE_SELECTION)..."
    install_linux_packages "$JSON_FILE"
fi

# Create config symlinks
if should_run "symlinks"; then
    create_config_symlinks "$JSON_FILE" "linux" "$REPO_DIR"
fi

# Apply GNOME dconf settings when GNOME is active and selected
if should_run "gnome"; then
    apply_gnome_dconf "$JSON_FILE" "linux" "$REPO_DIR"
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
