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

# Pipe grim output to tesseract stdin (-) and output to stdout (-)
# Capture stderr for error reporting
OCR_OUTPUT=""
OCR_ERROR=""
if ! OCR_OUTPUT=$(grim -g "$REGION" - | tesseract - - -l "$LANGS" 2>&1); then
    notify-send "OCR Error" "Tesseract failed to process the image" -u critical -i dialogue-error
    echo "Error: Tesseract processing failed" >&2
    echo "$OCR_OUTPUT" >&2
    exit 1
fi

# Split stdout and stderr (tesseract may output warnings on stderr)
# Re-run with stderr separated for clean text extraction
TEXT=$(grim -g "$REGION" - | tesseract - - -l "$LANGS" 2>/dev/null) || {
    notify-send "OCR Error" "Failed to extract text" -u critical -i dialogue-error
    exit 1
}

# Trim whitespace
TEXT=$(echo "$TEXT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

if [ -n "$TEXT" ]; then
    echo "$TEXT" | wl-copy
    notify-send "OCR Result" "Text copied to clipboard" -i edit-paste
else
    notify-send "OCR Result" "No text detected" -u low -i dialogue-error
fi
