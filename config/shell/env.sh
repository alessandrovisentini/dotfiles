# Source from .bashrc / .zshrc / .profile.

export XDG_CACHE_HOME="$HOME/.cache"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

export REPOS_HOME="$HOME/Development/repos"
export TTRPG_NOTES_HOME="$REPOS_HOME/ttrpg-notes"

alias t='$REPOS_HOME/dotfiles/scripts/t.sh'
alias tt='$REPOS_HOME/dotfiles/scripts/tt.sh'
alias ai='$REPOS_HOME/dotfiles/scripts/ai/ai.sh'
alias h='$REPOS_HOME/dotfiles/scripts/ai/h.sh'

# Homebrew nvm; check both prefixes for Intel + Apple Silicon parity.
if [[ "$(uname)" == "Darwin" ]]; then
    export NVM_DIR="$HOME/.nvm"
    [ -d "$NVM_DIR" ] || mkdir -p "$NVM_DIR"
    for nvm_prefix in /opt/homebrew /usr/local; do
        if [ -s "$nvm_prefix/opt/nvm/nvm.sh" ]; then
            # shellcheck disable=SC1090
            . "$nvm_prefix/opt/nvm/nvm.sh"
            break
        fi
    done
    unset nvm_prefix
fi
