[[ $- == *i* ]] || return 0

set -o vi

alias t='$REPOS_HOME/dotfiles/scripts/t.sh'
alias rip-cd='$REPOS_HOME/dotfiles/scripts/rip-cd.sh'
if command -v fzf >/dev/null; then eval "$(fzf --bash 2>/dev/null)"; fi
