#!/usr/bin/env bash
# Toggle the grinch launcher: signal the daemon, or start it.

set -u

if pgrep -x grinch >/dev/null; then
    exec pkill -USR1 -x grinch
fi

exec grinch
