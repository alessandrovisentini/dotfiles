#!/usr/bin/env bash
# delta wrapper; side-by-side except for new files (`--- /dev/null`).

input=$(cat)

if echo "$input" | grep -q '^--- /dev/null'; then
    echo "$input" | delta --paging=never
else
    echo "$input" | delta --paging=never -s
fi
