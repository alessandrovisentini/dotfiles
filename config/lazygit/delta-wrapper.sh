#!/usr/bin/env bash
# Wrapper for delta that disables side-by-side for new files
# New file diffs have "--- /dev/null" indicating no previous content

input=$(cat)

if echo "$input" | grep -q '^--- /dev/null'; then
    # New file: use unified view (no -s)
    echo "$input" | delta --dark --paging=never --line-numbers
else
    # Edited file: use side-by-side view
    echo "$input" | delta --dark --paging=never --line-numbers -s
fi
