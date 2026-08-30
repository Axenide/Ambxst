#!/usr/bin/env bash
# Script to list all monitors and their current brightness
# Outputs format: MonitorName:Brightness

# declare associative map to collect unique brightness values per monitor
declare -A BRIGHTNESS_MAP=()

# Helper: set a brightness value in the map, preferring non-zero and larger values
set_brightness() {
    local name="$1" value="$2"
    local prev
    prev="${BRIGHTNESS_MAP[$name]}"
    if [ -z "$prev" ]; then
        BRIGHTNESS_MAP[$name]="$value"
        return
    fi
    # prefer non-zero over zero
    if [ "$prev" -eq 0 ] && [ "$value" -gt 0 ]; then
        BRIGHTNESS_MAP[$name]="$value"
        return
    fi
    # prefer larger value if both non-zero
    if [ "$value" -gt "$prev" ]; then
        BRIGHTNESS_MAP[$name]="$value"
    fi
}

# Check for internal displays using brightnessctl (backlight devices only)
if command -v brightnessctl &> /dev/null; then
    DEVICES=$(brightnessctl -l 2>/dev/null | grep "backlight" | awk -F"'" '{print $2}')
    for device in $DEVICES; do
        CURRENT=$(brightnessctl -d "$device" g 2>/dev/null)
        MAX=$(brightnessctl -d "$device" m 2>/dev/null)
        if [ -n "$CURRENT" ] && [ -n "$MAX" ] && [ "$MAX" -gt 0 ]; then
            PERCENT=$(( CURRENT * 100 / MAX ))
            # Try to map backlight device to Hyprland monitor name
            # Most internal displays are eDP, so we use that as fallback
            MONITOR_NAME=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.name | contains("eDP")) | .name' | head -1)
            if [ -z "$MONITOR_NAME" ]; then
                MONITOR_NAME="eDP-1"
            fi
            set_brightness "$MONITOR_NAME" "$PERCENT"
        fi
    done
fi

# Check for external displays using ddcutil
if command -v ddcutil &> /dev/null; then
    CURRENT_BUS=""
    CURRENT_CONNECTOR=""
    
    while IFS= read -r line; do
        if [[ "$line" =~ I2C\ bus:.*-([0-9]+)$ ]]; then
            CURRENT_BUS="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ DRM\ connector:.*card[0-9]+-(.+)$ ]]; then
            CURRENT_CONNECTOR="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^$ ]] && [ -n "$CURRENT_BUS" ] && [ -n "$CURRENT_CONNECTOR" ]; then
            # End of display block, get brightness
            BRIGHTNESS=$(ddcutil -b "$CURRENT_BUS" getvcp 10 --brief 2>/dev/null | awk '{print $4}')
            if [ -n "$BRIGHTNESS" ]; then
                set_brightness "$CURRENT_CONNECTOR" "$BRIGHTNESS"
            fi
            CURRENT_BUS=""
            CURRENT_CONNECTOR=""
        fi
    done < <(ddcutil detect --brief 2>/dev/null; echo "")
fi

    # Output unique brightness entries
    for k in "${!BRIGHTNESS_MAP[@]}"; do
        echo "${k}:${BRIGHTNESS_MAP[$k]}"
    done
