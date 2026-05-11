#!/usr/bin/env bash

# macOS-specific installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

# When run via `curl | bash`, stdin is the curl pipe — any brew (or sudo) prompt
# during install reads EOF and aborts that one step, which is how we silently
# lost sketchybar/fzf/amethyst before. Reattach stdin to the controlling TTY.
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# Stop brew from running `brew update` before every install (slow + noisy +
# can introduce extra prompts) and from printing setup hints we don't need.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

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

echo ""
log_info "============================================================"
log_info "Manual step: create your Mission Control desktops"
log_info "============================================================"
log_info "macOS does not expose a reliable way to script the number of"
log_info "Spaces. To add more desktops:"
log_info "  1. Press F3 (or swipe up with 3 fingers) to open Mission Control"
log_info "  2. Hover the top edge and click '+' once per extra desktop"
log_info "  3. Option+<n> will then switch between them"
log_info "============================================================"

echo ""
log_info "============================================================"
log_info "Manual step: have Amethyst start at login"
log_info "============================================================"
log_info "  System Settings > General > Login Items & Extensions"
log_info "  Under 'Open at Login', click '+' and add Amethyst.app"
log_info "============================================================"

echo ""
log_info "============================================================"
log_info "Manual step: remap Caps Lock to Escape"
log_info "============================================================"
log_info "  System Settings > Keyboard > Keyboard Shortcuts..."
log_info "  > Modifier Keys (bottom of left sidebar)"
log_info "  Set 'Caps Lock Key' to 'Escape'"
log_info "============================================================"
