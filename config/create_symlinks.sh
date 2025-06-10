#!/usr/bin/env bash

# Set source directory to the script's location
SOURCE_DIR="$(dirname "$(realpath "$0")")"

# Set target directory to $XDG_CONFIG_HOME, defaulting to ~/.config if not set
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

# Ensure target directory exists, if not create it
if [ ! -d "$TARGET_DIR" ]; then
    echo "Target directory '$TARGET_DIR' does not exist. Creating it..."
    mkdir -p "$TARGET_DIR"
fi

# Iterate through each folder in the source directory
for dir in "$SOURCE_DIR"/*; do
    if [ -d "$dir" ]; then
        folder_name="$(basename "$dir")"

        symlink_path="$TARGET_DIR/$folder_name"
        # Create symlink if it does not already exist
        if [ ! -e "$symlink_path" ]; then
            ln -s "$dir" "$symlink_path"
            echo "Created symlink: $symlink_path -> $dir"
        else
            echo "Skipping: Symlink or file already exists at $symlink_path"
        fi
    fi
done
