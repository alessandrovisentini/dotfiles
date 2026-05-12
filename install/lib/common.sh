#!/usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse positional args into INSTALL_STEPS; intercept --de=<value> into DE_SELECTION.
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

prompt_de_selection() {
    if [[ -n "${DE_SELECTION:-}" ]]; then
        case "$DE_SELECTION" in
            gnome|sway|both) ;;
            *) log_warning "Invalid DE_SELECTION='$DE_SELECTION'; defaulting to 'both'"
               DE_SELECTION="both" ;;
        esac
        export DE_SELECTION
        log_info "Desktop environment: $DE_SELECTION"
        return 0
    fi

    # Under `curl … | bash` stdin is the pipe; borrow /dev/tty so the prompt still works.
    local tty_dev=""
    if [[ -t 0 && -t 1 ]]; then
        :
    elif [[ -r /dev/tty && -w /dev/tty ]]; then
        tty_dev="/dev/tty"
    else
        DE_SELECTION="both"
        export DE_SELECTION
        log_info "Non-interactive run; defaulting DE_SELECTION=both"
        return 0
    fi

    {
        echo
        log_info "Which desktop environment(s) should be installed?"
        echo "  1) gnome  — GNOME only (skips Sway and its WM tools)"
        echo "  2) sway   — Sway only (skips GNOME shell/tweaks and dconf)"
        echo "  3) both   — install everything"
    } >"${tty_dev:-/dev/stdout}"

    local choice
    if [[ -n "$tty_dev" ]]; then
        read -r -p "Select [1/2/3] (default: 3): " choice <"$tty_dev" >"$tty_dev" 2>"$tty_dev"
    else
        read -r -p "Select [1/2/3] (default: 3): " choice
    fi

    case "${choice:-3}" in
        1|gnome)   DE_SELECTION="gnome" ;;
        2|sway)    DE_SELECTION="sway"  ;;
        3|both|"") DE_SELECTION="both"  ;;
        *) log_warning "Invalid selection '$choice'; defaulting to 'both'"
           DE_SELECTION="both" ;;
    esac
    export DE_SELECTION
    log_info "Desktop environment: $DE_SELECTION"
}

de_group_active() {
    local group="$1" de="${DE_SELECTION:-both}"
    case "$group" in
        common) return 0 ;;
        gnome)  [[ "$de" == "gnome" || "$de" == "both" ]] ;;
        sway)   [[ "$de" == "sway"  || "$de" == "both" ]] ;;
        *) return 1 ;;
    esac
}

should_run() {
    local step="$1"
    for s in "${INSTALL_STEPS[@]}"; do
        [[ "$s" == "all" || "$s" == "$step" ]] && return 0
    done
    return 1
}

expand_vars() { eval echo "$1"; }

ensure_jq() {
    command -v jq &>/dev/null && return 0
    log_info "jq not found. Installing jq..."
    case "$DETECTED_OS" in
        nixos)  return 0 ;;  # provided on-demand via nix-shell in run_jq
        macos)
            command -v brew &>/dev/null || { log_error "Homebrew not found. Install jq manually."; return 1; }
            brew install jq || { log_error "Failed to install jq with Homebrew"; return 1; }
            ;;
        fedora)
            sudo dnf install -y jq || { log_error "Failed to install jq with dnf"; return 1; }
            ;;
        *) log_error "Unknown OS. Install jq manually."; return 1 ;;
    esac
    log_success "jq installed successfully"
}

run_jq() {
    if command -v jq &>/dev/null; then
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

get_json_value() { run_jq -r "$2" "$1"; }
get_json_array() { run_jq -r "$2 | .[]" "$1" 2>/dev/null; }
json_value_exists() {
    local value
    value=$(run_jq -r "$2 // empty" "$1" 2>/dev/null)
    [[ -n "$value" ]]
}

# Idempotent: skips if target already points to source, otherwise backs up and replaces.
create_symlink() {
    local source_path target_path backup
    source_path=$(expand_vars "$1")
    target_path=$(expand_vars "$2")
    backup="${3:-true}"

    if [[ ! -e "$source_path" ]]; then
        log_error "Source does not exist: $source_path"
        return 1
    fi

    mkdir -p "$(dirname "$target_path")"

    if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
        log_info "Symlink already exists: $target_path -> $source_path"
        return 0
    fi

    if [[ -e "$target_path" || -L "$target_path" ]]; then
        if [[ "$backup" == "true" ]]; then
            local backup_path="${target_path}.backup.$(date +%Y%m%d%H%M%S)"
            log_warning "Backing up existing: $target_path -> $backup_path"
            mv "$target_path" "$backup_path"
        else
            rm -rf "$target_path"
        fi
    fi

    ln -s "$source_path" "$target_path"
    log_success "Created symlink: $target_path -> $source_path"
}

run_post_install() {
    local json_file="$1" os="$2" commands
    commands=$(run_jq -r ".os.$os.post_install[]" "$json_file" 2>/dev/null)
    [[ -z "$commands" ]] && return 0

    log_info "Running post-install commands..."
    while IFS= read -r cmd; do
        [[ -z "$cmd" ]] && continue
        log_info "Executing: $cmd"
        eval "$cmd"
    done <<< "$commands"
}

# Supports two shapes for config_symlinks:
#   array form:  [ "folder", ... ]
#   object form: { common: [...], gnome: [...], sway: [...] }
# Object form filters gnome/sway by DE_SELECTION; "common" is always included.
create_config_symlinks() {
    local json_file="$1" os="$2" repo_dir="$3"
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"

    mkdir -p "$config_dir"
    log_info "Creating config symlinks..."

    local sym_type
    sym_type=$(run_jq -r ".os.$os.config_symlinks | type" "$json_file" 2>/dev/null)

    local folders=()
    if [[ "$sym_type" == "object" ]]; then
        for group in common gnome sway; do
            de_group_active "$group" || continue
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
        create_symlink "$repo_dir/config/$folder" "$config_dir/$folder"
    done
}

gnome_detected() {
    [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
    [[ "${DESKTOP_SESSION:-}" == *gnome*   ]] && return 0
    command -v gnome-shell &>/dev/null
}

apply_gnome_dconf() {
    local json_file="$1" os="$2" repo_dir="$3"

    json_value_exists "$json_file" ".os.$os.gnome_dconf" || return 0
    [[ "$(get_json_value "$json_file" ".os.$os.gnome_dconf.enabled")" == "true" ]] || return 0

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

_ensure_rc_sources_env() {
    local rcfile="$1" env_file="$2"
    if grep -q "source.*shell/env.sh" "$rcfile" 2>/dev/null; then
        log_info "Shell env already sourced in $rcfile"
        return
    fi
    log_info "Adding source line to $rcfile"
    {
        printf '\n# Dotfiles environment\n'
        printf '[ -f "%s" ] && source "%s"\n' "$env_file" "$env_file"
    } >> "$rcfile"
    log_success "Updated $rcfile"
}

setup_shell_env() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    local env_file="$config_dir/shell/env.sh"

    if [[ ! -f "$env_file" ]]; then
        log_warning "Shell env file not found: $env_file"
        return 0
    fi

    log_info "Setting up shell environment sourcing..."

    local bashrc="$HOME/.bashrc"
    [[ -f "$bashrc" ]] && _ensure_rc_sources_env "$bashrc" "$env_file"

    local zshrc="$HOME/.zshrc"
    if [[ -f "$zshrc" || "$SHELL" == *"zsh"* ]]; then
        [[ ! -f "$zshrc" ]] && touch "$zshrc"
        _ensure_rc_sources_env "$zshrc" "$env_file"
    fi
}
