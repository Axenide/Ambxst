#!/usr/bin/env bash
set -euo pipefail
# Clipboard watcher that triggers checks on clipboard changes
# Usage: clipboard_watch.sh <check_script> <db_path> <insert_script> <data_dir>

CHECK_SCRIPT="$1"
DB_PATH="$2"
INSERT_SCRIPT="$3"
DATA_DIR="$4"

# Function to check clipboard and output refresh signal on success
check_clipboard() {
	# Drain stdin to avoid blocking wl-paste
	cat >/dev/null

	if "$CHECK_SCRIPT" "$DB_PATH" "$INSERT_SCRIPT" "$DATA_DIR"; then
		echo "REFRESH_LIST"
	else
		echo "Check failed with code $?" >&2
	fi
}

# Export function and variables for use by wl-paste --watch
export -f check_clipboard
export CHECK_SCRIPT DB_PATH INSERT_SCRIPT DATA_DIR

# Watch clipboard and check on every change
# wl-paste --watch runs the given command with clipboard content on stdin
exec wl-paste --watch bash -c 'check_clipboard'
