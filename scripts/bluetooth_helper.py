#!/usr/bin/env python3
"""
Bluetooth helper for NothingLess.
Uses PTY-based bluetoothctl for reliable device discovery.

Commands: power on|off|status / scan find [secs] / devices / info / connect / disconnect / pair / trust / remove
"""

import sys, json, subprocess, os, pty, time, re, select, threading


def run_btctl(*args, timeout=10):
    cmd = ["bluetoothctl", "--"] + list(args)
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip(), r.stderr.strip(), r.returncode
    except subprocess.TimeoutExpired:
        return "", "timeout", 124
    except FileNotFoundError:
        return "", "bluetoothctl not found", 127


def parse_devices(text):
    devs = []
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith("Device "):
            p = line.split(" ", 2)
            if len(p) >= 3:
                devs.append({"address": p[1], "name": p[2], "alias": p[2],
                             "paired": True, "connected": False, "trusted": False,
                             "icon": "bluetooth", "rssi": 0})
    return devs


def parse_info(text, addr):
    info = {"address": addr, "name": "Unknown", "alias": "Unknown",
            "paired": False, "connected": False, "trusted": False,
            "icon": "bluetooth", "rssi": 0}
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith("Name: "): info["name"] = line[6:]
        elif line.startswith("Alias: "): info["alias"] = line[7:]
        elif line.startswith("Paired: "): info["paired"] = "yes" in line
        elif line.startswith("Connected: "): info["connected"] = "yes" in line
        elif line.startswith("Trusted: "): info["trusted"] = "yes" in line
        elif line.startswith("Icon: "): info["icon"] = line[6:]
    return info


def cmd_power(action):
    if action == "status":
        out, _, _ = run_btctl("show")
        print(json.dumps({"powered": "Powered: yes" in out}))
    elif action in ("on", "off"):
        run_btctl("power", action)
        out, _, _ = run_btctl("show")
        print(json.dumps({"powered": "Powered: yes" in out}))


def cmd_devices():
    out, _, _ = run_btctl("devices")
    devs = parse_devices(out)
    out2, _, _ = run_btctl("devices", "Connected")
    for line in out2.split("\n"):
        if line.strip().startswith("Device "):
            parts = line.strip().split(" ", 2)
            if len(parts) >= 2:
                for d in devs:
                    if d["address"] == parts[1]:
                        d["connected"] = True
    print(json.dumps(devs))


def cmd_info(addr):
    out, _, _ = run_btctl("info", addr)
    print(json.dumps(parse_info(out, addr)))


def cmd_connect(addr):
    out, err, rc = run_btctl("connect", addr)
    print(json.dumps({"connected": rc == 0, "error": err or None}))


def cmd_disconnect(addr):
    out, err, rc = run_btctl("disconnect", addr)
    print(json.dumps({"connected": False, "error": err or None}))


def cmd_pair(addr):
    out, err, rc = run_btctl("pair", addr)
    print(json.dumps({"paired": rc == 0, "error": err or None}))


def cmd_trust(addr):
    out, err, rc = run_btctl("trust", addr)
    print(json.dumps({"trusted": rc == 0, "error": err or None}))


def cmd_remove(addr):
    out, err, rc = run_btctl("remove", addr)
    print(json.dumps({"removed": rc == 0, "error": err or None}))


# ── PTY-based scan: spawns bluetoothctl with pseudo-terminal ──
def cmd_scan_find(duration=8):
    try: duration = int(duration)
    except: duration = 8
    duration = max(3, min(duration, 30))

    discovered = {}
    new_re = re.compile(r"\[NEW\]\s+Device\s+([0-9A-Fa-f:]{17})\s+(.*)")

    try:
        master_fd, slave_fd = pty.openpty()
        proc = subprocess.Popen(
            ["bluetoothctl"],
            stdin=slave_fd, stdout=slave_fd, stderr=slave_fd,
            close_fds=True, preexec_fn=os.setsid
        )
        os.close(slave_fd)

        time.sleep(0.3)
        os.write(master_fd, b"power on\n")
        time.sleep(0.2)
        os.write(master_fd, b"scan on\n")

        deadline = time.time() + duration
        buf = b""
        while time.time() < deadline:
            r, _, _ = select.select([master_fd], [], [], 0.5)
            if r:
                try:
                    data = os.read(master_fd, 4096)
                    if not data: break
                    buf += data
                    lines = buf.split(b"\n")
                    buf = lines.pop()
                    for line in lines:
                        m = new_re.match(line.decode(errors="replace").strip())
                        if m:
                            discovered[m.group(1).upper()] = {
                                "address": m.group(1).upper(),
                                "name": m.group(2).strip()
                            }
                except OSError: break

        os.write(master_fd, b"scan off\nquit\n")
        time.sleep(0.5)
        try: os.close(master_fd)
        except: pass
        try: proc.wait(timeout=3)
        except: proc.kill()
    except Exception as e:
        print(json.dumps({"error": str(e), "devices": []}))
        return

    # Merge known devices
    out, _, _ = run_btctl("devices")
    for line in out.split("\n"):
        if line.strip().startswith("Device "):
            parts = line.strip().split(" ", 2)
            if len(parts) >= 3 and parts[1] not in discovered:
                discovered[parts[1]] = {"address": parts[1], "name": parts[2],
                                         "paired": True}
    # Mark connected
    out2, _, _ = run_btctl("devices", "Connected")
    for line in out2.split("\n"):
        if line.strip().startswith("Device "):
            parts = line.strip().split(" ", 2)
            if len(parts) >= 2 and parts[1] in discovered:
                discovered[parts[1]]["connected"] = True

    print(json.dumps(list(discovered.values())))


def cmd_scan(action="find"):
    if action == "on":
        run_btctl("scan", "on")
        print(json.dumps({"scanning": True}))
    elif action == "off":
        run_btctl("scan", "off")
        print(json.dumps({"scanning": False}))
    else:
        cmd_scan_find(action)


def main():
    if len(sys.argv) < 2:
        print("Usage: bluetooth_helper.py <command> [args...]", file=sys.stderr)
        sys.exit(1)
    cmd, args = sys.argv[1], sys.argv[2:]
    try:
        {"power": lambda: cmd_power(args[0] if args else "status"),
         "scan": lambda: cmd_scan(args[0] if args else "find"),
         "devices": cmd_devices, "info": lambda: cmd_info(args[0] if args else ""),
         "connect": lambda: cmd_connect(args[0] if args else ""),
         "disconnect": lambda: cmd_disconnect(args[0] if args else ""),
         "pair": lambda: cmd_pair(args[0] if args else ""),
         "trust": lambda: cmd_trust(args[0] if args else ""),
         "remove": lambda: cmd_remove(args[0] if args else ""),
        }.get(cmd, lambda: print(json.dumps({"error": f"Unknown: {cmd}"})))()
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
