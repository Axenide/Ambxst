#!/usr/bin/env python3
"""Camera device enumeration and in-use detection.

Lists cameras from /dev/video* (names via /sys/class/video4linux) and detects
whether any application currently holds a camera device open by scanning
/proc/*/fd for links into /dev/video*. Pure Python, no v4l2 tooling required.

Outputs JSON to stdout:
{"cameras": [{"name": ..., "node": ...}], "inUse": true, "users": ["pid:name"]}
"""

import json
import os
import re
import sys

VIDEO4LINUX = "/sys/class/video4linux"
DEV_PREFIX = "/dev/video"


def _camera_name(node):
    v4l_name = None
    try:
        if os.path.islink(node):
            real = os.path.realpath(node)
            if os.path.basename(real).startswith("video"):
                v4l_name = os.path.basename(real)
    except OSError:
        pass
    if v4l_name and os.path.isdir(os.path.join(VIDEO4LINUX, v4l_name)):
        name_file = os.path.join(VIDEO4LINUX, v4l_name, "name")
        try:
            with open(name_file, "r", errors="replace") as f:
                return f.read().strip()
        except OSError:
            return v4l_name
    return os.path.basename(node)


def _list_cameras():
    cameras = []
    try:
        for entry in sorted(os.listdir("/dev")):
            if not entry.startswith("video"):
                continue
            node = os.path.join("/dev", entry)
            if not os.path.exists(node):
                continue
            cameras.append({"name": _camera_name(node), "node": node})
    except OSError:
        pass
    return cameras


def _open_camera_users(cameras):
    """Return [pid] list of processes holding any camera device open."""
    if not cameras:
        return []
    dev_numbers = set()
    for cam in cameras:
        try:
            dev_numbers.add(os.stat(cam["node"]).st_rdev)
        except OSError:
            continue
    if not dev_numbers:
        return []

    users = []
    proc_dir = "/proc"
    try:
        entries = os.listdir(proc_dir)
    except OSError:
        return users

    for entry in entries:
        if not entry.isdigit():
            continue
        fd_dir = os.path.join(proc_dir, entry, "fd")
        try:
            fds = os.listdir(fd_dir)
        except OSError:
            continue
        for fd in fds:
            link = os.path.join(fd_dir, fd)
            try:
                st = os.stat(link)
            except OSError:
                continue
            if st.st_rdev in dev_numbers:
                users.append(entry)
                break
    return users


def _proc_name(pid):
    try:
        with open(os.path.join("/proc", pid, "comm"), "r") as f:
            return f.read().strip()
    except OSError:
        return "?"


def main():
    cameras = _list_cameras()
    users = _open_camera_users(cameras)
    result = {
        "cameras": cameras,
        "inUse": len(users) > 0,
        "users": [{"pid": pid, "name": _proc_name(pid)} for pid in users],
    }
    json.dump(result, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
