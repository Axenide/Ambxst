#!/usr/bin/env python3
"""
Metrics overlay provider for NothingLess.
Pure Python 3, no external dependencies.

Monitors:
  - CPU temp via sysfs hwmon
  - CPU power via RAPL energy counters
  - GPU temp/power/usage via sysfs or nvidia-smi
  - FPS via built-in libambfps.so (LD_PRELOAD) - primary
  - FPS via MangoHud CSV, gsr-fps, lsfgvk - optional fallbacks

Usage:
  ./fps_monitor.py                # continuous output
"""
import os
import json
import sys
import time
import struct
import re

# ═══════════════════════════════════════════════════════════════════
#  Hardware monitoring helpers
# ═══════════════════════════════════════════════════════════════════

def _read_sysfs(path, default=None):
    try:
        with open(path, 'r') as f:
            return f.read().strip()
    except (FileNotFoundError, PermissionError, OSError):
        return default

def _get_cpu_temp():
    hwmon_base = '/sys/class/hwmon'
    if not os.path.isdir(hwmon_base):
        return -1
    for hwmon in sorted(os.listdir(hwmon_base)):
        path = os.path.join(hwmon_base, hwmon)
        try:
            name = _read_sysfs(os.path.join(path, 'name'))
            if name in ('coretemp', 'k10temp', 'zenpower', 'cpu_thermal',
                        'x86_pkg_temp', 'amd_energy'):
                for item in sorted(os.listdir(path)):
                    if item.endswith('_input') and item.startswith('temp'):
                        raw = _read_sysfs(os.path.join(path, item))
                        if raw:
                            val = int(raw)
                            if 10000 < val < 120000:
                                return val // 1000
        except OSError:
            continue
    return -1

# ── CPU power from RAPL (rate of change, not cumulative) ──
_rapl_cache = {'uj': None, 'time': 0.0}
_rapl_last_watts = 0.0

def _get_cpu_power():
    """Read CPU package power from RAPL.
    Calculates power from the rate of energy change over time.
    Returns last valid reading between samples to avoid flicker.
    Needs udev rule: see config/99-rapl-permissions.rules
    """
    global _rapl_cache, _rapl_last_watts
    try:
        p = '/sys/class/powercap/intel-rapl:0/energy_uj'
        if not os.path.exists(p):
            return 0.0
        with open(p) as f:
            v = f.read().strip()
        if not v or not v.isdigit():
            return 0.0

        uj_now = int(v)
        t_now = time.monotonic()

        prev_uj = _rapl_cache['uj']
        prev_t = _rapl_cache['time']

        if prev_uj is not None:
            dt = t_now - prev_t
            if dt >= 0.8:
                diff = uj_now - prev_uj
                if diff > 0:
                    watts = (diff / 1_000_000.0) / dt
                    if 0 < watts < 500:
                        _rapl_last_watts = round(watts, 1)
                    _rapl_cache['uj'] = uj_now
                    _rapl_cache['time'] = t_now

        if prev_uj is None:
            _rapl_cache['uj'] = uj_now
            _rapl_cache['time'] = t_now

        return _rapl_last_watts
    except (OSError, ValueError, PermissionError):
        return 0.0

def _get_gpu_stats():
    usages, temps, powers = [], [], []
    if os.path.exists('/proc/driver/nvidia/gpus'):
        try:
            out = os.popen(
                'nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,power.draw'
                ' --format=csv,noheader,nounits 2>/dev/null'
            ).read().strip()
            if out:
                parts = out.split(',')
                if len(parts) >= 3:
                    usages.append(float(parts[0]))
                    temps.append(int(parts[1]))
                    powers.append(float(parts[2]))
                elif len(parts) >= 2:
                    usages.append(float(parts[0]))
                    temps.append(int(parts[1]))
                    powers.append(0.0)
        except (ValueError, OSError):
            pass
        if usages:
            return usages, temps, powers

    drm_base = '/sys/class/drm'
    if os.path.exists(drm_base):
        for card in sorted(os.listdir(drm_base)):
            if not card.startswith('card') or '-' in card:
                continue
            vendor = _read_sysfs(f'{drm_base}/{card}/device/vendor')
            if vendor == '0x1002':
                usage = 0.0
                gpu_busy = _read_sysfs(f'{drm_base}/{card}/device/gpu_busy_percent')
                if gpu_busy:
                    try: usage = float(gpu_busy)
                    except ValueError: pass
                temp = -1
                hwmon_base = f'{drm_base}/{card}/device/hwmon'
                if os.path.isdir(hwmon_base):
                    dirs = os.listdir(hwmon_base)
                    if dirs:
                        t = _read_sysfs(f'{hwmon_base}/{dirs[0]}/temp1_input')
                        if t:
                            try: temp = int(t) // 1000
                            except ValueError: pass
                power = 0.0
                if os.path.isdir(hwmon_base):
                    dirs = os.listdir(hwmon_base)
                    if dirs:
                        for pname in ('power1_average', 'power2_average'):
                            p = _read_sysfs(f'{hwmon_base}/{dirs[0]}/{pname}')
                            if p:
                                try: power = int(p) / 1000000.0; break
                                except ValueError: pass
                usages.append(usage); temps.append(temp); powers.append(power)
                break
    if not usages:
        usages.append(0.0); temps.append(-1); powers.append(0.0)
    return usages, temps, powers

# ═══════════════════════════════════════════════════════════════════
#  FPS - Primary: Built-in libambfps.so via LD_PRELOAD (shm)
# ═══════════════════════════════════════════════════════════════════
# This is the recommended way: nothingless-fps ./game sets LD_PRELOAD
# and the library writes actual app FPS to /dev/shm/nothingless_fps.
# No external tools needed - ships with NothingLess.

SHM_FPS_FILE = '/dev/shm/nothingless_fps'

def _get_fps_shm():
    """Primary FPS source: built-in libambfps.so LD_PRELOAD library.
    
    Reads from /dev/shm/nothingless_fps which contains:
      fps=<value>
      pid=<process-id>
      frames=<count>
      source=nothingless-preload
    
    Checks /proc/<pid> to detect if the game is still running.
    Returns None if no data or process is gone.
    """
    if not os.path.exists(SHM_FPS_FILE):
        return None
    try:
        age = time.time() - os.path.getmtime(SHM_FPS_FILE)
        if age > 5:
            return None  # Stale: game probably exited

        with open(SHM_FPS_FILE, 'r') as f:
            data = {}
            for line in f:
                if '=' in line:
                    k, v = line.strip().split('=', 1)
                    data[k] = v

        fps_val = data.get('fps', '0.0')
        fps = float(fps_val)

        # Verify the process is still alive
        pid_str = data.get('pid', '')
        if pid_str:
            try:
                pid = int(pid_str)
                if not os.path.isdir(f'/proc/{pid}'):
                    return None  # Process exited
            except ValueError:
                pass

        if fps > 0:
            return fps
        return 0.0
    except (OSError, ValueError, IndexError):
        return None

# ═══════════════════════════════════════════════════════════════════
#  FPS - Optional fallbacks
# ═══════════════════════════════════════════════════════════════════
# These require external tools but are kept as optional alternatives.

LSFGVK_FILE = '/dev/shm/lsfgvk-fps'

def _get_fps_lsfgvk():
    """Optional: Read post-LSFG FPS from modified lsfg-vk layer.
    Only used as fallback when libambfps.so is not active.
    """
    if not os.path.exists(LSFGVK_FILE):
        return None
    try:
        age = time.time() - os.path.getmtime(LSFGVK_FILE)
        if age > 3:
            return None
        with open(LSFGVK_FILE, 'r') as f:
            val = f.read().strip()
        if val:
            fps = float(val)
            if fps > 0:
                return fps
        return 0.0
    except (OSError, ValueError):
        return None

# ── gpu-screen-recorder fallback ──────────────────────────────────
GSR_FILE = '/dev/shm/gsr-fps-stats'
_gsr_fps_re = re.compile(rb'update fps: (\d+)')

def _get_fps_gsr():
    """Optional fallback: Read FPS from gpu-screen-recorder stats.
    Requires gpu-screen-recorder running separately.
    """
    if not os.path.exists(GSR_FILE):
        return None
    try:
        age = time.time() - os.path.getmtime(GSR_FILE)
        if age > 10:
            return None
        with open(GSR_FILE, 'rb') as f:
            f.seek(0, 2)
            size = f.tell()
            chunk_size = min(size, 4096)
            f.seek(-chunk_size, 2)
            data = f.read()
        for line in reversed(data.split(b'\n')):
            m = _gsr_fps_re.search(line)
            if m:
                fps_val = float(m.group(1))
                if fps_val > 0:
                    return fps_val
                return 0.0
        return None
    except (OSError, ValueError):
        return None

# ── MangoHud fallback ─────────────────────────────────────────────
MANGOHUD_LOG_DIR = '/dev/shm/mangohud'

def _get_fps_mangohud():
    """Optional fallback: Read FPS from MangoHud CSV log."""
    if not os.path.isdir(MANGOHUD_LOG_DIR):
        return None
    try:
        csv_files = [f for f in os.listdir(MANGOHUD_LOG_DIR)
                     if f.endswith('.csv')]
        if not csv_files:
            return None
        latest = max(csv_files, key=lambda f:
                     os.path.getmtime(os.path.join(MANGOHUD_LOG_DIR, f)))
        csv_path = os.path.join(MANGOHUD_LOG_DIR, latest)
        age = time.time() - os.path.getmtime(csv_path)
        if age > 10:
            return None
        with open(csv_path, 'r') as f:
            lines = f.readlines()
        if not lines:
            return None
        for line in reversed(lines):
            line = line.strip()
            if not line:
                continue
            parts = line.split(',')
            if len(parts) >= 1:
                try:
                    fps_val = float(parts[0])
                    if fps_val > 0:
                        return fps_val
                    return 0.0
                except (ValueError, IndexError):
                    continue
        return None
    except (OSError, ValueError, IndexError, PermissionError):
        return None

# ═══════════════════════════════════════════════════════════════════
#  FPS resolution: try sources in order of preference
# ═══════════════════════════════════════════════════════════════════

def _get_fps():
    """Resolve FPS from available sources.

    Priority:
      1. Built-in libambfps.so (via LD_PRELOAD) - PRIMARY
      2. Modified LSFG-VK (optional, if available)
      3. gpu-screen-recorder (optional fallback)
      4. MangoHud CSV (optional fallback)
    """    
    # 1. PRIMARY: Built-in nothingless preload library
    fps = _get_fps_shm()
    if fps is not None:
        return fps, True

    # 2. Modified LSFG-VK (optional external)
    fps = _get_fps_lsfgvk()
    if fps is not None:
        return fps, True

    # 3. gpu-screen-recorder (optional external)
    fps = _get_fps_gsr()
    if fps is not None:
        return fps, True

    # 4. MangoHud CSV (optional external)
    fps = _get_fps_mangohud()
    if fps is not None:
        return fps, True

    return None, False

# ═══════════════════════════════════════════════════════════════════
#  Main loop
# ═══════════════════════════════════════════════════════════════════

def main():
    fps_samples = []
    output_interval = 0.3  # Update notch every 300ms

    try:
        while True:
            tick_start = time.monotonic()
            cpu_temp = _get_cpu_temp()
            cpu_power = _get_cpu_power()
            gpu_usages, gpu_temps, gpu_powers = _get_gpu_stats()

            fps_val, fps_active = _get_fps()

            result = {
                'cpu_temp': cpu_temp,
                'cpu_power': cpu_power,
                'gpu_usage': round(gpu_usages[0], 1) if gpu_usages else 0.0,
                'gpu_temp': gpu_temps[0] if gpu_temps else -1,
                'gpu_power': round(gpu_powers[0], 1) if gpu_powers else 0.0,
            }

            if fps_val is not None and fps_val > 0:
                # FPS from libambfps.so is already smoothed (EMA).
                # FPS from other sources may be raw - cap and average.
                capped = min(fps_val, 500.0)
                fps_samples.append(capped)
                if len(fps_samples) > 10:
                    fps_samples.pop(0)
                avg_fps = sum(fps_samples) / len(fps_samples)
                result['fps'] = round(avg_fps, 1)
                result['fps_active'] = True
            else:
                result['fps'] = 0.0
                result['fps_active'] = fps_active

            print(json.dumps(result), flush=True)
            elapsed = time.monotonic() - tick_start
            time.sleep(max(0.01, output_interval - elapsed))
    except KeyboardInterrupt:
        pass

if __name__ == '__main__':
    main()
