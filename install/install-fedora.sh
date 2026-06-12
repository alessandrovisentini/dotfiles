#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/packages.sh"

# Read by the helpers sourced from lib/common.sh (run_jq, ensure_jq).
export DETECTED_OS="fedora"

parse_install_steps "$@"

log_info "Starting Fedora installation..."

ensure_jq
prompt_de_selection

if should_run packages; then
    log_info "Installing packages (DE=$DE_SELECTION)..."
    install_fedora_packages "$JSON_FILE"
fi

should_run symlinks && create_config_symlinks "$JSON_FILE" fedora "$REPO_DIR"
should_run symlinks && create_claude_symlinks "$REPO_DIR"
should_run gnome    && install_gnome_extensions "$JSON_FILE" fedora "$REPO_DIR"
should_run gnome    && apply_gnome_dconf      "$JSON_FILE" fedora "$REPO_DIR"
should_run shell    && setup_shell_env
should_run post     && run_post_install       "$JSON_FILE" fedora

log_success "Fedora installation complete!"
