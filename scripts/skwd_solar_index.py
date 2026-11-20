#!/usr/bin/env python3
"""Sorts every wallpaper into a time of day for "Match Time of Day".

Writes ~/.cache/ambxst/wallpaper_solar_cache.json as {"relative/path.ext": period},
period one of morning | afternoon | sunset | night, from each picture's average
brightness and warmth. Videos and GIFs are judged by the thumbnail Ambxst already
made for them (~/.cache/ambxst/thumbnails/<relative path>.jpg). Needs ImageMagick.
Results are kept per file modification time, so a re-index only reads new files.
"""
import json
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache/ambxst")
OUT = os.path.join(CACHE, "wallpaper_solar_cache.json")
STAMPS = os.path.join(CACHE, "wallpaper_solar_cache.mtimes.json")
IMAGES = {"jpg", "jpeg", "png", "webp", "bmp", "tif", "tiff"}
MOVING = {"gif", "mp4", "webm", "mov", "avi", "mkv"}


def wallpaper_dir():
    try:
        with open(os.path.join(CACHE, "wallpapers.json")) as f:
            path = json.load(f).get("wallPath") or ""
            if path:
                return os.path.expanduser(path)
    except (OSError, ValueError):
        pass
    return os.path.join(HOME, "Pictures/Wallpapers")


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def average_rgb(path):
    """Mean colour as three 0..1 floats, or None."""
    try:
        out = subprocess.run(
            ["magick", path + "[0]", "-resize", "64x64!", "-colorspace", "sRGB",
             "-format", "%[fx:mean.r] %[fx:mean.g] %[fx:mean.b]", "info:"],
            capture_output=True, text=True, timeout=30, check=True).stdout.split()
        return tuple(float(v) for v in out[:3])
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def period(rgb):
    r, g, b = rgb
    light = 0.2126 * r + 0.7152 * g + 0.0722 * b
    warmth = r - b
    if light < 0.24:
        return "night"
    if warmth > 0.07 and light < 0.6:
        return "sunset"
    if light > 0.55 and warmth <= 0.04:
        return "morning"
    return "afternoon"


def main():
    base = wallpaper_dir()
    if not os.path.isdir(base):
        print(f"no wallpaper folder at {base}", file=sys.stderr)
        return 1
    old = load(OUT)
    stamps = load(STAMPS)
    jobs = []
    for root, _dirs, files in os.walk(base):
        for name in files:
            ext = name.rsplit(".", 1)[-1].lower() if "." in name else ""
            if ext not in IMAGES and ext not in MOVING:
                continue
            full = os.path.join(root, name)
            rel = os.path.relpath(full, base)
            mtime = os.path.getmtime(full)
            if rel in old and stamps.get(rel) == mtime:
                continue
            source = full if ext in IMAGES else os.path.join(CACHE, "thumbnails", rel + ".jpg")
            if os.path.exists(source):
                jobs.append((rel, mtime, source))

    known = {rel for rel in old if os.path.exists(os.path.join(base, rel))}
    result = {rel: old[rel] for rel in known}
    stamps = {rel: stamps[rel] for rel in known if rel in stamps}

    def judge(job):
        rel, mtime, source = job
        rgb = average_rgb(source)
        return rel, mtime, (period(rgb) if rgb else None)

    with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) // 2)) as pool:
        for rel, mtime, when in pool.map(judge, jobs):
            if when:
                result[rel] = when
                stamps[rel] = mtime

    os.makedirs(CACHE, exist_ok=True)
    for path, data in ((OUT, result), (STAMPS, stamps)):
        tmp = path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(data, f, indent=1, sort_keys=True)
        os.replace(tmp, path)
    counts = {p: list(result.values()).count(p) for p in ("morning", "afternoon", "sunset", "night")}
    print(f"indexed {len(jobs)} new, {len(result)} total: {counts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
