#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/alessandrovisentini/dotfiles.git"
TARGET_DIR="$HOME/Development/repos/dotfiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Install git if not available
install_git() {
    log_info "Git not found. Installing git..."

    case "$1" in
        "nixos")
            if command -v nix-shell &> /dev/null; then
                log_info "Using nix-shell to temporarily provide git..."
                # Create a wrapper script that uses nix-shell
                cat > /tmp/git-wrapper.sh << 'EOF'
#!/usr/bin/env bash
exec nix-shell -p git --run "git $*"
EOF
                chmod +x /tmp/git-wrapper.sh
                # Add to PATH for this session
                export PATH="/tmp:$PATH"
                # Create git symlink
                ln -sf /tmp/git-wrapper.sh /tmp/git
                log_success "Temporary git installation set up"
            else
                log_error "NixOS detected but nix-shell not available. Please add git to your system configuration or install it manually."
                log_info "To add git permanently, add 'git' to environment.systemPackages in your /etc/nixos/configuration.nix"
                exit 1
            fi
            ;;
        "macos")
            if command -v brew &> /dev/null; then
                brew install git || {
                    log_error "Failed to install git with brew"
                    exit 1
                }
            elif command -v xcode-select &> /dev/null; then
                log_info "Installing Xcode Command Line Tools (includes git)..."
                xcode-select --install
                log_info "Please complete the Xcode Command Line Tools installation and run this script again."
                exit 0
            else
                log_error "Neither Homebrew nor Xcode Command Line Tools available. Please install git manually."
                exit 1
            fi
            ;;
        *)
            # Try common package managers
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y git
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y git
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm git
            elif command -v zypper &> /dev/null; then
                sudo zypper install -y git
            else
                log_error "No supported package manager found. Please install git manually and run this script again."
                exit 1
            fi
            ;;
    esac

    log_success "Git installed successfully"
}

# Check if git is available
if ! command -v git &> /dev/null; then
    # We need to detect OS early for git installation
    if [[ "$OSTYPE" == "darwin"* ]]; then
        TEMP_OS="macos"
    elif [ -f /etc/nixos/configuration.nix ] || command -v nixos-rebuild &> /dev/null; then
        TEMP_OS="nixos"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "nixos" ]]; then
            TEMP_OS="nixos"
        else
            TEMP_OS="linux"
        fi
    else
        TEMP_OS="unknown"
    fi

    install_git "$TEMP_OS"
fi

# Create Development directory structure
log_info "Creating directory structure..."
mkdir -p "$HOME/Development/repos"

# Clone or update repository
if [ -d "$TARGET_DIR" ]; then
    log_warning "Directory $TARGET_DIR already exists. Updating..."
    cd "$TARGET_DIR"
    git pull origin main || {
        log_error "Failed to update repository. Please check your internet connection."
        exit 1
    }
else
    log_info "Cloning dotfiles repository..."
    git clone "$REPO_URL" "$TARGET_DIR" || {
        log_error "Failed to clone repository. Please check your internet connection."
        exit 1
    }
fi

cd "$TARGET_DIR"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [ -f /etc/nixos/configuration.nix ] || command -v nixos-rebuild &> /dev/null; then
        echo "nixos"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "nixos" ]]; then
            echo "nixos"
        else
            echo "linux"
        fi
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
log_info "Detected operating system: $OS"

case "$OS" in
    "nixos")
        log_info "Setting up NixOS configuration..."

        # Check if running as root for NixOS setup
        if [[ $EUID -eq 0 ]]; then
            log_error "Do not run this script as root. The script will handle privilege escalation."
            exit 1
        fi

        # Run NixOS symlinks as root
        log_info "Creating NixOS configuration symlinks (requires sudo)..."
        cd nixos
        sudo ./create_symlinks.sh || {
            log_error "Failed to create NixOS symlinks"
            exit 1
        }
        cd ..
        log_success "NixOS configuration symlinks created"

        # Run config symlinks as user
        log_info "Creating .config symlinks..."
        cd config
        ./create_symlinks.sh || {
            log_error "Failed to create .config symlinks"
            exit 1
        }
        cd ..
        log_success ".config symlinks created"

        log_success "NixOS setup complete! Run 'sudo nixos-rebuild switch' to apply changes."
        ;;

    "macos")
        log_info "Setting up macOS configuration..."

        # Only run config symlinks for macOS
        log_info "Creating .config symlinks..."
        cd config
        ./create_symlinks.sh || {
            log_error "Failed to create .config symlinks"
            exit 1
        }
        cd ..
        log_success "macOS setup complete!"
        ;;

    *)
        log_warning "Unsupported or unknown operating system: $OS"
        log_info "Only creating .config symlinks..."
        cd config
        ./create_symlinks.sh || {
            log_error "Failed to create .config symlinks"
            exit 1
        }
        cd ..
        log_success "Basic setup complete!"
        ;;
esac

log_success "Dotfiles installation completed successfully!"
log_info "Repository location: $TARGET_DIR"
