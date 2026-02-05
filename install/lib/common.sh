#!/usr/bin/env bash

# Common functions shared across all installation scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        "linux")
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y jq
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm jq
            else
                log_error "No supported package manager found. Please install jq manually."
                return 1
            fi
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
        nix-shell -p jq --run "jq $*"
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

# Create config symlinks from JSON
create_config_symlinks() {
    local json_file="$1"
    local os="$2"
    local repo_dir="$3"
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

    # Ensure config directory exists
    mkdir -p "$config_dir"

    log_info "Creating config symlinks..."

    local symlinks
    symlinks=$(get_json_array "$json_file" ".os.$os.config_symlinks")

    while IFS= read -r folder; do
        if [[ -n "$folder" ]]; then
            local source_path="$repo_dir/config/$folder"
            local target_path="$config_dir/$folder"
            create_symlink "$source_path" "$target_path"
        fi
    done <<< "$symlinks"
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
