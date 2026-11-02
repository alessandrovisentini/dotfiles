# Source from .bashrc, interactive bash only.

[[ $- == *i* ]] || return 0

set -o vi
eval "$(fzf --bash)"
