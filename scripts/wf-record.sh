#!/usr/bin/env bash
set -euo pipefail

OUTPUT=""
MODE="screen"
GEOMETRY=""
AUDIO_OUTPUT=false
AUDIO_INPUT=false

# Parse args
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      shift 2
      ;;
    -g|--geometry)
      GEOMETRY="$2"
      shift 2
      ;;
    --audio-output)
      AUDIO_OUTPUT=true
      shift
      ;;
    --audio-input)
      AUDIO_INPUT=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [ -z "$OUTPUT" ]; then
    echo "Error: Output file required"
    exit 1
fi

CMD=(wf-recorder -f "$OUTPUT")

# Geometry/Mode
if [ "$MODE" == "region" ]; then
    if [ -n "$GEOMETRY" ]; then
        CMD+=(-g "$GEOMETRY")
    else
        echo "Error: Geometry required for region mode"
        exit 1
    fi
fi

# Audio Logic
AUDIO_SOURCE=""
MODULE_IDS=""

cleanup() {
    if [ -n "$MODULE_IDS" ]; then
        for id in $MODULE_IDS; do
            pactl unload-module "$id" || true
        done
    fi
}
trap cleanup EXIT

if [ "$AUDIO_OUTPUT" = true ] && [ "$AUDIO_INPUT" = true ]; then
    # Both: Create temporary mixed sink
    SINK_NAME="ambxst+_record_sink_$$"
    
    # Load null sink
    MOD_SINK=$(pactl load-module module-null-sink media.class=Audio/Sink sink_name="$SINK_NAME" channel_map=stereo)
    if [ $? -eq 0 ]; then
        MODULE_IDS="$MOD_SINK"
        
        # Get defaults
        DEFAULT_SINK=$(pactl get-default-sink)
        DEFAULT_SOURCE=$(pactl get-default-source)
        
        # Loopback Output (Monitor) -> Null Sink
        MOD_L1=$(pactl load-module module-loopback source="$DEFAULT_SINK.monitor" sink="$SINK_NAME")
        MODULE_IDS="$MODULE_IDS $MOD_L1"
        
        # Loopback Input (Mic) -> Null Sink
        MOD_L2=$(pactl load-module module-loopback source="$DEFAULT_SOURCE" sink="$SINK_NAME")
        MODULE_IDS="$MODULE_IDS $MOD_L2"
        
        AUDIO_SOURCE="$SINK_NAME.monitor"
    else
        echo "Error: Failed to create null sink"
        exit 1
    fi
    
elif [ "$AUDIO_OUTPUT" = true ]; then
    # Output only (Monitor of default sink)
    DEFAULT_SINK=$(pactl get-default-sink)
    AUDIO_SOURCE="$DEFAULT_SINK.monitor"
    
elif [ "$AUDIO_INPUT" = true ]; then
    # Input only (Default source)
    DEFAULT_SOURCE=$(pactl get-default-source)
    AUDIO_SOURCE="$DEFAULT_SOURCE"
fi

if [ -n "$AUDIO_SOURCE" ]; then
    CMD+=(-a "$AUDIO_SOURCE")
fi

# Use libx264rgb codec for better colors
CMD+=(-c libx264rgb)

echo "Starting recording..."
echo "Command: ${CMD[*]}"

# Execute
"${CMD[@]}"
