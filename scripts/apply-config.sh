#!/bin/bash
# Apply Ambxst compositor config to Hyprland
# Called from the shell when user saves compositor settings

# 1. Sync to hyprland.conf and hyprland.lua
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
python3 "$SCRIPT_DIR/sync-hyprland-conf.py"

# 2. Read compositor.json and apply via axctl
CONFIG="$HOME/.config/ambxst/config/compositor.json"
if [ -f "$CONFIG" ]; then
    python3 -c "
import json, subprocess
with open('$CONFIG') as f:
    cfg = json.load(f)

# Known compositor keywords to apply
kw_map = {
    'borderSize': 'general:border_size', 'gapsIn': 'general:gaps_in',
    'gapsOut': 'general:gaps_out', 'rounding': 'decoration:rounding',
    'shadowEnabled': 'decoration:shadow:enabled',
    'shadowRange': 'decoration:shadow:range',
    'shadowRenderPower': 'decoration:shadow:render_power',
    'blurEnabled': 'decoration:blur:enabled',
    'blurSize': 'decoration:blur:size',
    'blurPasses': 'decoration:blur:passes',
    'activeOpacity': 'decoration:active_opacity',
    'inactiveOpacity': 'decoration:inactive_opacity',
    'fullscreenOpacity': 'decoration:fullscreen_opacity',
    'dimInactive': 'decoration:dim_inactive',
    'dimStrength': 'decoration:dim_strength',
    'kbLayout': 'input:kb_layout',
    'repeatRate': 'input:repeat_rate',
    'repeatDelay': 'input:repeat_delay',
    'mouseSensitivity': 'input:sensitivity',
    'followMouse': 'input:follow_mouse',
    'xwaylandEnabled': 'xwayland:enabled',
    'xwaylandForceZeroScaling': 'xwayland:force_zero_scaling',
    'disableAutoreload': 'misc:disable_autoreload',
}

def fmt(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    return str(v)

parts = []
for ck, kw in kw_map.items():
    if ck in cfg:
        parts.append(f'keyword {kw} {fmt(cfg[ck])}')

if parts:
    batch = ' ; '.join(parts)
    r = subprocess.run(['axctl', 'config', 'raw-batch', batch], capture_output=True, text=True)
    print(f'axctl: {r.stdout or r.stderr}')
"
fi
