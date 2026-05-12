#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
JSON_FILE="$SCRIPT_DIR/install.json"

# Under `curl | bash` stdin is the pipe; any brew/sudo prompt would hit EOF and
# the step would silently skip (this is how sketchybar/fzf/amethyst slipped through
# before). Reattach stdin to the controlling TTY.
if [[ ! -t 0 && -e /dev/tty ]]; then
    exec < /dev/tty
fi

# Skip the noisy auto-update before every install and the post-install hints.
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/packages.sh"

DETECTED_OS="macos"

parse_install_steps "$@"

log_info "Starting macOS installation..."

if should_run packages; then
    install_homebrew_if_missing
fi

ensure_jq

if should_run packages; then
    log_info "Installing packages via Homebrew..."
    install_packages_homebrew "$JSON_FILE"
fi

should_run symlinks && create_config_symlinks "$JSON_FILE" macos "$REPO_DIR"
should_run shell    && setup_shell_env
should_run post     && run_post_install       "$JSON_FILE" macos

log_success "macOS installation complete!"

cat <<'EOF'

============================================================
Manual steps required after install
============================================================

1. Create Mission Control desktops (macOS has no scripting API for this):
     • F3 (or 3-finger swipe up) to open Mission Control
     • Hover the top edge and click '+' once per extra desktop
     • Option+<n> then switches between them

2. Have Amethyst start at login:
     • System Settings > General > Login Items & Extensions
     • Under "Open at Login", click '+' and add Amethyst.app

3. Remap Caps Lock to Escape:
     • System Settings > Keyboard > Keyboard Shortcuts...
     • > Modifier Keys (bottom of left sidebar)
     • Set "Caps Lock Key" to "Escape"
EOF
