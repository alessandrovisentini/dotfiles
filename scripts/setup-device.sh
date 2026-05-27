#!/usr/bin/env bash
# Link nixos/device.nix to nixos/devices/<name>.nix based on an exact
# match of /sys/class/dmi/id/product_version. Idempotent; safe to re-run.
# Needed because Nix evaluation can't read sysfs cleanly (it reports a
# page-size length and readFile hits unexpected EOF), so the selector
# can't be computed inside configuration.nix.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMI=$(cat /sys/class/dmi/id/product_version 2>/dev/null || true)

case "$DMI" in
    "ThinkPad X12 Detachable Gen 1") DEV="x12" ;;
    "ThinkPad P14s Gen 4")           DEV="p14s" ;;
    *)
        echo "Unrecognized device (product_version='$DMI')." >&2
        echo "Available device profiles:" >&2
        for p in "$REPO"/nixos/devices/*.nix; do
            echo "  - $(basename "$p" .nix)" >&2
        done
        echo "Add a matcher in scripts/setup-device.sh or create the symlink manually:" >&2
        echo "  ln -sfn devices/<name>.nix $REPO/nixos/device.nix" >&2
        exit 1
        ;;
esac

target="devices/$DEV.nix"
link="$REPO/nixos/device.nix"
if [[ ! -e "$REPO/nixos/$target" ]]; then
    echo "missing source: $REPO/nixos/$target" >&2
    exit 1
fi
ln -sfn "$target" "$link"
printf '  %-30s -> %s\n' "nixos/device.nix" "$target"
echo "Detected device: $DEV (product_version='$DMI')"
