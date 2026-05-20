#!/usr/bin/env bash
# Show the grinch launcher: signal the running daemon, or launch it
# if not up (grinch's singleton check handles the rest).

set -u

if pgrep -x grinch >/dev/null; then
    exec pkill -USR1 -x grinch
fi

exec grinch
