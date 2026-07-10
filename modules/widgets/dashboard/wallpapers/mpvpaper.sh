#!/usr/bin/env bash

if [ -z "$1" ]; then
	echo "Use: $0 /path/to/wallpaper [shader_path] [monitor_target]"
	exit 1
fi

WALLPAPER="$1"
SHADER="$2"
MONITOR="${3:-ALL}"

# Kill existing mpvpaper instances (all, or just this monitor's).
#
# NOTE: we match on the command line rather than the process name. When mpvpaper
# is launched through a wrapper its process name may not be exactly "mpvpaper"
# (e.g. ".mpvpaper-wrapped"), so `pkill -x mpvpaper` can silently match nothing
# and leave old decoders running on every wallpaper change (wasting GPU).
# Matching the cmdline is reliable regardless of packaging; we explicitly skip
# this launcher script so it never kills itself.
for pid in $(pgrep -f mpvpaper 2>/dev/null); do
    [ "$pid" = "$$" ] && continue
    args=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
    [ -z "$args" ] && continue
    case "$args" in
        *mpvpaper.sh*) continue ;;   # never kill the launcher script
        *mpvpaper*) ;;               # an actual mpvpaper process
        *) continue ;;
    esac
    if [ "$MONITOR" = "ALL" ] || printf '%s' "$args" | grep -q -- "$MONITOR"; then
        kill "$pid" 2>/dev/null
    fi
done
SOCKET="/tmp/ambxst_mpv_socket_${MONITOR}"

MPV_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 load-scripts=no input-ipc-server=$SOCKET"

# Si el shader no está vacío y el archivo existe, agregarlo a MPV_OPTS
if [ -n "$SHADER" ] && [ -f "$SHADER" ]; then
	MPV_OPTS="$MPV_OPTS glsl-shaders=$SHADER"
fi

nohup mpvpaper -o "$MPV_OPTS" "$MONITOR" "$WALLPAPER" >/tmp/mpvpaper.log 2>&1 &
