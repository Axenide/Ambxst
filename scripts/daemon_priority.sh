#!/usr/bin/env bash

# Kill notification daemons that may conflict
for daemon in dunst mako swaync; do
  if pgrep -x "$daemon" >/dev/null; then
    echo "Stopping $daemon..."
    pkill -x "$daemon"
  fi
done

# LiteLLM Proxy
if pgrep -f "litellm" >/dev/null; then
  echo "Stopping existing litellm instances..."
  pkill -f "litellm"
  sleep 0.5
fi

if command -v litellm >/dev/null; then
  echo "Starting litellm..."

  # Resolve config path relative to script location
  SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  REPO_ROOT=$(dirname "$SCRIPT_DIR")
  CONFIG_PATH="$REPO_ROOT/modules/services/ai/litellm_config.yaml"

  if [ -f "$CONFIG_PATH" ]; then
    nohup litellm --config "$CONFIG_PATH" --port 4000 >/tmp/litellm.log 2>&1 &
    echo "LiteLLM started on port 4000"
  else
    echo "Warning: litellm_config.yaml not found at $CONFIG_PATH"
  fi
else
  echo "Warning: litellm not found in PATH"
fi
