#!/usr/bin/env bash

# Get the directory where the script is executed
SCRIPT_DIR="$(pwd)"

# Define the NixOS configuration directory
NIXOS_DIR="/etc/nixos"

# Ensure the script is run with appropriate permissions
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root." 
   exit 1
fi

# Create a symlink for hardware-configuration.nix if it doesn't exist
if [ ! -e "$SCRIPT_DIR/hardware-configuration.nix" ]; then
    ln -s "$NIXOS_DIR/hardware-configuration.nix" "$SCRIPT_DIR/hardware-configuration.nix"
    echo "Created symlink: $SCRIPT_DIR/hardware-configuration.nix -> $NIXOS_DIR/hardware-configuration.nix"
else
    echo "Skipping: Symlink already exists for hardware-configuration.nix in $SCRIPT_DIR"
fi

# Remove all .nix files in /etc/nixos except hardware-configuration.nix
find "$NIXOS_DIR" -maxdepth 1 -type f -name "*.nix" ! -name "hardware-configuration.nix" -exec rm -f {} \;

echo "Removed all .nix files in $NIXOS_DIR except hardware-configuration.nix."

# Create symlinks for all .nix files in the script directory to /etc/nixos, except hardware-configuration.nix
for nix_file in "$SCRIPT_DIR"/*.nix; do
    if [[ "$nix_file" != "$SCRIPT_DIR/hardware-configuration.nix" ]]; then
        file_name="$(basename "$nix_file")"
        symlink_path="$NIXOS_DIR/$file_name"

        if [ ! -e "$symlink_path" ]; then
            ln -s "$nix_file" "$symlink_path"
            echo "Created symlink: $symlink_path -> $nix_file"
        else
            echo "Skipping: Symlink or file already exists at $symlink_path"
        fi
    fi
done

