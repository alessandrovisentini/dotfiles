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
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Install packages via apt (Debian/Ubuntu)
install_packages_apt() {
    local json_file="$1"

    local packages
    packages=$(get_json_array "$json_file" ".os.linux.packages.apt")

    if [[ -z "$packages" ]]; then
        log_info "No apt packages configured"
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

# Install packages via dnf (Fedora/RHEL)
install_packages_dnf() {
    local json_file="$1"

    local packages
    packages=$(get_json_array "$json_file" ".os.linux.packages.dnf")

    if [[ -z "$packages" ]]; then
        log_info "No dnf packages configured"
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
    packages=$(get_json_array "$json_file" ".os.linux.packages.pacman")

    if [[ -z "$packages" ]]; then
        log_info "No pacman packages configured"
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

# Install packages based on detected package manager
install_linux_packages() {
    local json_file="$1"
    local pkg_manager

    pkg_manager=$(detect_linux_package_manager)

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
            log_warning "Unknown package manager. Skipping package installation."
            log_info "Please install required packages manually."
            ;;
    esac
}
