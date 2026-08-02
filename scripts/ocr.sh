#!/usr/bin/env bash
set -euo pipefail

# Check dependencies
for dep in grim slurp tesseract wl-copy notify-send; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        notify-send "OCR Error" "Missing dependency: $dep" -u critical
        echo "Error: Missing dependency: $dep" >&2
        exit 1
    fi
done

# Select region
REGION=$(slurp)
if [ -z "$REGION" ]; then
    exit 0 # User cancelled
fi

# Capture and OCR
# Languages based on installed tesseract packages:
# eng (English), spa (Spanish), lat (Latin), jpn (Japanese),
# chi_sim (Simplified Chinese), chi_tra (Traditional Chinese), kor (Korean)
if [ -n "${1:-}" ]; then
    LANGS="$1"
else
    # Default fallback if no argument provided
    LANGS="eng+spa"
fi

# Single capture pass: grim writes the region to a temp file, then tesseract
# runs once — stdout is the text, stderr goes to a sidecar file so errors can
# be reported without polluting the text (the old version captured twice).
TMP_IMG=$(mktemp --suffix=.png)
TMP_ERR=$(mktemp)
trap 'rm -f "$TMP_IMG" "$TMP_ERR"' EXIT

if ! grim -g "$REGION" "$TMP_IMG"; then
    notify-send "OCR Error" "Failed to capture the selected region" -u critical -i dialogue-error
    exit 1
fi

TEXT=""
if ! TEXT=$(tesseract "$TMP_IMG" - -l "$LANGS" 2>"$TMP_ERR"); then
    notify-send "OCR Error" "Tesseract failed to process the image" -u critical -i dialogue-error
    cat "$TMP_ERR" >&2
    exit 1
fi

# Trim whitespace
TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    echo "$TEXT" | wl-copy
    notify-send "OCR Result" "Text copied to clipboard" -i edit-paste
else
    notify-send "OCR Result" "No text detected" -u low -i dialogue-error
fi
