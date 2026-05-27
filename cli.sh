#!/usr/bin/env bash
# Ambxst CLI - Minimal Ambxst fork - It was needed, so here it is. lol

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

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

# Ensure config files exist - copy from preset if missing
ensure_config_files() {
	local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ambxst/config"
	local preset_dir="${SCRIPT_DIR}/assets/presets/Ambxst Default"

	# Create config directory if it doesn't exist
	mkdir -p "$config_dir"

	# Copy preset files if they don't exist (cp -n = no-clobber)
	for file in theme bar workspaces overview notch compositor performance desktop lockscreen dock ai; do
		cp -n "${preset_dir}/${file}.json" "${config_dir}/${file}.json" 2>/dev/null || true
	done
}

# Call it before launching
ensure_config_files

show_help() {
	cat <<EOF
Ambxst CLI - Desktop Environment Control

Usage: ambxst [COMMAND]

Commands:
    (none)                            Launch Ambxst
    update                            Update Ambxst
    refresh                           Refresh local/dev profile (for developers)
    lock                              Activate lockscreen
    reload                            Restart Ambxst
    quit                              Stop Ambxst
    screen [on|off]                   Turn screen on/off
    suspend                           Suspend the system

    brightness <percent> [monitor]    Set brightness (0-100)
    brightness +/-<delta> [monitor]   Adjust brightness relatively
    brightness -s [monitor]           Save current brightness
    brightness -r [monitor]           Restore saved brightness
    brightness -l                     List monitors and their brightness

    volume-up                         Increase volume
    volume-down                       Decrease volume
    volume-mute                       Toggle volume mute
    mic-mute                          Toggle microphone mute
    caffeine                          Toggle caffeine (idle inhibition)
    gamemode                          Toggle game mode
    nightlight                        Toggle night light

    run <command>                     Run any IPC command (launcher, dashboard, overview, etc.)

    help                              Show this help message
    version, -v, --version            Show Ambxst version
    goodbye                           Uninstall Ambxst :(
    install <target>                    Install compositor config (hyprland)
    install hyprland --lua            Install with Lua config (Hyprland >= 0.48)
    install hyprland --conf           Install with config file (default, safe)
    remove <target>                    Remove compositor config (hyprland)

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

AMBXST_HYPR_CONF_SOURCE="source = ~/.local/share/ambxst/hyprland.conf"
AMBXST_HYPR_LUA_SOURCE='loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()'
AMBXST_HYPR_CONF_BLOCK=$(
	cat <<'EOF'
# Ambxst
source = ~/.local/share/ambxst/hyprland.conf

# OVERRIDES
# Down here you can write or source anything that you want to override from Ambxst's settings.
EOF
)
AMBXST_HYPR_LUA_BLOCK=$(
	cat <<'EOF'
-- Ambxst
loadfile(os.getenv("HOME") .. "/.local/share/ambxst/hyprland.lua")()

-- OVERRIDES
-- Down here you can write or source anything that you want to override from Ambxst's settings.
EOF
)

append_ambxst_hyprland_block() {
	local conf="$1"
	local source="$2"
	local block="$3"

	if [ -f "$conf" ] && grep -qF "$source" "$conf"; then
		echo "Ambxst Hyprland block already present in $conf"
		return 0
	fi

	if [ -f "$conf" ] && [ -s "$conf" ]; then
		printf "\n%s\n" "$block" >>"$conf"
	else
		printf "%s\n" "$block" >"$conf"
	fi

	echo "Added Ambxst Hyprland block to $conf"
}

remove_ambxst_hyprland_block() {
	local conf="$1"
	local source="$2"

	if [ ! -f "$conf" ]; then
		echo "$conf does not exist"
		return 0
	fi

	awk -v source="$source" '
		function is_remove(line) {
			return line == source \
				|| line == "# Ambxst" \
				|| line == "-- Ambxst" \
				|| line == "# OVERRIDES" \
				|| line == "-- OVERRIDES" \
				|| line == "# Down here you can write or source anything that you want to override from Ambxst'\''s settings." \
				|| line == "-- Down here you can write or source anything that you want to override from Ambxst'\''s settings." \
				|| line == "exec-once = ambxst" \
				|| line == "exec-once = axctl -c ~/.local/share/ambxst/axctl.toml daemon"
		}
		{
			lines[NR] = $0
		}
		END {
			for (i = 1; i <= NR; i++) {
				line = lines[i]
				nextline = (i < NR) ? lines[i + 1] : ""
				if (is_remove(line)) {
					continue
				}
				if (line == "" && (is_remove(lines[i - 1]) || is_remove(nextline))) {
					continue
				}
				print line
			}
		}
	' "$conf" >"${conf}.tmp" && mv "${conf}.tmp" "$conf"

	echo "Removed Ambxst Hyprland block from $conf"
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
	# Kill axctl processes first (they survive parent death when forked/detached)
	pkill -f "axctl.*daemon" 2>/dev/null || true
	pkill -f "axctl subscribe" 2>/dev/null || true

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
	curl -fsSL github.com/Axenide/Ambxst/ambxst | sh
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

	# toggle-metrics: write directly to notch.json (no IPC needed)
	if [ "$CMD" = "toggle-metrics" ]; then
		# Debounce: prevent double-fire from Hyprland key repeat
		LOCK_FILE="/tmp/ambxst_toggle_metrics.lock"
		if [ -f "$LOCK_FILE" ]; then
			last_run=$(cat "$LOCK_FILE")
			now=$(date +%s%N)
			elapsed=$(( (now - last_run) / 1000000 ))
			if [ "$elapsed" -lt 500 ]; then
				exit 0
			fi
		fi
		date +%s%N > "$LOCK_FILE"

		NOTCH_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/ambxst/config/notch.json"
		if [ -f "$NOTCH_JSON" ]; then
			# Toggle showMetrics in the JSON
			python3 -c "
import json
with open('$NOTCH_JSON') as f:
    cfg = json.load(f)
cfg['showMetrics'] = not cfg.get('showMetrics', False)
with open('$NOTCH_JSON', 'w') as f:
    json.dump(cfg, f, indent=2)
print('Metrics toggled to', cfg['showMetrics'])
" 2>&1 || {
				echo "Error: Failed to toggle metrics"
				exit 1
			}
			exit 0
		else
			echo "Error: notch.json not found at $NOTCH_JSON"
			exit 1
		fi
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
	# Kill axctl processes first
	pkill -f "axctl.*daemon" 2>/dev/null || true
	pkill -f "axctl subscribe" 2>/dev/null || true

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
volume-up|volume-down|volume-mute|mic-mute|caffeine|gamemode|nightlight)
	PID=$(find_ambxst_pid_cached)
	if [ -z "$PID" ]; then
		echo "Error: Ambxst is not running"
		exit 1
	fi
	qs ipc --pid "$PID" call ambxst run "$1" 2>/dev/null || {
		echo "Error: Could not run command '$1'"
		exit 1
	}
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
install)
	TARGET="${2:-}"
	MODE="auto"

	# Parse optional flags
	if [ "$TARGET" = "hyprland" ]; then
		shift 2 2>/dev/null || true
		for arg in "$@"; do
			case "$arg" in
				--lua) MODE="lua" ;;
				--conf) MODE="conf" ;;
				*) echo "Warning: Unknown option '$arg'. Use --lua or --conf." ;;
			esac
		done
	elif [ "$TARGET" != "hyprland" ]; then
		echo "Error: Unknown target '$TARGET'. Supported: hyprland"
		exit 1
	fi

	HYPR_DIR="$HOME/.config/hypr"
	HYPR_LUA="$HYPR_DIR/hyprland.lua"
	HYPR_CONF="$HYPR_DIR/hyprland.conf"
	SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/ambxst"

	# Create directories if needed
	mkdir -p "$HYPR_DIR"
	mkdir -p "$SHARE_DIR"

	# ---- Base config content - always valid conf syntax ----
	BASE_CONF=$(cat <<-'ENDCONF'
exec-once = sh -c '[ -f /tmp/.nl_booted ] || { touch /tmp/.nl_booted && ambxst; }'

# Core binds — baseline for Hyprland reload recovery
bind = SUPER, Super_L, exec, ambxst run launcher
bind = SUPER, D, exec, ambxst run dashboard
bind = SUPER, A, exec, ambxst run assistant
bind = SUPER, V, exec, ambxst run clipboard
bind = SUPER, PERIOD, exec, ambxst run emoji
bind = SUPER, N, exec, ambxst run notes
bind = SUPER, T, exec, ambxst run tmux
bind = SUPER, COMMA, exec, ambxst run wallpapers
bind = SUPER, L, exec, ambxst lock
bind = SUPER, TAB, exec, ambxst run overview
bind = SUPER, ESCAPE, exec, ambxst run powermenu
bind = SUPER, S, exec, ambxst run tools
bind = SUPER SHIFT, C, exec, ambxst run config
bind = SUPER SHIFT, S, exec, ambxst run screenshot
bind = SUPER SHIFT, R, exec, ambxst run screenrecord
bind = SUPER SHIFT, A, exec, ambxst run lens
bind = SUPER SHIFT, BACKSPACE, exec, ambxst run toggle-metrics
ENDCONF
	)

	# ---- Detect mode if auto ----
	if [ "$MODE" = "auto" ]; then
		if [ -f "$HYPR_LUA" ]; then
			# User already has hyprland.lua → stick with lua mode
			MODE="lua"
		elif [ -f "$HYPR_CONF" ]; then
			# User has hyprland.conf → use conf mode
			MODE="conf"
		else
			# No config exists yet → default to conf (safe)
			MODE="conf"
		fi
	fi

	# ---- Generate config files ----
	if [ "$MODE" = "lua" ]; then
		# Write sourced file as valid Lua: returns the config as a string
		# Hyprland's Lua mode (>= 0.48) expects valid Lua; returning a string
		# is the simplest way to embed conf syntax inside Lua.
		{
			printf "return [[\n"
			printf "%s\n" "$BASE_CONF"
			printf "]]\n"
		} > "$SHARE_DIR/hyprland.lua"

		echo "Created compositor Lua config at $SHARE_DIR/hyprland.lua"

		# Main Hyprland config: inject Ambxst block into hyprland.lua
		append_ambxst_hyprland_block "$HYPR_LUA" "$AMBXST_HYPR_LUA_SOURCE" "$AMBXST_HYPR_LUA_BLOCK"

		# Clean up stale .conf if switching from conf to lua
		rm -f "$HYPR_CONF" 2>/dev/null || true
	else
		# Write the plain conf version
		printf "%s\n" "$BASE_CONF" > "$SHARE_DIR/hyprland.conf"

		echo "Created compositor config at $SHARE_DIR/hyprland.conf"

		# Main Hyprland config: inject Ambxst block into hyprland.conf
		append_ambxst_hyprland_block "$HYPR_CONF" "$AMBXST_HYPR_CONF_SOURCE" "$AMBXST_HYPR_CONF_BLOCK"

		# Clean up stale .lua if switching from lua to conf
		rm -f "$HYPR_LUA" 2>/dev/null || true
	fi
	;;
remove)
	TARGET="${2:-}"
	if [ "$TARGET" = "hyprland" ]; then
		HYPR_DIR="$HOME/.config/hypr"
		HYPR_LUA="$HYPR_DIR/hyprland.lua"
		HYPR_CONF="$HYPR_DIR/hyprland.conf"

		remove_ambxst_hyprland_block "$HYPR_LUA" "$AMBXST_HYPR_LUA_SOURCE"
		remove_ambxst_hyprland_block "$HYPR_CONF" "$AMBXST_HYPR_CONF_SOURCE"

		# Clean up stale .lua if user switched from lua to conf mode
		if [ ! -f "$HYPR_CONF" ] && [ -f "$HYPR_LUA" ] && [ ! -s "$HYPR_LUA" ] || grep -q "Ambxst" "$HYPR_LUA" 2>/dev/null; then
			rm -f "$HYPR_LUA" 2>/dev/null || true
		fi
	else
		echo "Error: Unknown target '$TARGET'. Supported: hyprland"
		exit 1
	fi
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
	# Prevent duplicate instances: if Ambxst is already running, exit.
	# This handles Hyprland config reloads where exec-once is re-executed
	# and the daemon tries to start a second Ambxst.
	EXISTING_PID=$(find_ambxst_pid_cached)
	if [ -n "$EXISTING_PID" ]; then
		echo "Ambxst is already running (PID $EXISTING_PID), not starting duplicate."
		exit 0
	fi

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
	unset HL_INITIAL_WORKSPACE_TOKEN

	# Set Qt rendering backend from compositor config (opengl or vulkan)
	COMPOSITOR_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/ambxst/config/compositor.json"
	if [ -f "$COMPOSITOR_CFG" ]; then
		RHI_BACKEND=$(python3 -c "import json; print(json.load(open('$COMPOSITOR_CFG')).get('renderBackend','opengl'))" 2>/dev/null || echo "opengl")
	else
		RHI_BACKEND="opengl"
	fi
	# Let Qt auto-detect the RHI backend (don't force opengl if unavailable)
	# Only set if a working backend was explicitly configured
	if [ "$RHI_BACKEND" = "vulkan" ] || [ "$RHI_BACKEND" = "opengl" ]; then
		export QSG_RHI_BACKEND="$RHI_BACKEND"
	fi
	export QSG_RENDER_LOOP="threaded"
	export QML_XHR_ALLOW_FILE_READ=1

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
