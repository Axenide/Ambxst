#!/usr/bin/env bash
# ambxst-fps — Launch any program with built-in FPS monitoring
#
# Sets LD_PRELOAD=libambfps.so so the game's frame presents are
# intercepted and FPS is written to /dev/shm/ambxst_fps.
# Ambxst's fps_monitor.py reads that file and shows FPS in the notch.
#
# The library only activates when ambxst-fps=1 is in the environment,
# which this script also sets automatically.
#
# Usage:
#   ambxst-fps ./my-game
#   ambxst-fps steam steam://rungameid/730
#   ambxst-fps %command%            (Steam launch options)
#
# Env vars:
#   ambxst-fps=1                    Set automatically by this script
#   AMBXST_FPS_LIB                   Override library path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate libambfps.so ──────────────────────────────────────────
# Search order: env override > next to script > standard install paths
if [ -n "${AMBXST_FPS_LIB:-}" ] && [ -f "$AMBXST_FPS_LIB" ]; then
    AMBFPS_LIB="$AMBXST_FPS_LIB"
elif [ -f "$SCRIPT_DIR/libambfps.so" ]; then
    AMBFPS_LIB="$SCRIPT_DIR/libambfps.so"
elif [ -f "$HOME/.local/lib/libambfps.so" ]; then
    AMBFPS_LIB="$HOME/.local/lib/libambfps.so"
elif [ -f "/usr/local/lib/libambfps.so" ]; then
    AMBFPS_LIB="/usr/local/lib/libambfps.so"
elif libambfps="$(command -v libambfps.so 2>/dev/null)"; then
    AMBFPS_LIB="$libambfps"
else
    echo "ambxst-fps: libambfps.so not found." >&2
    echo "  Compile: gcc -shared -fPIC -O2 -o libambfps.so fps_preload.c -lm -ldl" >&2
    echo "  Install: cp libambfps.so ~/.local/lib/" >&2
    echo "  Or run: ambxst install" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: ambxst-fps <command> [args...]" >&2
    echo "" >&2
    echo "  Launch a program with built-in FPS monitoring." >&2
    echo "  FPS will appear in the Ambxst notch (enable metrics view)." >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  ambxst-fps ./my-game" >&2
    echo "  ambxst-fps steam steam://rungameid/730" >&2
    echo "  ambxst-fps vkcube" >&2
    exit 1
fi

# ── Activate FPS interception ────────────────────────────────────
# AMBXST_FPS is the underscore variant (POSIX shell compatible).
# libambfps.so checks both AMBXST_FPS and ambxst-fps env vars.
AMBXST_FPS=1
LD_PRELOAD="$AMBFPS_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
export AMBXST_FPS LD_PRELOAD

# ── Ensure /dev/shm is writable ──────────────────────────────────
mkdir -p /dev/shm 2>/dev/null || true

# ── Launch the game ──────────────────────────────────────────────
exec "$@"
