#!/usr/bin/env bash

# Function to wait for a TCP port to become active
wait_for_port() {
    local port=$1
    local timeout=10
    echo "Waiting for port $port to become active..."
    for ((i=0; i<timeout*2; i++)); do
        if ss -tln | grep -q ":$port"; then
            echo "Port $port is active."
            return 0
        fi
        sleep 0.5
    done
    echo "Timeout: Port $port did not become active within $timeout seconds."
    return 1
}

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
		wait_for_port 4000
	else
		echo "Warning: litellm_config.yaml not found at $CONFIG_PATH"
	fi
else
	echo "Warning: litellm not found in PATH"
fi

# EasyEffects
if command -v easyeffects >/dev/null; then
	echo "Starting EasyEffects..."
	pkill -x easyeffects 2>/dev/null || true
	nohup easyeffects --gapplication-service >/dev/null 2>&1 &
	sleep 1 # Give easyeffects a moment to initialize
else
	echo "Warning: easyeffects not found in PATH"
fi
