#!/usr/bin/env bash

# Common functions shared across all installation scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step selection helpers
# Parse arguments into INSTALL_STEPS array. No arguments means "all".
# Also intercepts `--de=<value>` and stores it in DE_SELECTION.
parse_install_steps() {
    INSTALL_STEPS=()
    local rest=()
    for arg in "$@"; do
        case "$arg" in
            --de=*) DE_SELECTION="${arg#--de=}"; export DE_SELECTION ;;
            *) rest+=("$arg") ;;
        esac
    done
    if [[ ${#rest[@]} -eq 0 ]]; then
        INSTALL_STEPS=("all")
    else
        INSTALL_STEPS=("${rest[@]}")
    fi
    export INSTALL_STEPS
}

# Interactively choose the desktop environment(s) to install.
# Honors DE_SELECTION if already set (e.g. via --de=, env var).
# Falls back to "both" when stdin is non-interactive.
prompt_de_selection() {
    if [[ -n "${DE_SELECTION:-}" ]]; then
        case "$DE_SELECTION" in
            gnome|sway|both) ;;
            *)
                log_warning "Invalid DE_SELECTION='$DE_SELECTION'; defaulting to 'both'"
                DE_SELECTION="both"
                ;;
        esac
        export DE_SELECTION
        log_info "Desktop environment: $DE_SELECTION"
        return 0
    fi

    if [[ ! -t 0 || ! -t 1 ]]; then
        DE_SELECTION="both"
        export DE_SELECTION
        log_info "Non-interactive run; defaulting DE_SELECTION=both"
        return 0
    fi

    echo
    log_info "Which desktop environment(s) should be installed?"
    echo "  1) gnome  — GNOME only (skips Sway and its WM tools)"
    echo "  2) sway   — Sway only (skips GNOME shell/tweaks and dconf)"
    echo "  3) both   — install everything"
    local choice
    read -r -p "Select [1/2/3] (default: 3): " choice
    case "${choice:-3}" in
        1|gnome) DE_SELECTION="gnome" ;;
        2|sway)  DE_SELECTION="sway"  ;;
        3|both|"") DE_SELECTION="both" ;;
        *)
            log_warning "Invalid selection '$choice'; defaulting to 'both'"
            DE_SELECTION="both"
            ;;
    esac
    export DE_SELECTION
    log_info "Desktop environment: $DE_SELECTION"
}

# Whether a given DE group ("common", "gnome", "sway") should be installed
# given the current DE_SELECTION. "common" is always included.
de_group_active() {
    local group="$1"
    local de="${DE_SELECTION:-both}"
    case "$group" in
        common) return 0 ;;
        gnome)  [[ "$de" == "gnome" || "$de" == "both" ]] && return 0 || return 1 ;;
        sway)   [[ "$de" == "sway"  || "$de" == "both" ]] && return 0 || return 1 ;;
        *) return 1 ;;
    esac
}

# Check if a given step should run
should_run() {
    local step="$1"
    for s in "${INSTALL_STEPS[@]}"; do
        if [[ "$s" == "all" || "$s" == "$step" ]]; then
            return 0
        fi
    done
    return 1
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Expand variables like $HOME in strings
expand_vars() {
    local input="$1"
    eval echo "$input"
}

# Ensure jq is available, install if missing
ensure_jq() {
    if command -v jq &> /dev/null; then
        return 0
    fi

    log_info "jq not found. Installing jq..."

    case "$DETECTED_OS" in
        "nixos")
            log_info "Using nix-shell to provide jq..."
            # For NixOS, we'll use nix-shell inline
            return 0
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install jq || {
                    log_error "Failed to install jq with Homebrew"
                    return 1
                }
            else
                log_error "Homebrew not found. Please install jq manually."
                return 1
            fi
            ;;
        "fedora")
            sudo dnf install -y jq || {
                log_error "Failed to install jq with dnf"
                return 1
            }
            ;;
        *)
            log_error "Unknown OS. Please install jq manually."
            return 1
            ;;
    esac

    log_success "jq installed successfully"
}

# Run jq command, using nix-shell on NixOS if jq is not installed
run_jq() {
    if command -v jq &> /dev/null; then
        jq "$@"
    elif [[ "$DETECTED_OS" == "nixos" ]]; then
        local args
        args=$(printf '%q ' "$@")
        nix-shell -p jq --run "jq $args"
    else
        log_error "jq is not available"
        return 1
    fi
}

# Create symlink idempotently
# Arguments: source_path target_path [backup]
# If symlink exists and points to correct target, skip
# If file/symlink exists but is different, backup and replace
create_symlink() {
    local source_path="$1"
    local target_path="$2"
    local backup="${3:-true}"

    # Expand variables in paths
    source_path=$(expand_vars "$source_path")
    target_path=$(expand_vars "$target_path")

    # Check if source exists
    if [[ ! -e "$source_path" ]]; then
        log_error "Source does not exist: $source_path"
        return 1
    fi

    # Ensure parent directory exists
    local parent_dir
    parent_dir=$(dirname "$target_path")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir"
    fi

    # Check if target is already a correct symlink
    if [[ -L "$target_path" ]]; then
        local current_target
        current_target=$(readlink "$target_path")
        if [[ "$current_target" == "$source_path" ]]; then
            log_info "Symlink already exists: $target_path -> $source_path"
            return 0
        fi
    fi

    # If target exists (file, directory, or wrong symlink), backup and remove
    if [[ -e "$target_path" ]] || [[ -L "$target_path" ]]; then
        if [[ "$backup" == "true" ]]; then
            local backup_path="${target_path}.backup.$(date +%Y%m%d%H%M%S)"
            log_warning "Backing up existing: $target_path -> $backup_path"
            mv "$target_path" "$backup_path"
        else
            rm -rf "$target_path"
        fi
    fi

    # Create the symlink
    ln -s "$source_path" "$target_path"
    log_success "Created symlink: $target_path -> $source_path"
}

# Run post-install commands from JSON array
run_post_install() {
    local json_file="$1"
    local os="$2"
    local commands

    commands=$(run_jq -r ".os.$os.post_install[]" "$json_file" 2>/dev/null)

    if [[ -n "$commands" ]]; then
        log_info "Running post-install commands..."
        while IFS= read -r cmd; do
            if [[ -n "$cmd" ]]; then
                log_info "Executing: $cmd"
                eval "$cmd"
            fi
        done <<< "$commands"
    fi
}

# Get JSON value with jq
get_json_value() {
    local json_file="$1"
    local query="$2"
    run_jq -r "$query" "$json_file"
}

# Get JSON array as lines
get_json_array() {
    local json_file="$1"
    local query="$2"
    run_jq -r "$query | .[]" "$json_file" 2>/dev/null
}

# Check if JSON value exists and is not null
json_value_exists() {
    local json_file="$1"
    local query="$2"
    local value
    value=$(run_jq -r "$query // empty" "$json_file" 2>/dev/null)
    [[ -n "$value" ]]
}

# Create config symlinks from JSON.
# Supports two shapes:
#   - array form: .os.<os>.config_symlinks = [ "folder", ... ]
#   - object form: .os.<os>.config_symlinks = { common: [...], gnome: [...], sway: [...] }
# In object form, "common" is always installed; "gnome"/"sway" lists are filtered
# by DE_SELECTION.
create_config_symlinks() {
    local json_file="$1"
    local os="$2"
    local repo_dir="$3"
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

    mkdir -p "$config_dir"
    log_info "Creating config symlinks..."

    local sym_type
    sym_type=$(run_jq -r ".os.$os.config_symlinks | type" "$json_file" 2>/dev/null)

    local folders=()
    if [[ "$sym_type" == "object" ]]; then
        for group in common gnome sway; do
            if ! de_group_active "$group"; then
                continue
            fi
            while IFS= read -r f; do
                [[ -n "$f" ]] && folders+=("$f")
            done < <(get_json_array "$json_file" ".os.$os.config_symlinks.$group")
        done
    else
        while IFS= read -r f; do
            [[ -n "$f" ]] && folders+=("$f")
        done < <(get_json_array "$json_file" ".os.$os.config_symlinks")
    fi

    if [[ ${#folders[@]} -eq 0 ]]; then
        log_info "No config symlinks to create for this selection"
        return 0
    fi

    for folder in "${folders[@]}"; do
        local source_path="$repo_dir/config/$folder"
        local target_path="$config_dir/$folder"
        create_symlink "$source_path" "$target_path"
    done
}

# Detect whether GNOME is the active or installed desktop environment.
# Returns 0 if GNOME is detected, 1 otherwise.
gnome_detected() {
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
        return 0
    fi
    if [[ "${DESKTOP_SESSION:-}" == *gnome* ]]; then
        return 0
    fi
    if command -v gnome-shell &>/dev/null; then
        return 0
    fi
    return 1
}

# Apply GNOME dconf settings from a keyfile, when relevant.
# Reads .os.<os>.gnome_dconf from JSON: { enabled, source, path }
apply_gnome_dconf() {
    local json_file="$1"
    local os="$2"
    local repo_dir="$3"

    if ! json_value_exists "$json_file" ".os.$os.gnome_dconf"; then
        return 0
    fi

    local enabled
    enabled=$(get_json_value "$json_file" ".os.$os.gnome_dconf.enabled")
    if [[ "$enabled" != "true" ]]; then
        return 0
    fi

    if ! de_group_active gnome; then
        log_info "DE_SELECTION=${DE_SELECTION:-?} excludes GNOME; skipping dconf settings"
        return 0
    fi

    if ! gnome_detected; then
        log_info "GNOME not detected; skipping dconf settings"
        return 0
    fi

    if ! command -v dconf &>/dev/null; then
        log_warning "dconf not available; cannot apply GNOME settings"
        return 0
    fi

    local source dconf_path
    source=$(get_json_value "$json_file" ".os.$os.gnome_dconf.source")
    dconf_path=$(get_json_value "$json_file" ".os.$os.gnome_dconf.path")
    [[ -z "$dconf_path" || "$dconf_path" == "null" ]] && dconf_path="/"

    local source_path="$repo_dir/$source"
    if [[ ! -f "$source_path" ]]; then
        log_warning "GNOME dconf source not found: $source_path"
        return 0
    fi

    log_info "Applying GNOME dconf settings from $source_path (path: $dconf_path)..."
    if dconf load "$dconf_path" < "$source_path"; then
        log_success "GNOME dconf settings applied"
    else
        log_warning "dconf load reported an error"
    fi
}

# Setup shell environment sourcing
# Adds source line to .bashrc and/or .zshrc if not already present
setup_shell_env() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    local env_file="$config_dir/shell/env.sh"
    local source_line="# Dotfiles environment"
    local source_cmd="[ -f \"$env_file\" ] && source \"$env_file\""

    if [[ ! -f "$env_file" ]]; then
        log_warning "Shell env file not found: $env_file"
        return 0
    fi

    log_info "Setting up shell environment sourcing..."

    # Setup for bash
    local bashrc="$HOME/.bashrc"
    if [[ -f "$bashrc" ]]; then
        if ! grep -q "source.*shell/env.sh" "$bashrc" 2>/dev/null; then
            log_info "Adding source line to $bashrc"
            echo "" >> "$bashrc"
            echo "$source_line" >> "$bashrc"
            echo "$source_cmd" >> "$bashrc"
            log_success "Updated $bashrc"
        else
            log_info "Shell env already sourced in $bashrc"
        fi
    fi

    # Setup for zsh
    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        # Create .zshrc if it doesn't exist and user uses zsh
        if [[ ! -f "$zshrc" ]] && [[ "$SHELL" == *"zsh"* ]]; then
            touch "$zshrc"
        fi
        if [[ -f "$zshrc" ]]; then
            if ! grep -q "source.*shell/env.sh" "$zshrc" 2>/dev/null; then
                log_info "Adding source line to $zshrc"
                echo "" >> "$zshrc"
                echo "$source_line" >> "$zshrc"
                echo "$source_cmd" >> "$zshrc"
                log_success "Updated $zshrc"
            else
                log_info "Shell env already sourced in $zshrc"
            fi
        fi
    fi
}
