#!/usr/bin/env bash
# Cycle the mode daemon: auto → laptop → tablet → auto (SIGUSR1).
# The daemon applies the change and notifies.

set -u

exec systemctl --user kill -s USR1 mode-daemon.service
