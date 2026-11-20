[[ $- == *i* ]] || return 0

set -o vi
if command -v fzf >/dev/null; then eval "$(fzf --bash 2>/dev/null)"; fi
