#!/usr/bin/env bash
# nothingless-fps — Launch any program with built-in FPS monitoring
#
# Sets LD_PRELOAD=libambfps.so so the game's frame presents are
# intercepted and FPS is written to /dev/shm/nothingless_fps.
# NothingLess's fps_monitor.py reads that file and shows FPS in the notch.
#
# The library only activates when nothingless-fps=1 is in the environment,
# which this script also sets automatically.
#
# Usage:
#   nothingless-fps ./my-game
#   nothingless-fps steam steam://rungameid/730
#   nothingless-fps %command%            (Steam launch options)
#
# Env vars:
#   nothingless-fps=1                    Set automatically by this script
#   AMBXST_FPS_LIB                   Override library path (backward compat)
#   NOTHINGLESS_FPS_LIB              Override library path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Locate libambfps.so ──────────────────────────────────────────
# Search order: env override > next to script > standard install paths
# Check NOTHINGLESS_FPS_LIB first, then fall back to AMBXST_FPS_LIB
if [ -n "${NOTHINGLESS_FPS_LIB:-}" ] && [ -f "$NOTHINGLESS_FPS_LIB" ]; then
    AMBFPS_LIB="$NOTHINGLESS_FPS_LIB"
elif [ -n "${AMBXST_FPS_LIB:-}" ] && [ -f "$AMBXST_FPS_LIB" ]; then
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
    echo "nothingless-fps: libambfps.so not found." >&2
    echo "  Compile: gcc -shared -fPIC -O2 -o libambfps.so fps_preload.c -lm -ldl" >&2
    echo "  Install: cp libambfps.so ~/.local/lib/" >&2
    echo "  Or run: nothingless install" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: nothingless-fps <command> [args...]" >&2
    echo "" >&2
    echo "  Launch a program with built-in FPS monitoring." >&2
    echo "  FPS will appear in the NothingLess notch (enable metrics view)." >&2
    echo "" >&2
    echo "Examples:" >&2
    echo "  nothingless-fps ./my-game" >&2
    echo "  nothingless-fps steam steam://rungameid/730" >&2
    echo "  nothingless-fps vkcube" >&2
    exit 1
fi

# ── Activate FPS interception ────────────────────────────────────
# NOTHINGLESS_FPS is the underscore variant (POSIX shell compatible).
# libambfps.so checks both NOTHINGLESS_FPS, AMBXST_FPS and nothingless-fps env vars.
NOTHINGLESS_FPS=1
AMBXST_FPS=1
LD_PRELOAD="$AMBFPS_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
export NOTHINGLESS_FPS AMBXST_FPS LD_PRELOAD

# ── Ensure /dev/shm is writable ──────────────────────────────────
mkdir -p /dev/shm 2>/dev/null || true

# ── Launch the game ──────────────────────────────────────────────
exec "$@"
