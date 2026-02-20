# Dotfiles shell environment configuration
# Source this file from your .bashrc, .zshrc, or .profile

# XDG Base Directory Specification
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Custom paths
export REPOS_HOME="$HOME/Development/repos"
export TTRPG_NOTES_HOME="$REPOS_HOME/ttrpg-notes"

# Aliases
alias td='$REPOS_HOME/dotfiles/scripts/td.sh'
alias tt='$REPOS_HOME/dotfiles/scripts/tt.sh'

alias ai='$REPOS_HOME/dotfiles/scripts/ai.sh'
alias aim='$REPOS_HOME/dotfiles/scripts/ai.sh -m'
