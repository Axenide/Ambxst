#!/usr/bin/env python3
"""
Ambxst Smart Resize
Resize una ventana desde el borde más cercano al cursor,
manteniendo la orilla opuesta anclada. No mueve la ventana.

Uso: ambxst resize [right|left|top|bottom|corner]
  Si no se especifica borde, detecta el más cercano al cursor
"""
import json, os, subprocess, sys, time, math

def hyprctl(cmd):
    try:
        return subprocess.run(
            ["hyprctl"] + cmd.split(),
            capture_output=True, text=True, timeout=1
        ).stdout.strip()
    except: return ""

def hyprctl_j(cmd):
    try:
        out = subprocess.run(
            ["hyprctl"] + cmd.split(),
            capture_output=True, text=True, timeout=1
        ).stdout.strip()
        return json.loads(out) if out else {}
    except: return {}

def dispatch(cmd):
    subprocess.run(["hyprctl", "dispatch"] + cmd.split(),
                   capture_output=True, timeout=1)

def get_active_window():
    return hyprctl_j("activewindow -j")

def get_cursor():
    out = hyprctl("cursorpos")
    if out:
        parts = out.split(",")
        return (int(parts[0]), int(parts[1]))
    return (0, 0)

def get_edges(win):
    """Return (left, right, top, bottom, center_x, center_y)"""
    if not win or not win.get("at") or not win.get("size"):
        return None
    at = win["at"]
    size = win["size"]
    x, y = at[0], at[1]
    w, h = size[0], size[1]
    return {
        "left": x, "right": x + w,
        "top": y, "bottom": y + h,
        "center_x": x + w / 2,
        "center_y": y + h / 2,
        "w": w, "h": h
    }

def nearest_edge(edges, cursor):
    """Determina el borde/corner más cercano al cursor"""
    cx, cy = cursor
    e = edges

    dist_left = abs(cx - e["left"])
    dist_right = abs(cx - e["right"])
    dist_top = abs(cy - e["top"])
    dist_bottom = abs(cy - e["bottom"])

    # Corner threshold: if within 30px of a corner, use corner anchor
    corner_threshold = 30
    near_topleft = dist_left < corner_threshold and dist_top < corner_threshold
    near_topright = dist_right < corner_threshold and dist_top < corner_threshold
    near_bottomleft = dist_left < corner_threshold and dist_bottom < corner_threshold
    near_bottomright = dist_right < corner_threshold and dist_bottom < corner_threshold

    if near_topleft: return "top-left"
    if near_topright: return "top-right"
    if near_bottomleft: return "bottom-left"
    if near_bottomright: return "bottom-right"

    # Edge detection
    min_dist = min(dist_left, dist_right, dist_top, dist_bottom)

    if min_dist == dist_left: return "left"
    if min_dist == dist_right: return "right"
    if min_dist == dist_top: return "top"
    return "bottom"

def resize_from_edge(edge, dx, dy):
    """
    Resize manteniendo la orilla opuesta anclada.
    Usa movewindow + resizeactive para compensar.
    """
    if edge == "right":
        # Anchor: left, resize right
        dispatch(f"resizeactive {dx} {dy}")
    elif edge == "left":
        # Anchor: right, resize left
        # Move window right (or left), then compensate with resize
        dispatch(f"movewindow {dx} 0")
        dispatch(f"resizeactive {-dx} 0")
        if dy != 0:
            dispatch(f"resizeactive 0 {dy}")
    elif edge == "bottom":
        # Anchor: top, resize bottom
        dispatch(f"resizeactive {dx} {dy}")
    elif edge == "top":
        # Anchor: bottom, resize top
        dispatch(f"movewindow 0 {dy}")
        dispatch(f"resizeactive 0 {-dy}")
        if dx != 0:
            dispatch(f"resizeactive {dx} 0")
    elif edge == "top-left":
        # Anchor: bottom-right
        dispatch(f"movewindow {dx} {dy}")
        dispatch(f"resizeactive {-dx} {-dy}")
    elif edge == "top-right":
        # Anchor: bottom-left
        dispatch(f"movewindow 0 {dy}")
        dispatch(f"resizeactive {dx} {-dy}")
    elif edge == "bottom-left":
        # Anchor: top-right
        dispatch(f"movewindow {dx} 0")
        dispatch(f"resizeactive {-dx} {dy}")
    elif edge == "bottom-right":
        # Anchor: top-left
        dispatch(f"resizeactive {dx} {dy}")


def interactive_resize():
    """Interactive resize: follow cursor movement"""
    # Get initial state
    win = get_active_window()
    if not win or not win.get("at") or not win.get("size"):
        print("No active window")
        return

    edges = get_edges(win)
    if not edges:
        return

    cursor = get_cursor()
    anchor_edge = nearest_edge(edges, cursor)
    print(f"Anchor: {anchor_edge}")

    # Initial cursor position for tracking deltas
    prev_cx, prev_cy = cursor
    
    # Track mouse movement for a short time
    # We poll cursor position and apply resize
    start = time.time()
    while time.time() - start < 30:  # 30 second timeout
        current = get_cursor()
        if current == (0, 0):
            continue
            
        cx, cy = current
        dx = cx - prev_cx
        dy = cy - prev_cy

        if dx != 0 or dy != 0:
            # Invert delta if anchoring from top/left
            if anchor_edge in ("left", "top-left", "bottom-left"):
                dx = -dx
            if anchor_edge in ("top", "top-left", "top-right"):
                dy = -dy
                
            resize_from_edge(anchor_edge, dx, dy)
            prev_cx, prev_cy = cx, cy

        time.sleep(0.016)  # ~60fps polling
        # Check if a mouse button is still pressed
        # We can't easily check this, so we check if cursor has moved recently
        if abs(dx) > 0 or abs(dy) > 0:
            start = time.time()  # Reset timeout on movement
        

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "start":
        interactive_resize()
    elif len(sys.argv) > 1:
        edge = sys.argv[1]
        dx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        dy = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        resize_from_edge(edge, dx, dy)
    else:
        interactive_resize()
