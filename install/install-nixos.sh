#!/usr/bin/env bash

# NixOS-specific installation script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

# Source common functions
source "$SCRIPT_DIR/lib/common.sh"

DETECTED_OS="nixos"

log_info "Starting NixOS installation..."

# Ensure jq is available
ensure_jq

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "Do not run this script as root. The script will handle privilege escalation."
    exit 1
fi

# Create config symlinks
create_config_symlinks "$JSON_FILE" "nixos" "$REPO_DIR"

# Handle NixOS configuration symlinks
nixos_symlinks_enabled=$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.enabled")

if [[ "$nixos_symlinks_enabled" == "true" ]]; then
    log_info "Setting up NixOS configuration symlinks..."

    nixos_source_dir="$REPO_DIR/$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.source_dir")"
    nixos_target_dir=$(get_json_value "$JSON_FILE" ".os.nixos.nixos_symlinks.target_dir")

    # Get excluded files as an array
    readarray -t exclude_files < <(get_json_array "$JSON_FILE" ".os.nixos.nixos_symlinks.exclude")

    # Handle hardware-configuration.nix specially:
    # - The actual file must stay in /etc/nixos (it's machine-specific)
    # - We create a reverse symlink in the repo pointing TO /etc/nixos/hardware-configuration.nix
    hw_config="$nixos_target_dir/hardware-configuration.nix"
    hw_config_link="$nixos_source_dir/hardware-configuration.nix"

    # Ensure hardware-configuration.nix exists in /etc/nixos
    if [[ ! -e "$hw_config" ]]; then
        log_warning "hardware-configuration.nix not found in $nixos_target_dir"
        log_warning "You may need to run 'nixos-generate-config' first"
    else
        # Create or verify reverse symlink in repo
        if [[ -L "$hw_config_link" ]]; then
            current_target=$(readlink "$hw_config_link")
            if [[ "$current_target" == "$hw_config" ]]; then
                log_info "Reverse symlink already correct: $hw_config_link -> $hw_config"
            else
                log_warning "Updating reverse symlink for hardware-configuration.nix..."
                rm "$hw_config_link"
                ln -s "$hw_config" "$hw_config_link"
                log_success "Updated: $hw_config_link -> $hw_config"
            fi
        elif [[ -e "$hw_config_link" ]]; then
            # It's a regular file, back it up and create symlink
            log_warning "Backing up existing hardware-configuration.nix in repo..."
            mv "$hw_config_link" "${hw_config_link}.backup.$(date +%Y%m%d%H%M%S)"
            ln -s "$hw_config" "$hw_config_link"
            log_success "Created: $hw_config_link -> $hw_config"
        else
            log_info "Creating reverse symlink for hardware-configuration.nix..."
            ln -s "$hw_config" "$hw_config_link"
            log_success "Created: $hw_config_link -> $hw_config"
        fi
    fi

    # Function to check if file is excluded
    is_excluded() {
        local filename="$1"
        for excluded in "${exclude_files[@]}"; do
            if [[ "$filename" == "$excluded" ]]; then
                return 0
            fi
        done
        return 1
    }

    # Remove existing .nix files in /etc/nixos (except excluded ones like hardware-configuration.nix)
    log_info "Removing existing .nix files in $nixos_target_dir (requires sudo)..."
    for nix_file in "$nixos_target_dir"/*.nix; do
        if [[ -e "$nix_file" ]]; then
            filename=$(basename "$nix_file")
            # Double-check: NEVER remove hardware-configuration.nix
            if [[ "$filename" == "hardware-configuration.nix" ]]; then
                log_info "Preserving: $nix_file (machine-specific)"
                continue
            fi
            if ! is_excluded "$filename"; then
                sudo rm -f "$nix_file"
                log_info "Removed: $nix_file"
            else
                log_info "Preserving (excluded): $nix_file"
            fi
        fi
    done

    # Create symlinks for all .nix files from repo to /etc/nixos
    log_info "Creating NixOS symlinks (requires sudo)..."
    for nix_file in "$nixos_source_dir"/*.nix; do
        if [[ -f "$nix_file" ]]; then
            filename=$(basename "$nix_file")
            if ! is_excluded "$filename"; then
                target_path="$nixos_target_dir/$filename"

                # Check if symlink already exists and points to correct target
                if [[ -L "$target_path" ]]; then
                    current_target=$(readlink "$target_path")
                    if [[ "$current_target" == "$nix_file" ]]; then
                        log_info "Symlink already exists: $target_path -> $nix_file"
                        continue
                    fi
                fi

                sudo ln -sf "$nix_file" "$target_path"
                log_success "Created symlink: $target_path -> $nix_file"
            fi
        fi
    done
fi

# Run post-install commands
run_post_install "$JSON_FILE" "nixos"

log_success "NixOS installation complete!"
