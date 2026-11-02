[[ $- == *i* ]] || return 0

set -o vi
eval "$(fzf --bash)"
