#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCKFILE="$RUNTIME_DIR/ambxst+_sleep_monitor.pid"
set -C
if ! (echo $$ >"$LOCKFILE") 2>/dev/null; then
	PID=$(cat "$LOCKFILE" 2>/dev/null || echo "")
	if [ -n "$PID" ] && [ -O "$LOCKFILE" ] && kill -0 "$PID" 2>/dev/null; then
		exit 0
	fi
	set +C
	rm -f "$LOCKFILE"
	set -C
	echo $$ >"$LOCKFILE"
fi
set +C

# Sleep Monitor - Reports PrepareForSleep events. Command execution is owned
# by IdleService in the shell (QML side), which avoids double-locking and
# shell-eval injection.
#
# We use grep --line-buffered to reliably capture the boolean argument
# which indicates start (true) or end (false) of sleep
dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" |
	grep --line-buffered "boolean" |
	while read -r line; do
		if echo "$line" | grep -q "true"; then
			# Going to sleep
			echo "SUSPEND"
		elif echo "$line" | grep -q "false"; then
			# Waking up
			echo "WAKE"
		fi
	done
