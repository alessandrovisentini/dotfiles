#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

source "$SCRIPT_DIR/lib/common.sh"

# Read by the helpers sourced from lib/common.sh (run_jq, ensure_jq).
export DETECTED_OS="nixos"

parse_install_steps "$@"

log_info "Starting NixOS installation..."

ensure_jq

if [[ $EUID -eq 0 ]]; then
    log_error "Do not run this script as root. The script handles privilege escalation itself."
    exit 1
fi

if should_run nixos || should_run rebuild; then
    log_info "Sudo is required for NixOS configuration setup. Please authenticate:"
    sudo -v || { log_error "sudo authentication failed"; exit 1; }
fi

is_excluded() {
    local filename="$1"
    for excluded in "${EXCLUDE_FILES[@]}"; do
        [[ "$filename" == "$excluded" ]] && return 0
    done
    return 1
}

# Reverse-symlink hardware-configuration.nix so editing the repo edits the real file.
setup_hw_config_reverse_link() {
    local target_dir="$1" source_dir="$2"
    local hw_config="$target_dir/hardware-configuration.nix"
    local hw_config_link="$source_dir/hardware-configuration.nix"

    if [[ ! -e "$hw_config" ]]; then
        log_warning "hardware-configuration.nix not found in $target_dir"
        log_warning "You may need to run 'nixos-generate-config' first"
        return
    fi

    if [[ -L "$hw_config_link" ]]; then
        if [[ "$(readlink "$hw_config_link")" == "$hw_config" ]]; then
            log_info "Reverse symlink already correct: $hw_config_link -> $hw_config"
            return
        fi
        log_warning "Updating reverse symlink for hardware-configuration.nix..."
        rm "$hw_config_link"
    elif [[ -e "$hw_config_link" ]]; then
        log_warning "Backing up existing hardware-configuration.nix in repo..."
        mv "$hw_config_link" "${hw_config_link}.backup.$(date +%Y%m%d%H%M%S)"
    else
        log_info "Creating reverse symlink for hardware-configuration.nix..."
    fi

    ln -s "$hw_config" "$hw_config_link"
    log_success "Linked: $hw_config_link -> $hw_config"
}

clear_target_nix_files() {
    local target_dir="$1"
    log_info "Removing existing .nix files in $target_dir (requires sudo)..."
    for nix_file in "$target_dir"/*.nix; do
        [[ -e "$nix_file" ]] || continue
        local filename
        filename=$(basename "$nix_file")
        # Never delete hardware-configuration.nix.
        if [[ "$filename" == "hardware-configuration.nix" ]]; then
            log_info "Preserving: $nix_file (machine-specific)"
            continue
        fi
        if is_excluded "$filename"; then
            log_info "Preserving (excluded): $nix_file"
        else
            sudo rm -f "$nix_file"
            log_info "Removed: $nix_file"
        fi
    done
}

link_source_nix_files() {
    local source_dir="$1" target_dir="$2"
    log_info "Creating NixOS symlinks (requires sudo)..."
    for nix_file in "$source_dir"/*.nix; do
        [[ -f "$nix_file" ]] || continue
        local filename
        filename=$(basename "$nix_file")
        is_excluded "$filename" && continue

        local target_path="$target_dir/$filename"
        if [[ -L "$target_path" && "$(readlink "$target_path")" == "$nix_file" ]]; then
            log_info "Symlink already exists: $target_path -> $nix_file"
            continue
        fi
        sudo ln -sf "$nix_file" "$target_path"
        log_success "Created symlink: $target_path -> $nix_file"
    done
}

setup_nixos_system_symlinks() {
    [[ "$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.enabled")" == "true" ]] || return 0
    log_info "Setting up NixOS configuration symlinks..."

    local source_dir target_dir
    source_dir="$REPO_DIR/$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.source_dir")"
    target_dir=$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.target_dir")

    EXCLUDE_FILES=()
    readarray -t EXCLUDE_FILES < <(get_json_array "$JSON_FILE" ".os.nixos.nixos_symlinks.exclude")

    setup_hw_config_reverse_link "$target_dir" "$source_dir"
    clear_target_nix_files       "$target_dir"
    link_source_nix_files        "$source_dir" "$target_dir"
}

autodetect_device() {
    local script="$REPO_DIR/scripts/setup-device.sh"
    [[ -x "$script" ]] || return 0
    log_info "Autodetecting per-device config selectors..."
    if ! "$script"; then
        log_warning "Device autodetection failed — link nixos/device.nix, config/sway/device.conf, and config/astal-bar/src/device.ts manually before nixos-rebuild."
    fi
}

# Activate the linked configuration. `set -e` aborts the script if the
# rebuild fails (stop on errors, no manual step when there are none).
run_nixos_rebuild() {
    log_info "Running nixos-rebuild switch (this can take a while)..."
    # Refresh the sudo timestamp: the symlink steps are quick, but on a
    # slow first run the earlier authentication may have expired.
    sudo -v
    sudo nixos-rebuild switch
    log_success "nixos-rebuild switch completed"
}

should_run symlinks && create_config_symlinks "$JSON_FILE" nixos "$REPO_DIR"
should_run symlinks && create_claude_symlinks "$REPO_DIR"
should_run nixos    && setup_nixos_system_symlinks
should_run nixos    && autodetect_device
should_run rebuild  && run_nixos_rebuild
should_run post     && run_post_install       "$JSON_FILE" nixos

log_success "NixOS installation complete!"
