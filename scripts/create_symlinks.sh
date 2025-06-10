#!/usr/bin/env bash

# Define paths to the symlink scripts
NIXOS_SCRIPT="$(dirname "$0")/../nixos/create_symlinks.sh"
CONFIG_SCRIPT="$(dirname "$0")/../config/create_symlinks.sh"

# Ensure scripts exist before execution
if [ -f "$NIXOS_SCRIPT" ]; then
    echo "Executing $NIXOS_SCRIPT"
    bash "$NIXOS_SCRIPT"
else
    echo "Error: $NIXOS_SCRIPT not found."
fi

if [ -f "$CONFIG_SCRIPT" ]; then
    echo "Executing $CONFIG_SCRIPT"
    bash "$CONFIG_SCRIPT"
else
    echo "Error: $CONFIG_SCRIPT not found."
fi
