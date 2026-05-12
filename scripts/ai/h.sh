#!/usr/bin/env bash
# h — "how to" helper: outputs the shell command to do something
# Usage: h how to list files in a directory

if [ $# -eq 0 ]; then
    echo "Usage: h <what you want to do>" >&2
    exit 1
fi

OS=$(uname -s)
case "$OS" in
    Linux)
        if [ -f /etc/os-release ]; then
            DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
            OS_DESC="Linux ($DISTRO)"
        else
            OS_DESC="Linux"
        fi
        ;;
    Darwin) OS_DESC="macOS" ;;
    *)      OS_DESC="$OS" ;;
esac

PROMPT="You are a terminal command assistant. The user is on $OS_DESC.
Reply with ONLY the shell command that answers their question.
If the command needs explanation or has non-obvious flags, add one short example line prefixed with '# '.
No markdown, no fences, no extra text. Keep it to 1-2 lines max.

Question: $*"

claude --print --model claude-haiku-4-5-20251001 -p "$PROMPT" 2>/dev/null
