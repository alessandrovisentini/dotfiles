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

detect_os() {
    [[ "$OSTYPE" == "darwin"* ]] && { echo macos; return; }
    if [[ -f /etc/nixos/configuration.nix ]] || command -v nixos-rebuild &>/dev/null; then
        echo nixos; return
    fi
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            nixos)  echo nixos ;;
            fedora) echo fedora ;;
            *)      echo unsupported ;;
        esac
        return
    fi
    echo unsupported
}

# Every step any installer understands; an OS just no-ops steps it doesn't use.
VALID_STEPS="symlinks packages nixos rebuild gnome shell post all"

# Args → INSTALL_STEPS; intercept --de=<value> into DE_SELECTION.
# Unknown steps are fatal: a typo would otherwise skip every step and
# still print success.
parse_install_steps() {
    INSTALL_STEPS=()
    local rest=()
    for arg in "$@"; do
        case "$arg" in
            --de=*) DE_SELECTION="${arg#--de=}"; export DE_SELECTION ;;
            *)
                if [[ " $VALID_STEPS " != *" $arg "* ]]; then
                    log_error "Unknown step '$arg'. Valid steps: $VALID_STEPS"
                    exit 64
                fi
                rest+=("$arg")
                ;;
        esac
    done
    if [[ ${#rest[@]} -eq 0 ]]; then
        INSTALL_STEPS=("all")
    else
        INSTALL_STEPS=("${rest[@]}")
    fi
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

    # Borrow /dev/tty under `curl … | bash` so the prompt still works.
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
        nixos)  return 0 ;;  # on-demand via nix-shell
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

# Idempotent. Backs up an existing non-matching target before replacing.
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
            local backup_path
            backup_path="${target_path}.backup.$(date +%Y%m%d%H%M%S)"
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

# config_symlinks may be an array or a {common,gnome,sway} object filtered by DE_SELECTION.
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

# Claude Code reads ~/.claude regardless of OS, so the same files link in
# everywhere. Per-machine state (settings.local.json, .claude.json) stays put
# and is left untouched.
create_claude_symlinks() {
    local repo_dir="$1"
    local claude_dir="$HOME/.claude"

    log_info "Creating Claude config symlinks..."
    for file in settings.json CLAUDE.md; do
        create_symlink "$repo_dir/.claude/$file" "$claude_dir/$file"
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

# Symlinking (vs copy) means edits are live on next shell reload.
install_gnome_extension_local() {
    local uuid="$1" source_path="$2"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"

    if [[ ! -d "$source_path" ]]; then
        log_warning "Local extension source missing: $source_path"
        return 1
    fi

    if [[ -L "$ext_dir" && "$(readlink "$ext_dir")" == "$source_path" ]]; then
        log_info "Local extension already linked: $uuid"
        return 0
    fi

    mkdir -p "$(dirname "$ext_dir")"
    [[ -e "$ext_dir" || -L "$ext_dir" ]] && rm -rf "$ext_dir"
    ln -s "$source_path" "$ext_dir"
    log_success "Linked local extension: $uuid -> $source_path"
}

install_gnome_extension_ego() {
    local uuid="$1" ext_id="$2"
    local ext_dir="$HOME/.local/share/gnome-shell/extensions/$uuid"

    if [[ -d "$ext_dir" ]]; then
        log_info "EGO extension already installed: $uuid"
        return 0
    fi

    local shell_version
    shell_version=$(gnome-shell --version 2>/dev/null | awk '{print $3}' | cut -d. -f1)
    if [[ -z "$shell_version" ]]; then
        log_warning "Could not detect gnome-shell version; skipping $uuid"
        return 1
    fi

    local info_url="https://extensions.gnome.org/extension-info/?pk=${ext_id}&shell_version=${shell_version}"
    local info download_path
    info=$(curl -fsSL "$info_url") || {
        log_warning "Failed to fetch e.g.o info for $uuid (id=$ext_id)"
        return 1
    }
    download_path=$(echo "$info" | run_jq -r '.download_url // empty')
    if [[ -z "$download_path" ]]; then
        log_warning "No download for $uuid on shell $shell_version"
        return 1
    fi

    local tmp_zip
    tmp_zip=$(mktemp --suffix=.zip)
    if ! curl -fsSL "https://extensions.gnome.org${download_path}" -o "$tmp_zip"; then
        rm -f "$tmp_zip"
        log_warning "Failed to download $uuid"
        return 1
    fi

    if gnome-extensions install --force "$tmp_zip" 2>/dev/null; then
        log_success "Installed e.g.o extension: $uuid"
    else
        log_warning "gnome-extensions install failed for $uuid"
        rm -f "$tmp_zip"
        return 1
    fi
    rm -f "$tmp_zip"
}

enable_gnome_extension() {
    local uuid="$1"
    if gnome-extensions list --enabled 2>/dev/null | grep -qx "$uuid"; then
        log_info "Extension already enabled: $uuid"
        return 0
    fi
    if gnome-extensions enable "$uuid" 2>/dev/null; then
        log_success "Enabled extension: $uuid"
    else
        # Some newly-installed extensions need a shell reload first.
        log_warning "Could not enable $uuid yet (may need shell reload)"
    fi
}

install_gnome_extensions() {
    local json_file="$1" os="$2" repo_dir="$3"

    json_value_exists "$json_file" ".os.$os.gnome_extensions" || return 0
    [[ "$(get_json_value "$json_file" ".os.$os.gnome_extensions.enabled")" == "true" ]] || return 0

    if ! de_group_active gnome; then
        log_info "DE_SELECTION=${DE_SELECTION:-?} excludes GNOME; skipping extensions"
        return 0
    fi

    if ! command -v gnome-extensions &>/dev/null; then
        log_warning "gnome-extensions CLI not available; skipping extensions"
        return 0
    fi

    local ego_count loc_count i uuid ext_id src
    ego_count=$(run_jq -r ".os.$os.gnome_extensions.ego | length // 0" "$json_file" 2>/dev/null)
    [[ -z "$ego_count" || "$ego_count" == "null" ]] && ego_count=0
    for ((i = 0; i < ego_count; i++)); do
        uuid=$(get_json_value  "$json_file" ".os.$os.gnome_extensions.ego[$i].uuid")
        ext_id=$(get_json_value "$json_file" ".os.$os.gnome_extensions.ego[$i].ext_id")
        [[ -z "$uuid" || -z "$ext_id" ]] && continue
        install_gnome_extension_ego "$uuid" "$ext_id" || true
    done

    loc_count=$(run_jq -r ".os.$os.gnome_extensions.local | length // 0" "$json_file" 2>/dev/null)
    [[ -z "$loc_count" || "$loc_count" == "null" ]] && loc_count=0
    for ((i = 0; i < loc_count; i++)); do
        uuid=$(get_json_value "$json_file" ".os.$os.gnome_extensions.local[$i].uuid")
        src=$(get_json_value  "$json_file" ".os.$os.gnome_extensions.local[$i].source")
        [[ -z "$uuid" || -z "$src" ]] && continue
        install_gnome_extension_local "$uuid" "$repo_dir/$src" || true
    done

    while IFS= read -r uuid; do
        [[ -z "$uuid" ]] && continue
        enable_gnome_extension "$uuid"
    done <<< "$(get_json_array "$json_file" ".os.$os.gnome_extensions.enable")"
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
