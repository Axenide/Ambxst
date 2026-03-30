#!/usr/bin/env bash
# Upload image to uguu.se and open in Google Lens
# Expects image at /tmp/image.png (captured by ScreenshotTool)

set -euo pipefail

IMAGE_PATH="/tmp/image.png"

# Verify image exists
if [[ ! -f "$IMAGE_PATH" ]]; then
	notify-send -u critical "Google Lens" "No image found at $IMAGE_PATH" >&2
	echo "ERROR: Image file not found at $IMAGE_PATH" >&2
	exit 1
fi

# Verify image is readable
if [[ ! -r "$IMAGE_PATH" ]]; then
	notify-send -u critical "Google Lens" "Cannot read image at $IMAGE_PATH" >&2
	echo "ERROR: Image file not readable at $IMAGE_PATH" >&2
	exit 1
fi

# Check dependencies
for cmd in curl jq xdg-open notify-send; do
	if ! command -v "$cmd" &>/dev/null; then
		echo "ERROR: Missing required command: $cmd" >&2
		exit 1
	fi
done

# Notify user that processing has started
notify-send -u normal "Google Lens" "Uploading image for analysis..."

# Upload to uguu.se with error handling
echo "Uploading image to uguu.se..." >&2

# Temporarily disable set -e to handle curl errors gracefully
set +e
uploadResponse=$(curl -sS -f --connect-timeout 10 --max-time 30 -F "files[]=@$IMAGE_PATH" 'https://uguu.se/upload' 2>&1)
curlExit=$?
set -e

if [[ $curlExit -eq 28 ]]; then
    notify-send -u critical "Google Lens" "Upload timed out"
    echo "ERROR: Upload timed out after 30 seconds" >&2
    exit 1
if [[ $curlExit -ne 0 ]]; then
	notify-send -u critical "Google Lens" "Upload failed (curl error $curlExit)" >&2
	echo "ERROR: Upload failed with curl exit code $curlExit" >&2
	echo "Response: $uploadResponse" >&2
	exit 1
fi

# Parse response
imageLink=$(echo "$uploadResponse" | jq -r '.files[0].url' 2>&1)
jqExit=$?

if [[ $jqExit -ne 0 ]] || [[ -z "$imageLink" ]] || [[ "$imageLink" == "null" ]]; then
	notify-send -u critical "Google Lens" "Failed to parse upload response" >&2
	echo "ERROR: Failed to parse upload response" >&2
	echo "Response: $uploadResponse" >&2
	exit 1
fi

echo "Image uploaded successfully: $imageLink" >&2

# Open in Google Lens
lensUrl="https://lens.google.com/uploadbyurl?url=${imageLink}"
echo "Opening in Google Lens: $lensUrl" >&2

if ! xdg-open "$lensUrl" 2>&1; then
	notify-send -u critical "Google Lens" "Failed to open browser" >&2
	echo "ERROR: Failed to open browser" >&2
	exit 1
fi

# Clean up
rm -f "$IMAGE_PATH"
notify-send "Google Lens" "Image opened in browser successfully"
echo "Success: Google Lens opened" >&2
