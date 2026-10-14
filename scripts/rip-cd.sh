#!/usr/bin/env bash
# Rip an audio CD to tagged FLAC with whipper, keeping only the tracks.

set -euo pipefail

DEVICE="${CD_DEVICE:-/dev/sr0}"
OUTPUT_DIR="${1:-$HOME/Music}"

if ! command -v whipper &>/dev/null; then
    echo "whipper not found." >&2
    exit 1
fi

if [[ ! -e "$DEVICE" ]]; then
    echo "No disc detected at $DEVICE. Insert a CD and try again." >&2
    exit 1
fi

TMP_DIR=$(mktemp -d)

# Custom templates skip the album/ep/single folder whipper adds by default.
if ! whipper cd -d "$DEVICE" rip \
    -O "$TMP_DIR" \
    --track-template "%A - %d/%t. %a - %n" \
    --disc-template "%A - %d/%A - %d"
then
    echo "Rip failed; partial files left in $TMP_DIR for inspection." >&2
    exit 1
fi

ALBUM_DIR=$(find "$TMP_DIR" -mindepth 1 -maxdepth 1 -type d)
find "$ALBUM_DIR" -type f ! -name '*.flac' -delete

DEST="$OUTPUT_DIR/$(basename "$ALBUM_DIR")"
if [[ -e "$DEST" ]]; then
    echo "Destination already exists: $DEST" >&2
    echo "Ripped files are in $TMP_DIR; move them manually." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
mv "$ALBUM_DIR" "$DEST"
rmdir "$TMP_DIR"

echo "Ripped to: $DEST"
