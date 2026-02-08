#!/usr/bin/env bash
# Ambxst CLI - It was needed, so here it is. lol

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use environment variables if set by flake, otherwise fall back to PATH
QS_BIN="${AMBXST_QS:-qs}"
NIXGL_BIN="${AMBXST_NIXGL:-}"

if [ -z "${QML2_IMPORT_PATH:-}" ]; then
	if command -v qs >/dev/null 2>&1; then
		true
	fi
fi

# If QML2_IMPORT_PATH is set (by wrapper or dev shell), ensure QML_IMPORT_PATH matches
if [ -n "${QML2_IMPORT_PATH:-}" ] && [ -z "${QML_IMPORT_PATH:-}" ]; then
	export QML_IMPORT_PATH="$QML2_IMPORT_PATH"
fi

show_help() {
	cat <<EOF
Ambxst CLI - Desktop Environment Control

Usage: ambxst [COMMAND]

Commands:
    (none)                            Launch Ambxst
    update                            Update Ambxst
    refresh                           Refresh local/dev profile (for developers)
    lock                              Activate lockscreen
    brightness <percent> [monitor]    Set brightness (0-100)
    brightness +/-<delta> [monitor]   Adjust brightness relatively
    brightness -s [monitor]           Save current brightness
    brightness -r [monitor]           Restore saved brightness
    brightness -l                     List monitors and their brightness
    help                              Show this help message
    version, -v, --version            Show Ambxst version
    goodbye                           Uninstall Ambxst :(

Examples:
    ambxst brightness 75              Set all monitors to 75%
    ambxst brightness 50 HDMI-A-1     Set HDMI-A-1 to 50%
    ambxst brightness +10             Increase brightness by 10%
    ambxst brightness -5 HDMI-A-1     Decrease HDMI-A-1 brightness by 5%
    ambxst brightness 10 -s           Save current, then set all to 10%
    ambxst brightness -s HDMI-A-1     Save current brightness of HDMI-A-1
    ambxst brightness -r              Restore saved brightness

EOF
}

find_ambxst_pid() {
	# Try to find QuickShell process running shell.qml
	# QuickShell binary can be named 'qs' or 'quickshell'
	local pid

	# First try with full path (production/flake mode)
	pid=$(pgrep -f "qs.*${SCRIPT_DIR}/shell.qml" 2>/dev/null | head -1)
	if [ -z "$pid" ]; then
		pid=$(pgrep -f "quickshell.*${SCRIPT_DIR}/shell.qml" 2>/dev/null | head -1)
	fi

	# If not found, try with relative path (development mode)
	if [ -z "$pid" ]; then
		pid=$(pgrep -f "qs.*shell.qml" 2>/dev/null | head -1)
	fi
	if [ -z "$pid" ]; then
		pid=$(pgrep -f "quickshell.*shell.qml" 2>/dev/null | head -1)
	fi

	# Last resort: find any qs/quickshell process in this directory
	if [ -z "$pid" ]; then
		pid=$(pgrep -a "qs" 2>/dev/null | grep -F "$SCRIPT_DIR" | awk '{print $1}' | head -1)
	fi
	if [ -z "$pid" ]; then
		pid=$(pgrep -a quickshell 2>/dev/null | grep -F "$SCRIPT_DIR" | awk '{print $1}' | head -1)
	fi

	echo "$pid"
}

find_ambxst_pid_cached() {
	# Optimized PID lookup: check cache file first, then fall back to pgrep
	local pid_file="/tmp/ambxst.pid"
	local pid=""

	# Check if cache file exists and process is alive
	if [ -f "$pid_file" ]; then
		pid=$(<"$pid_file" 2>/dev/null)
		# Verify process still exists using kill -0 (no signal, just test)
		if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
			echo "$pid"
			return 0
		fi
		# PID is stale, remove cache file
		rm -f "$pid_file"
	fi

	# Fallback: use expensive pgrep search
	pid=$(find_ambxst_pid)
	echo "$pid"
}

restart_ambxst() {
	PID=$(find_ambxst_pid_cached)
	if [ -n "$PID" ]; then
		echo "Stopping Ambxst (PID $PID)..."
		kill "$PID"
		# Wait for process to exit
		while kill -0 "$PID" 2>/dev/null; do
			sleep 0.1
		done
	fi
	echo "Starting Ambxst..."
	# Relaunch the script in background
	nohup "$0" >/dev/null 2>&1 &
}

case "${1:-}" in
update)
	echo "Updating Ambxst..."
	curl -fsSL get.axeni.de/ambxst | sh
	restart_ambxst
	;;
refresh)
	echo "Refreshing Ambxst profile..."
	exec nix profile upgrade Ambxst --refresh --impure
	;;
run)
	CMD="${2:-}"
	PIPE="/tmp/ambxst_ipc.pipe"

	if [ -z "$CMD" ]; then
		echo "Error: No command specified for run"
		exit 1
	fi

	# Fast path: Write directly to pipe if it exists (Zero latency)
	if [ -p "$PIPE" ]; then
		echo "$CMD" >"$PIPE" &
		exit 0
	fi

	# Fallback path: Use QS IPC with cached PID lookup
	PID=$(find_ambxst_pid_cached)
	if [ -z "$PID" ]; then
		echo "Error: Ambxst is not running"
		exit 1
	fi

	qs ipc --pid "$PID" call ambxst run "$CMD" 2>/dev/null || {
		echo "Error: Could not run command '$CMD'"
		exit 1
	}
	;;
lock)
	PID=$(find_ambxst_pid_cached)
	if [ -z "$PID" ]; then
		echo "Error: Ambxst is not running"
		exit 1
	fi
	qs ipc --pid "$PID" call ambxst run lockscreen 2>/dev/null || {
		echo "Error: Could not activate lockscreen"
		exit 1
	}
	;;
reload)
	restart_ambxst
	;;
quit)
	PID=$(find_ambxst_pid_cached)
	if [ -n "$PID" ]; then
		echo "Stopping Ambxst (PID $PID)..."
		kill "$PID"
	else
		echo "Ambxst is not running"
	fi
	;;
screen)
	SUB="${2:-}"
	if [ "$SUB" = "off" ]; then
		if command -v hyprctl &>/dev/null; then
			hyprctl dispatch dpms off
		else
			notify-send "Screen Off" "Not supported on this compositor yet"
		fi
	elif [ "$SUB" = "on" ]; then
		if command -v hyprctl &>/dev/null; then
			hyprctl dispatch dpms on
		else
			notify-send "Screen On" "Not supported on this compositor yet"
		fi
	else
		echo "Usage: ambxst screen [on|off]"
		exit 1
	fi
	;;
suspend)
	if command -v systemctl &>/dev/null; then
		systemctl suspend
	elif command -v loginctl &>/dev/null; then
		loginctl suspend
	else
		# Fallback to D-Bus
		dbus-send --system --print-reply --dest=org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager.Suspend boolean:true
	fi
	;;
brightness)
	PID=$(find_ambxst_pid_cached)
	if [ -z "$PID" ]; then
		echo "Error: Ambxst is not running"
		exit 1
	fi

	BRIGHTNESS_SAVE_FILE="/tmp/ambxst_brightness_saved.txt"

	# Parse arguments
	ARG2="${2:-}"
	ARG3="${3:-}"
	ARG4="${4:-}"

	# Handle list flag
	if [ "$ARG2" = "-l" ] || [ "$ARG2" = "--list" ]; then
		echo "Monitors:"
		if command -v hyprctl &>/dev/null; then
			hyprctl monitors -j 2>/dev/null | jq -r '.[] | "  \(.name)"' || {
				echo "Error: Could not list monitors"
				exit 1
			}
		else
			echo "Error: hyprctl not found"
			exit 1
		fi
		exit 0
	fi

	# Handle restore flag
	if [ "$ARG2" = "-r" ] || [ "$ARG2" = "--restore" ]; then
		if [ ! -f "$BRIGHTNESS_SAVE_FILE" ]; then
			echo "Error: No saved brightness found. Use -s to save first."
			exit 1
		fi

		MONITOR="${ARG3:-}"

		if [ -z "$MONITOR" ]; then
			# Restore all monitors
			while IFS=: read -r name value; do
				if [ -n "$name" ] && [ -n "$value" ]; then
					NORMALIZED=$(awk "BEGIN {printf \"%.2f\", $value / 100}")
					qs ipc --pid "$PID" call brightness set "$NORMALIZED" "$name" 2>/dev/null || {
						echo "Warning: Could not restore brightness for $name"
					}
				fi
			done <"$BRIGHTNESS_SAVE_FILE"
			echo "Restored brightness for all monitors"
		else
			# Restore specific monitor
			VALUE=$(grep "^${MONITOR}:" "$BRIGHTNESS_SAVE_FILE" | cut -d: -f2)
			if [ -z "$VALUE" ]; then
				echo "Error: No saved brightness for monitor $MONITOR"
				exit 1
			fi
			NORMALIZED=$(awk "BEGIN {printf \"%.2f\", $VALUE / 100}")
			qs ipc --pid "$PID" call brightness set "$NORMALIZED" "$MONITOR" 2>/dev/null || {
				echo "Error: Could not restore brightness for $MONITOR"
				exit 1
			}
			echo "Restored brightness for $MONITOR to ${VALUE}%"
		fi
		exit 0
	fi

	# Parse value and monitor/flags
	VALUE=""
	MONITOR=""
	SAVE_FLAG=false
	RELATIVE_MODE=false
	RELATIVE_DELTA=0

	if [[ "$ARG2" =~ ^[0-9]+$ ]]; then
		VALUE="$ARG2"
		if [ "$ARG3" = "-s" ] || [ "$ARG3" = "--save" ]; then
			SAVE_FLAG=true
		elif [ -n "$ARG3" ] && [ "$ARG3" != "-s" ] && [ "$ARG3" != "--save" ]; then
			MONITOR="$ARG3"
			if [ "$ARG4" = "-s" ] || [ "$ARG4" = "--save" ]; then
				SAVE_FLAG=true
			fi
		fi
	elif [[ "$ARG2" =~ ^[+-][0-9]+$ ]]; then
		# Relative mode: +10 or -5
		RELATIVE_MODE=true
		RELATIVE_DELTA="$ARG2"
		if [ -n "$ARG3" ] && [ "$ARG3" != "-s" ] && [ "$ARG3" != "--save" ]; then
			MONITOR="$ARG3"
			if [ "$ARG4" = "-s" ] || [ "$ARG4" = "--save" ]; then
				SAVE_FLAG=true
			fi
		elif [ "$ARG3" = "-s" ] || [ "$ARG3" = "--save" ]; then
			SAVE_FLAG=true
		fi
	elif [ "$ARG2" = "-s" ] || [ "$ARG2" = "--save" ]; then
		# Just save, no value change
		MONITOR="${ARG3:-}"
		if [ -z "$MONITOR" ]; then
			# Save all monitors
			bash "${SCRIPT_DIR}/scripts/brightness_list.sh" >"${BRIGHTNESS_SAVE_FILE}.tmp" 2>/dev/null || {
				echo "Warning: Could not query current brightness"
			}
			if [ -f "${BRIGHTNESS_SAVE_FILE}.tmp" ]; then
				while IFS=: read -r name bright method; do
					if [ -n "$name" ] && [ -n "$bright" ]; then
						echo "${name}:${bright}"
					fi
				done <"${BRIGHTNESS_SAVE_FILE}.tmp" >"$BRIGHTNESS_SAVE_FILE"
				rm -f "${BRIGHTNESS_SAVE_FILE}.tmp"
				echo "Saved current brightness for all monitors"
			fi
		else
			# Save specific monitor
			CURRENT_LINE=$(bash "${SCRIPT_DIR}/scripts/brightness_list.sh" 2>/dev/null | grep "^${MONITOR}:")
			if [ -z "$CURRENT_LINE" ]; then
				echo "Error: Monitor $MONITOR not found"
				exit 1
			fi
			CURRENT=$(echo "$CURRENT_LINE" | cut -d: -f2)
			if [ -f "$BRIGHTNESS_SAVE_FILE" ]; then
				grep -v "^${MONITOR}:" "$BRIGHTNESS_SAVE_FILE" >"${BRIGHTNESS_SAVE_FILE}.tmp" 2>/dev/null || true
				echo "${MONITOR}:${CURRENT}" >>"${BRIGHTNESS_SAVE_FILE}.tmp"
				mv "${BRIGHTNESS_SAVE_FILE}.tmp" "$BRIGHTNESS_SAVE_FILE"
			else
				echo "${MONITOR}:${CURRENT}" >"$BRIGHTNESS_SAVE_FILE"
			fi
			echo "Saved current brightness for $MONITOR (${CURRENT}%)"
		fi
		exit 0
	else
		echo "Error: Invalid brightness value. Must be 0-100 or +/-delta."
		echo "Run 'ambxst help' for usage information"
		exit 1
	fi

	# Handle relative mode - use IPC adjust function directly
	if [ "$RELATIVE_MODE" = true ]; then
		# Convert delta to 0-1 range
		NORMALIZED_DELTA=$(awk "BEGIN {printf \"%.2f\", $RELATIVE_DELTA / 100}")

		if [ -z "$MONITOR" ]; then
			qs ipc --pid "$PID" call brightness adjust "$NORMALIZED_DELTA" "" 2>/dev/null || {
				echo "Error: Could not adjust brightness"
				exit 1
			}
			echo "Adjusted brightness by ${RELATIVE_DELTA}% for all monitors"
		else
			qs ipc --pid "$PID" call brightness adjust "$NORMALIZED_DELTA" "$MONITOR" 2>/dev/null || {
				echo "Error: Could not adjust brightness for $MONITOR"
				exit 1
			}
			echo "Adjusted brightness by ${RELATIVE_DELTA}% for $MONITOR"
		fi
		exit 0
	fi

	# Validate brightness range
	if [ "$VALUE" -lt 0 ] || [ "$VALUE" -gt 100 ]; then
		echo "Error: Brightness must be between 0 and 100"
		exit 1
	fi

	# Save current brightness if requested
	if [ "$SAVE_FLAG" = true ]; then
		if [ -z "$MONITOR" ]; then
			# Save all monitors - we need to get current brightness
			# For simplicity, we'll use a helper script to query current brightness
			bash "${SCRIPT_DIR}/scripts/brightness_list.sh" >"${BRIGHTNESS_SAVE_FILE}.tmp" 2>/dev/null || {
				echo "Warning: Could not query current brightness"
			}
			# Convert format from name:brightness:method to name:brightness
			if [ -f "${BRIGHTNESS_SAVE_FILE}.tmp" ]; then
				while IFS=: read -r name bright method; do
					if [ -n "$name" ] && [ -n "$bright" ]; then
						echo "${name}:${bright}"
					fi
				done <"${BRIGHTNESS_SAVE_FILE}.tmp" >"$BRIGHTNESS_SAVE_FILE"
				rm -f "${BRIGHTNESS_SAVE_FILE}.tmp"
				echo "Saved current brightness for all monitors"
			fi
		else
			# Save specific monitor
			CURRENT_LINE=$(bash "${SCRIPT_DIR}/scripts/brightness_list.sh" 2>/dev/null | grep "^${MONITOR}:")
			if [ -z "$CURRENT_LINE" ]; then
				echo "Error: Monitor $MONITOR not found"
				exit 1
			fi
			CURRENT=$(echo "$CURRENT_LINE" | cut -d: -f2)
			# Update or append to save file
			if [ -f "$BRIGHTNESS_SAVE_FILE" ]; then
				grep -v "^${MONITOR}:" "$BRIGHTNESS_SAVE_FILE" >"${BRIGHTNESS_SAVE_FILE}.tmp" 2>/dev/null || true
				echo "${MONITOR}:${CURRENT}" >>"${BRIGHTNESS_SAVE_FILE}.tmp"
				mv "${BRIGHTNESS_SAVE_FILE}.tmp" "$BRIGHTNESS_SAVE_FILE"
			else
				echo "${MONITOR}:${CURRENT}" >"$BRIGHTNESS_SAVE_FILE"
			fi
			echo "Saved current brightness for $MONITOR (${CURRENT}%)"
		fi
	fi

	# Set brightness
	NORMALIZED=$(awk "BEGIN {printf \"%.2f\", $VALUE / 100}")

	if [ -z "$MONITOR" ]; then
		# Set all monitors
		qs ipc --pid "$PID" call brightness set "$NORMALIZED" "" 2>/dev/null || {
			echo "Error: Could not set brightness"
			exit 1
		}
		echo "Set brightness to ${VALUE}% for all monitors"
	else
		# Set specific monitor
		qs ipc --pid "$PID" call brightness set "$NORMALIZED" "$MONITOR" 2>/dev/null || {
			echo "Error: Could not set brightness for $MONITOR"
			exit 1
		}
		echo "Set brightness to ${VALUE}% for $MONITOR"
	fi
	;;
version | -v | --version)
	echo "Ambxst $(cat "${SCRIPT_DIR}/version")"
	;;
goodbye)
	echo "Uninstalling Ambxst..."

	read -p "Are you sure? (y/N): " -n 1 -r
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "Uninstall aborted."
		exit 0
	fi

	if [ -f /etc/NIXOS ]; then
		if nix profile list 2>/dev/null | grep -q "Ambxst"; then
			echo "Removing from nix profile..."
			nix profile remove Ambxst
		elif command -v ambxst >/dev/null 2>&1; then
			echo "Ambxst was declared in this system. Please remove it from your configuration in order to uninstall."
		else
			echo "Ambxst is not installed."
		fi
		exit 0
	fi

	read -p "Remove configuration files? (y/N): " -n 1 -r
	echo
	REMOVE_CONFIG=false
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		REMOVE_CONFIG=true
	fi

	rm -rf "$HOME/.local/src/ambxst"
	rm -rf "$HOME/.local/share/ambxst"
	rm -rf "$HOME/.local/state/ambxst"

	if [ "$REMOVE_CONFIG" = true ]; then
		rm -rf "$HOME/.config/ambxst"
		echo "Configuration files removed."
	fi

	echo "Ambxst uninstalled. :("
	;;
help | --help | -h)
	show_help
	;;
"")
	# Run daemon priority script (backgrounded to not block startup)
	bash "${SCRIPT_DIR}/scripts/daemon_priority.sh" &

	# Set QS_ICON_THEME environment variable
	if command -v gsettings >/dev/null 2>&1; then
		export QS_ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme | tr -d "'")
	else
		echo "DEBUG: gsettings not found in PATH" >&2
	fi

	# Force Qt6CT
	export QT_QPA_PLATFORMTHEME=qt6ct

	# Cache this script's PID before exec (for fast PID lookups in future CLI calls)
	echo $$ >/tmp/ambxst.pid

	# Launch QuickShell with the main shell.qml
	# If NIXGL_BIN is set (NixOS/Nix setup), use it. Otherwise, just run qs directly.
	if [ -n "$NIXGL_BIN" ]; then
		exec "$NIXGL_BIN" "$QS_BIN" -p "${SCRIPT_DIR}/shell.qml"
	else
		exec qs -p "${SCRIPT_DIR}/shell.qml"
	fi
	;;
*)
	echo "Error: Unknown command '$1'"
	echo "Run 'ambxst help' for usage information"
	exit 1
	;;
esac
