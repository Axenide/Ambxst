#!/usr/bin/env bash
# Ambxst CLI - Main entry point for Ambxst desktop environment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Use environment variables if set by flake, otherwise fall back to PATH
QS_BIN="${AMBXST_QS:-qs}"
NIXGL_BIN="${AMBXST_NIXGL:-}"

# Default action: launch the shell
case "${1:-}" in
    *)
        # Launch QuickShell with the main shell.qml
        if [ -n "$NIXGL_BIN" ]; then
            exec "$NIXGL_BIN" "$QS_BIN" -p "${SCRIPT_DIR}/shell.qml"
        else
            exec "$QS_BIN" -p "${SCRIPT_DIR}/shell.qml"
        fi
        ;;
esac
