#!/usr/bin/env python3
import time
import sys
import os
import json
import subprocess
import re


class SystemMonitor:
    def __init__(self, disks=[]):
        self.prev_cpu_total = 0
        self.prev_cpu_idle = 0
        self.monitored_disks = disks
        self.cpu_model = self._detect_cpu_model()
        self.gpu_info = self._detect_gpus()
        self.disk_types = self._detect_disk_types(disks)
        # Cache filesystem paths discovered once at init instead of re-walking
        # /sys/class/hwmon and /sys/class/drm on every poll.
        self.cpu_temp_path = self._find_cpu_temp_path()
        self.amd_temp_paths = self._find_amd_temp_paths()
        # nvidia-smi is expensive (a full driver query); only re-run it every
        # N polls (20s at the default 2s interval) and serve the cached values
        # in between. The cheap /proc power-state check still runs every poll.
        self._nvidia_poll_counter = 0
        self._nvidia_poll_every = 10
        self._nvidia_cache = {}

    def _find_cpu_temp_path(self):
        base = "/sys/class/hwmon"
        if not os.path.exists(base):
            return None
        for hwmon in os.listdir(base):
            path = os.path.join(base, hwmon)
            try:
                with open(os.path.join(path, "name"), "r") as f:
                    name = f.read().strip()
                if name in [
                    "coretemp",
                    "k10temp",
                    "zenpower",
                    "cpu_thermal",
                    "x86_pkg_temp",
                    "amd_energy",
                ]:
                    for item in os.listdir(path):
                        if item.endswith("_input") and item.startswith("temp"):
                            candidate = os.path.join(path, item)
                            try:
                                with open(candidate, "r") as f:
                                    val = int(f.read().strip())
                                if 10000 < val < 120000:
                                    return candidate
                            except Exception:
                                continue
            except Exception:
                continue
        return None

    def _find_amd_temp_paths(self):
        paths = {}
        for gpu in self.gpu_info:
            if gpu["vendor"] != "amd":
                continue
            card = gpu["card"]
            try:
                hwmon_base = f"/sys/class/drm/{card}/device/hwmon"
                if os.path.exists(hwmon_base):
                    hwmon_dir = os.listdir(hwmon_base)[0]
                    paths[card] = os.path.join(
                        hwmon_base, hwmon_dir, "temp1_input"
                    )
            except Exception:
                pass
        return paths

    def _detect_cpu_model(self):
        try:
            with open("/proc/cpuinfo", "r") as f:
                for line in f:
                    if "model name" in line:
                        model = line.split(":", 1)[1].strip()
                        model = re.sub(
                            r" (?:CPU|FPU|APU|Processor|Dual-Core|Quad-Core|Six-Core|Eight-Core|Ten-Core|[0-9]+-Core)$",
                            "",
                            model,
                            flags=re.I,
                        )
                        model = re.sub(r" w/ Radeon.*$", "", model)
                        model = re.sub(r" with Radeon.*$", "", model)
                        model = re.sub(r" @.*$", "", model)
                        return " ".join(model.split())
        except Exception:
            pass
        return "Unknown CPU"

    def _detect_gpus(self):
        gpus = []
        nvidia_base = "/proc/driver/nvidia/gpus"
        if os.path.exists(nvidia_base):
            for entry in os.listdir(nvidia_base):
                path = os.path.join(nvidia_base, entry, "information")
                if os.path.exists(path):
                    gpu = {
                        "vendor": "nvidia",
                        "name": "NVIDIA GPU",
                        "pci_id": entry,
                        "power_path": "",
                    }
                    try:
                        with open(path, "r") as f:
                            for line in f:
                                if line.startswith("Model:"):
                                    gpu["name"] = line.split(":", 1)[1].strip()
                    except Exception:
                        pass
                    pci_path = f"/sys/bus/pci/devices/{entry}/power/runtime_status"
                    if os.path.exists(pci_path):
                        gpu["power_path"] = pci_path
                    gpus.append(gpu)

        drm_base = "/sys/class/drm"
        if os.path.exists(drm_base):
            for card in os.listdir(drm_base):
                if not card.startswith("card") or "-" in card:
                    continue

                vendor_path = f"{drm_base}/{card}/device/vendor"
                if not os.path.exists(vendor_path):
                    continue

                try:
                    with open(vendor_path, "r") as f:
                        vendor_id = f.read().strip().lower()

                    if vendor_id == "0x1002":
                        gpus.append(
                            {
                                "vendor": "amd",
                                "name": f"AMD GPU {card[-1]}",
                                "card": card,
                            }
                        )
                    elif vendor_id == "0x8086":
                        gpus.append(
                            {
                                "vendor": "intel",
                                "name": f"Intel GPU {card[-1]}",
                                "card": card,
                            }
                        )
                except Exception:
                    pass
        return gpus

    def _detect_disk_types(self, disks):
        types = {}
        for mount in disks:
            types[mount] = "unknown"
            try:
                with open("/proc/mounts", "r") as f:
                    for line in f:
                        parts = line.split()
                        if parts[1] == mount:
                            dev = parts[0]
                            if dev.startswith("/dev/"):
                                base = re.sub(
                                    r"p?[0-9]*$", "", dev.replace("/dev/", "")
                                )
                                rota_path = f"/sys/block/{base}/queue/rotational"
                                if os.path.exists(rota_path):
                                    with open(rota_path, "r") as f2:
                                        types[mount] = (
                                            "hdd" if f2.read().strip() == "1" else "ssd"
                                        )
                            break
            except Exception:
                pass
        return types

    def get_cpu(self):
        try:
            with open("/proc/stat", "r") as f:
                line = f.readline()
                if not line.startswith("cpu "):
                    return 0.0
                values = [int(x) for x in line.split()[1:]]
                idle = values[3] + values[4]
                total = sum(values)
                diff_idle = idle - self.prev_cpu_idle
                diff_total = total - self.prev_cpu_total
                self.prev_cpu_total = total
                self.prev_cpu_idle = idle
                if diff_total == 0:
                    return 0.0
                return max(
                    0.0, min(100.0, ((diff_total - diff_idle) * 100.0) / diff_total)
                )
        except Exception:
            return 0.0

    def get_cpu_temp(self):
        if self.cpu_temp_path is None:
            return -1
        try:
            with open(self.cpu_temp_path, "r") as f:
                val = int(f.read().strip())
                if 10000 < val < 120000:
                    return val // 1000
        except Exception:
            pass
        return -1

    def get_mem(self):
        try:
            mem_total = 0
            mem_available = 0
            with open("/proc/meminfo", "r") as f:
                for line in f:
                    if line.startswith("MemTotal:"):
                        mem_total = int(line.split()[1])
                    elif line.startswith("MemAvailable:"):
                        mem_available = int(line.split()[1])
                    if mem_total > 0 and mem_available > 0:
                        break
            if mem_total == 0:
                return 0.0, 0, 0, 0
            mem_used = mem_total - mem_available
            return (mem_used * 100.0) / mem_total, mem_total, mem_used, mem_available
        except Exception:
            return 0.0, 0, 0, 0

    def get_disk_usage(self, disks):
        usage_map = {}
        for mount in disks:
            try:
                st = os.statvfs(mount)
                total = st.f_blocks * st.f_frsize
                if total > 0:
                    used = total - (st.f_bavail * st.f_frsize)
                    usage_map[mount] = (used / total) * 100.0
                else:
                    usage_map[mount] = 0.0
            except Exception:
                usage_map[mount] = 0.0
        return usage_map

    def get_gpu_stats(self):
        usages = []
        temps = []
        refresh_nvidia = (
            self._nvidia_poll_counter % self._nvidia_poll_every == 0
        )
        self._nvidia_poll_counter += 1
        for gpu in self.gpu_info:
            u, t = 0.0, -1
            if gpu["vendor"] == "nvidia":
                is_active = True
                if gpu.get("power_path"):
                    try:
                        with open(gpu["power_path"], "r") as f:
                            is_active = f.read().strip() == "active"
                    except Exception:
                        pass

                if is_active:
                    if refresh_nvidia:
                        try:
                            out = (
                                subprocess.check_output(
                                    [
                                        "nvidia-smi",
                                        "-i",
                                        gpu["pci_id"],
                                        "--query-gpu=utilization.gpu,temperature.gpu",
                                        "--format=csv,noheader,nounits",
                                    ]
                                )
                                .decode("utf-8")
                                .strip()
                            )
                            parts = out.split(",")
                            if len(parts) >= 2:
                                self._nvidia_cache[gpu["pci_id"]] = (
                                    float(parts[0]),
                                    int(parts[1]),
                                )
                        except Exception:
                            pass
                else:
                    self._nvidia_cache[gpu["pci_id"]] = (0.0, -1)
                cached = self._nvidia_cache.get(gpu["pci_id"])
                if cached is not None:
                    u, t = cached
            elif gpu["vendor"] == "amd":
                card = gpu["card"]
                try:
                    with open(
                        f"/sys/class/drm/{card}/device/gpu_busy_percent", "r"
                    ) as f:
                        u = float(f.read().strip())
                except Exception:
                    pass
                temp_path = self.amd_temp_paths.get(card)
                if temp_path:
                    try:
                        with open(temp_path, "r") as f:
                            t = int(f.read().strip()) // 1000
                    except Exception:
                        pass
            elif gpu["vendor"] == "intel":
                pass
            usages.append(u)
            temps.append(t)
        return usages, temps


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="System resource monitor for Ambxst[+]")
    parser.add_argument("interval_ms", nargs="?", type=int, default=2000,
                        help="Polling interval in milliseconds (default: 2000)")
    parser.add_argument("disks", nargs="*", default=["/"],
                        help="Disk mount points to monitor (default: /)")
    args = parser.parse_args()

    interval_ms = args.interval_ms
    disks = args.disks if args.disks else ["/"]

    monitor = SystemMonitor(disks)
    interval_sec = max(0.1, interval_ms / 1000.0)

    print(
        json.dumps(
            {
                "static": {
                    "cpu_model": monitor.cpu_model,
                    "gpu_names": [g["name"] for g in monitor.gpu_info],
                    "gpu_vendors": [g["vendor"] for g in monitor.gpu_info],
                    "disk_types": monitor.disk_types,
                    "gpu_count": len(monitor.gpu_info),
                }
            }
        ),
        flush=True,
    )

    try:
        while True:
            cpu_usage = monitor.get_cpu()
            cpu_temp = monitor.get_cpu_temp()
            ram_usage, ram_total, ram_used, ram_avail = monitor.get_mem()
            disk_usage = monitor.get_disk_usage(disks)
            gpu_usages, gpu_temps = monitor.get_gpu_stats()

            print(
                json.dumps(
                    {
                        "cpu": {"usage": cpu_usage, "temp": cpu_temp},
                        "ram": {
                            "usage": ram_usage,
                            "total": ram_total,
                            "used": ram_used,
                            "available": ram_avail,
                        },
                        "disk": {"usage": disk_usage},
                        "gpu": {
                            "detected": len(monitor.gpu_info) > 0,
                            "count": len(monitor.gpu_info),
                            "usages": gpu_usages,
                            "temps": gpu_temps,
                        },
                    }
                ),
                flush=True,
            )
            time.sleep(interval_sec)
    except KeyboardInterrupt:
        sys.exit(0)
