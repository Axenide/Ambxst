#!/usr/bin/env bash
# Produce (and cache) a copy of a video wallpaper downscaled to the target
# monitor's resolution and capped at its refresh rate, to cut GPU usage on
# oversized (e.g. 4K/60) sources. Prints the path that should be played: the
# optimized file, or the original when optimization is unnecessary or fails.
set -u

SRC="${1:-}"
MONITOR="${2:-}"
OUTDIR="${3:-$HOME/.cache/ambxst/optimized_wallpapers}"

# On any problem, fall back to the original source so the wallpaper still shows.
fallback() { printf '%s\n' "$SRC"; exit 0; }

[ -n "$SRC" ] && [ -f "$SRC" ] || fallback
command -v ffmpeg >/dev/null 2>&1 || fallback
command -v ffprobe >/dev/null 2>&1 || fallback
command -v hyprctl >/dev/null 2>&1 || fallback
command -v python3 >/dev/null 2>&1 || fallback
mkdir -p "$OUTDIR" || fallback

# Target geometry (physical pixels) + refresh rate from the compositor.
GEO=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import sys, json
name = '$MONITOR'
try:
    mons = json.load(sys.stdin)
except Exception:
    print(''); sys.exit()
m = next((x for x in mons if x.get('name') == name), None) or (mons[0] if mons else None)
if not m:
    print(''); sys.exit()
print(int(m['width']), int(m['height']), max(1, round(float(m.get('refreshRate', 60)))))
" 2>/dev/null)
[ -n "$GEO" ] || fallback
read -r W H FPS <<< "$GEO"
[ -n "${W:-}" ] && [ -n "${H:-}" ] && [ -n "${FPS:-}" ] || fallback

# Source properties; skip re-encoding if it is already within the target.
SP=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate \
    -of csv=p=0 "$SRC" 2>/dev/null | python3 -c "
import sys
line = sys.stdin.read().strip()
try:
    parts = line.split(',')
    w, h, r = int(parts[0]), int(parts[1]), parts[2]
    n, d = (r.split('/') + ['1'])[:2]
    fps = float(n) / float(d) if float(d) else float(n)
    print(w, h, round(fps, 3))
except Exception:
    print('')
" 2>/dev/null)
if [ -n "$SP" ]; then
    read -r SW SH SFPS <<< "$SP"
    if awk "BEGIN{exit !($SW<=$W && $SH<=$H && $SFPS<=$FPS+0.5)}"; then
        fallback
    fi
fi

KEY=$(printf '%s' "$SRC" | md5sum | cut -d' ' -f1)
OUT="$OUTDIR/${KEY}_${W}x${H}_${FPS}.mp4"

# Reuse cached result when it is newer than the source.
if [ -f "$OUT" ] && [ "$OUT" -nt "$SRC" ]; then
    printf '%s\n' "$OUT"
    exit 0
fi

# Run at low CPU/IO priority so the one-time transcode doesn't hog the machine
# when a video wallpaper is set. `ionice` is optional (util-linux).
IONICE=""
command -v ionice >/dev/null 2>&1 && IONICE="ionice -c 3"

TMP="${OUT}.tmp.mp4"
if nice -n 19 $IONICE ffmpeg -y -nostdin -loglevel error -i "$SRC" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},fps=${FPS}" \
    -c:v libx264 -preset veryfast -crf 23 -an -pix_fmt yuv420p "$TMP" >/dev/null 2>&1; then
    mv -f "$TMP" "$OUT"
    printf '%s\n' "$OUT"
else
    rm -f "$TMP"
    fallback
fi
