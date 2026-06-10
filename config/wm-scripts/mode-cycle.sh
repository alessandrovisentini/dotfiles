#!/usr/bin/env bash
# Cycle the mode daemon: auto → laptop → tablet → external → auto.

set -u

exec systemctl --user kill -s USR1 mode-daemon.service
