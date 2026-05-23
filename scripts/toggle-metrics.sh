#!/usr/bin/env bash
# Toggle notch metrics overlay
# IPC call handled by GlobalShortcuts - this triggers the QML handler
qs ipc --pid "$(pidof nothingless)" call nothingless run toggle-metrics 2>/dev/null || true
