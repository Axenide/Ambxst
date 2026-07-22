#!/usr/bin/env bash
set -euo pipefail

# Check dependencies
for dep in grim slurp zbarimg wl-copy notify-send; do
    if ! command -v $dep &> /dev/null; then
        notify-send "QR Scan Error" "Missing dependency: $dep" -u critical
        exit 1
    fi
done

# Select region
REGION=$(slurp)
if [ -z "$REGION" ]; then
    exit 0 # User cancelled
fi

# Capture and Scan
# grim to stdout -> zbarimg from stdin
# zbarimg -q (quiet) --raw (raw output)
RESULT=$(grim -g "$REGION" - | zbarimg -q --raw -)

if [ -n "$RESULT" ]; then
    # zbarimg might return multiple lines if multiple codes are found
    # We'll just copy everything
    echo -n "$RESULT" | wl-copy
    notify-send "QR/Barcode Result" "Content copied to clipboard" -i qr-code
else
    notify-send "QR/Barcode Result" "No code detected" -u low -i dialogue-error
fi
