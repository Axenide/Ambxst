#!/bin/bash
# gsr-fps.sh — Lanza juego con monitoreo de FPS post-LSFG
# Integrado en NothingLess. Usar: nothingless fps <comando del juego>
#
# Escribe FPS a /dev/shm/gsr-fps-stats para que fps_monitor.py lo lea
# y los muestre en el notch.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSR_FILE="/dev/shm/gsr-fps-stats"
GSR_PID=""

trap "rm -f $GSR_FILE; kill $GSR_PID 2>/dev/null; rm -f /tmp/nothingless-gsr-fps.mp4" EXIT INT TERM

# Iniciar gpu-screen-recorder en modo verbose
# -w screen: captura pantalla completa
# -v yes: verbose mode (genera "update fps: N" a stderr)
# stderr al archivo para fps_monitor.py
gpu-screen-recorder \
    -w screen \
    -f 999 \
    -s 1920x1080 \
    -c mkv \
    -o /tmp/nothingless-gsr-fps.mp4 \
    -v yes \
    -df no \
    2>"$GSR_FILE" &
GSR_PID=$!

# Ejecutar el juego (todos los argumentos)
"$@"
GAME_EXIT=$?

# Cleanup
kill $GSR_PID 2>/dev/null
wait $GSR_PID 2>/dev/null
rm -f "$GSR_FILE" /tmp/nothingless-gsr-fps.mp4
exit $GAME_EXIT
