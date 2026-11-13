#!/usr/bin/env bash

input=$(cat)

if echo "$input" | grep -q '^--- /dev/null'; then
    echo "$input" | delta --paging=never
else
    echo "$input" | delta --paging=never -s
fi
