#!/usr/bin/env bash
set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCKFILE="$RUNTIME_DIR/ambxst+_loginlock.pid"
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

# Login Lock Monitor - Reports Lock events on stdout. Execution of the
# configured lock command is owned by IdleService in the shell (QML side).
dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Session',member='Lock'" |
	while read -r line; do
		if echo "$line" | grep -q "member=Lock"; then
			echo "LOCK"
		fi
	done
