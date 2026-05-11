#!/usr/bin/env bash

# Package installation helpers

# Install Homebrew if not present (macOS)
install_homebrew_if_missing() {
    if command -v brew &> /dev/null; then
        log_info "Homebrew is already installed"
        return 0
    fi

    log_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        log_error "Failed to install Homebrew"
        return 1
    }

    # Add Homebrew to PATH for this session
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_success "Homebrew installed successfully"
}

# Install packages via Homebrew (macOS)
install_packages_homebrew() {
    local json_file="$1"

    # Install taps
    local taps
    taps=$(get_json_array "$json_file" ".os.macos.packages.homebrew.taps")
    while IFS= read -r tap; do
        if [[ -n "$tap" ]]; then
            log_info "Adding Homebrew tap: $tap"
            brew tap "$tap" 2>/dev/null || true
        fi
    done <<< "$taps"

    # Install formulae
    local formulae
    formulae=$(get_json_array "$json_file" ".os.macos.packages.homebrew.formulae")
    while IFS= read -r formula; do
        if [[ -n "$formula" ]]; then
            if brew list "$formula" &>/dev/null; then
                log_info "Formula already installed: $formula"
            else
                log_info "Installing formula: $formula"
                brew install "$formula" || log_warning "Failed to install: $formula"
            fi
        fi
    done <<< "$formulae"

    # Install casks
    local casks
    casks=$(get_json_array "$json_file" ".os.macos.packages.homebrew.casks")
    while IFS= read -r cask; do
        if [[ -n "$cask" ]]; then
            if brew list --cask "$cask" &>/dev/null; then
                log_info "Cask already installed: $cask"
            else
                log_info "Installing cask: $cask"
                brew install --cask "$cask" || log_warning "Failed to install cask: $cask"
            fi
        fi
    done <<< "$casks"
}

# Detect Linux package manager
detect_linux_package_manager() {
    if command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Collect packages for a given manager + DE-selected groups.
# Echoes one package per line. Supports both flat array and {common,gnome,sway} object.
collect_de_packages() {
    local json_file="$1"
    local mgr="$2"   # dnf|apt|pacman
    local sub_key="$3"  # "" for top-level array form, or sub-key like "packages" for dnf legacy

    local base=".os.linux.packages.$mgr"
    local node_type
    node_type=$(run_jq -r "$base | type" "$json_file" 2>/dev/null)

    # Legacy: dnf had {rpm_repos, copr, packages: [...]} flat array
    if [[ "$node_type" == "object" ]]; then
        # Object form — could be {common,gnome,sway} or legacy with "packages" key
        local has_groups
        has_groups=$(run_jq -r "($base | has(\"common\")) or ($base | has(\"gnome\")) or ($base | has(\"sway\"))" "$json_file" 2>/dev/null)
        if [[ "$has_groups" == "true" ]]; then
            for group in common gnome sway; do
                if de_group_active "$group"; then
                    get_json_array "$json_file" "$base.$group"
                fi
            done
            return 0
        fi
        # Legacy dnf shape: .packages array
        if [[ -n "$sub_key" ]]; then
            get_json_array "$json_file" "$base.$sub_key"
        fi
        return 0
    fi

    if [[ "$node_type" == "array" ]]; then
        get_json_array "$json_file" "$base"
    fi
}

# Install packages via apt (Debian/Ubuntu)
install_packages_apt() {
    local json_file="$1"

    local packages
    packages=$(collect_de_packages "$json_file" "apt" "")

    if [[ -z "$packages" ]]; then
        log_info "No apt packages configured for current DE selection"
        return 0
    fi

    log_info "Updating apt cache..."
    sudo apt-get update

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if dpkg -l "$pkg" &>/dev/null; then
                log_info "Package already installed: $pkg"
            else
                log_info "Installing package: $pkg"
                sudo apt-get install -y "$pkg" || log_warning "Failed to install: $pkg"
            fi
        fi
    done <<< "$packages"
}

# Add RPM repositories listed under .os.linux.packages.dnf.rpm_repos
install_dnf_rpm_repos() {
    local json_file="$1"
    local repos
    repos=$(get_json_array "$json_file" ".os.linux.packages.dnf.rpm_repos")

    if [[ -z "$repos" ]]; then
        return 0
    fi

    while IFS= read -r repo_url; do
        if [[ -z "$repo_url" ]]; then continue; fi
        # Expand $(...) shell substitutions (e.g. $(rpm -E %fedora))
        local expanded
        expanded=$(eval echo "$repo_url")
        local pkg_name
        pkg_name=$(basename "$expanded" .noarch.rpm)
        if rpm -q "$pkg_name" &>/dev/null; then
            log_info "RPM repo already installed: $pkg_name"
        else
            log_info "Installing RPM repo: $expanded"
            sudo dnf install -y "$expanded" || log_warning "Failed to enable repo: $expanded"
        fi
    done <<< "$repos"
}

# Enable COPR repos listed under .os.linux.packages.dnf.copr
install_dnf_copr() {
    local json_file="$1"
    local copr_repos
    copr_repos=$(get_json_array "$json_file" ".os.linux.packages.dnf.copr")

    if [[ -z "$copr_repos" ]]; then
        return 0
    fi

    if ! command -v dnf &>/dev/null; then
        return 0
    fi

    # Ensure copr plugin is available
    if ! dnf copr --help &>/dev/null; then
        log_info "Installing dnf copr plugin..."
        sudo dnf install -y dnf-plugins-core || log_warning "Failed to install dnf-plugins-core"
    fi

    while IFS= read -r copr; do
        if [[ -z "$copr" ]]; then continue; fi
        local repo_file="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:$(echo "$copr" | tr '/' ':').repo"
        if [[ -f "$repo_file" ]]; then
            log_info "COPR already enabled: $copr"
        else
            log_info "Enabling COPR: $copr"
            sudo dnf copr enable -y "$copr" || log_warning "Failed to enable COPR: $copr"
        fi
    done <<< "$copr_repos"
}

# Install packages via dnf (Fedora/RHEL)
install_packages_dnf() {
    local json_file="$1"

    # Pre-install repos (RPM Fusion, etc.)
    install_dnf_rpm_repos "$json_file"

    # Pre-install COPR repos
    install_dnf_copr "$json_file"

    local packages
    packages=$(collect_de_packages "$json_file" "dnf" "packages")

    if [[ -z "$packages" ]]; then
        log_info "No dnf packages configured for current DE selection"
        return 0
    fi

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if rpm -q "$pkg" &>/dev/null; then
                log_info "Package already installed: $pkg"
            else
                log_info "Installing package: $pkg"
                sudo dnf install -y "$pkg" || log_warning "Failed to install: $pkg"
            fi
        fi
    done <<< "$packages"
}

# Install packages via pacman (Arch Linux)
install_packages_pacman() {
    local json_file="$1"

    local packages
    packages=$(collect_de_packages "$json_file" "pacman" "")

    if [[ -z "$packages" ]]; then
        log_info "No pacman packages configured for current DE selection"
        return 0
    fi

    while IFS= read -r pkg; do
        if [[ -n "$pkg" ]]; then
            if pacman -Q "$pkg" &>/dev/null; then
                log_info "Package already installed: $pkg"
            else
                log_info "Installing package: $pkg"
                sudo pacman -S --noconfirm "$pkg" || log_warning "Failed to install: $pkg"
            fi
        fi
    done <<< "$packages"
}

# Ensure flatpak itself is installed, then add remotes
ensure_flatpak_and_remotes() {
    local json_file="$1"

    if ! command -v flatpak &>/dev/null; then
        log_info "Installing flatpak..."
        case "$(detect_linux_package_manager)" in
            "dnf")    sudo dnf install -y flatpak ;;
            "apt")    sudo apt-get install -y flatpak ;;
            "pacman") sudo pacman -S --noconfirm flatpak ;;
            *)
                log_warning "Cannot install flatpak: no supported package manager"
                return 1
                ;;
        esac
    fi

    # Add remotes defined in JSON
    local remote_count
    remote_count=$(run_jq -r '.os.linux.packages.flatpak.remotes | length // 0' "$json_file" 2>/dev/null)
    if [[ -z "$remote_count" || "$remote_count" == "null" ]]; then
        remote_count=0
    fi

    local i
    for ((i = 0; i < remote_count; i++)); do
        local name url
        name=$(get_json_value "$json_file" ".os.linux.packages.flatpak.remotes[$i].name")
        url=$(get_json_value "$json_file" ".os.linux.packages.flatpak.remotes[$i].url")
        if [[ -n "$name" && -n "$url" ]]; then
            log_info "Adding flatpak remote: $name ($url)"
            flatpak remote-add --if-not-exists --user "$name" "$url" || \
                log_warning "Failed to add flatpak remote: $name"
        fi
    done
}

# Install Flatpak packages (per-user)
install_packages_flatpak() {
    local json_file="$1"

    if ! json_value_exists "$json_file" ".os.linux.packages.flatpak"; then
        return 0
    fi

    ensure_flatpak_and_remotes "$json_file" || return 0

    local packages
    packages=$(get_json_array "$json_file" ".os.linux.packages.flatpak.packages")

    if [[ -z "$packages" ]]; then
        log_info "No flatpak packages configured"
        return 0
    fi

    while IFS= read -r app; do
        if [[ -z "$app" ]]; then continue; fi
        if flatpak info --user "$app" &>/dev/null; then
            log_info "Flatpak already installed: $app"
        else
            log_info "Installing flatpak: $app"
            flatpak install --user -y --noninteractive flathub "$app" || \
                log_warning "Failed to install flatpak: $app"
        fi
    done <<< "$packages"
}

# Install global npm packages
install_packages_npm() {
    local json_file="$1"

    if ! json_value_exists "$json_file" ".os.linux.packages.npm_global"; then
        return 0
    fi

    if ! command -v npm &>/dev/null; then
        log_warning "npm not available; skipping npm_global packages"
        return 0
    fi

    local packages
    packages=$(get_json_array "$json_file" ".os.linux.packages.npm_global")

    while IFS= read -r pkg; do
        if [[ -z "$pkg" ]]; then continue; fi
        if npm list -g --depth=0 "$pkg" &>/dev/null; then
            log_info "npm global already installed: $pkg"
        else
            log_info "Installing npm global: $pkg"
            sudo npm install -g "$pkg" || log_warning "Failed to install npm: $pkg"
        fi
    done <<< "$packages"
}

# Install Python packages with pip --user
install_packages_pip() {
    local json_file="$1"

    if ! json_value_exists "$json_file" ".os.linux.packages.pip_user"; then
        return 0
    fi

    local pip_cmd=""
    if command -v pipx &>/dev/null; then
        pip_cmd="pipx install"
    elif command -v pip3 &>/dev/null; then
        pip_cmd="pip3 install --user --break-system-packages"
    elif command -v pip &>/dev/null; then
        pip_cmd="pip install --user --break-system-packages"
    else
        log_warning "pip not available; skipping pip_user packages"
        return 0
    fi

    local packages
    packages=$(get_json_array "$json_file" ".os.linux.packages.pip_user")

    while IFS= read -r pkg; do
        if [[ -z "$pkg" ]]; then continue; fi
        log_info "Installing pip (user): $pkg"
        $pip_cmd "$pkg" || log_warning "Failed to install pip pkg: $pkg"
    done <<< "$packages"
}

# Install packages based on detected package manager
install_linux_packages() {
    local json_file="$1"
    local pkg_manager

    pkg_manager=$(detect_linux_package_manager)
    log_info "Detected package manager: $pkg_manager"

    case "$pkg_manager" in
        "apt")
            install_packages_apt "$json_file"
            ;;
        "dnf")
            install_packages_dnf "$json_file"
            ;;
        "pacman")
            install_packages_pacman "$json_file"
            ;;
        *)
            log_warning "Unknown package manager. Skipping native package installation."
            log_info "Please install required packages manually."
            ;;
    esac

    # Cross-distro: Flatpak, npm, pip
    install_packages_flatpak "$json_file"
    install_packages_npm "$json_file"
    install_packages_pip "$json_file"
}
