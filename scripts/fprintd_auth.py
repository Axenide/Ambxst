#!/usr/bin/env python3
"""
Fingerprint authentication helper using fprintd D-Bus API.
Outputs JSON to stdout for QML consumption.

Usage:
  python3 fprintd_auth.py check       - Check if fprintd is available and fingers enrolled
  python3 fprintd_auth.py verify      - Start fingerprint verification (blocks until done)
  python3 fprintd_auth.py enroll <finger> - Enroll a finger
  python3 fprintd_auth.py delete <finger> - Delete enrolled finger
  python3 fprintd_auth.py list        - List enrolled fingers
"""

import sys
import json
import os

sys.stdout.reconfigure(line_buffering=True)

try:
    import dbus
    HAS_DBUS = True
except ImportError:
    HAS_DBUS = False

FPRINTD_SERVICE = "net.reactivated.Fprint"
FPRINTD_PATH = "/net/reactivated/Fprint/Device/0"
FPRINTD_INTERFACE = "net.reactivated.Fprint.Device"


def get_bus():
    """Get D-Bus session bus."""
    if HAS_DBUS:
        return dbus.SessionBus()
    return None


def check_available():
    """Check if fprintd is available and fingers are enrolled."""
    result = {
        "available": False,
        "enrolled": False,
        "fingers": [],
        "error": None
    }

    if not HAS_DBUS:
        result["error"] = "python-dbus not installed"
        print(json.dumps(result))
        return

    try:
        bus = get_bus()
        if bus is None:
            result["error"] = "Failed to get D-Bus session bus"
            print(json.dumps(result))
            return

        if not bus.name_has_owner(FPRINTD_SERVICE):
            result["error"] = "fprintd service not running"
            print(json.dumps(result))
            return

        result["available"] = True

        device = dbus.Interface(
            bus.get_object(FPRINTD_SERVICE, FPRINTD_PATH),
            FPRINTD_INTERFACE
        )

        fingers = device.ListEnrolledFingers()
        finger_list = []
        for f in fingers:
            if isinstance(f, dbus.String):
                finger_list.append(str(f))
            elif isinstance(f, (list, tuple)):
                for item in f:
                    if isinstance(item, dbus.String):
                        finger_list.append(str(item))

        result["fingers"] = finger_list
        result["enrolled"] = len(finger_list) > 0

    except Exception as e:
        result["error"] = str(e)

    print(json.dumps(result))


def verify_finger():
    """Start fingerprint verification and wait for result."""
    result = {
        "success": False,
        "error": None,
        "finger": None
    }

    if not HAS_DBUS:
        result["error"] = "python-dbus not installed"
        print(json.dumps(result))
        return

    try:
        bus = get_bus()
        if bus is None:
            result["error"] = "Failed to get D-Bus session bus"
            print(json.dumps(result))
            return

        if not bus.name_has_owner(FPRINTD_SERVICE):
            result["error"] = "fprintd service not running"
            print(json.dumps(result))
            return

        device = dbus.Interface(
            bus.get_object(FPRINTD_SERVICE, FPRINTD_PATH),
            FPRINTD_INTERFACE
        )

        username = os.environ.get("USER", "")
        if username:
            device.SetUsername(username)

        fingers = device.ListEnrolledFingers()
        if not fingers:
            result["error"] = "No fingers enrolled"
            print(json.dumps(result))
            return

        first_finger = str(fingers[0]) if fingers else ""
        result["finger"] = first_finger

        ret = device.VerifyStart(first_finger)
        if ret != 0:
            result["error"] = f"VerifyStart failed with code {ret}"
            print(json.dumps(result))
            return

        print(json.dumps({"status": "scanning", "finger": first_finger}))
        sys.stdout.flush()

        done = False
        success = False
        timeout_count = 0
        max_timeout = 30

        while not done and timeout_count < max_timeout:
            try:
                msg = bus.pop_message()
                while msg is not None:
                    if msg.get_member() == "VerifyStatus":
                        args = msg.get_args_list()
                        if len(args) >= 2:
                            done = bool(args[0])
                            success = bool(args[1])
                    msg = bus.pop_message()

                if not done:
                    import time
                    time.sleep(0.1)
                    timeout_count += 0.1
            except Exception:
                import time
                time.sleep(0.1)
                timeout_count += 0.1

        try:
            device.VerifyStop()
        except Exception:
            pass

        if done:
            result["success"] = success
            if not success:
                result["error"] = "Fingerprint did not match"
        else:
            result["error"] = "Fingerprint verification timed out"

    except Exception as e:
        result["error"] = str(e)

    print(json.dumps(result))


def enroll_finger(finger):
    """Enroll a new finger."""
    result = {
        "success": False,
        "error": None,
        "finger": finger
    }

    if not HAS_DBUS:
        result["error"] = "python-dbus not installed"
        print(json.dumps(result))
        return

    try:
        bus = get_bus()
        if bus is None:
            result["error"] = "Failed to get D-Bus session bus"
            print(json.dumps(result))
            return

        if not bus.name_has_owner(FPRINTD_SERVICE):
            result["error"] = "fprintd service not running"
            print(json.dumps(result))
            return

        device = dbus.Interface(
            bus.get_object(FPRINTD_SERVICE, FPRINTD_PATH),
            FPRINTD_INTERFACE
        )

        username = os.environ.get("USER", "")
        if username:
            device.SetUsername(username)

        ret = device.EnrollStart(finger)
        if ret != 0:
            result["error"] = f"EnrollStart failed with code {ret}"
            print(json.dumps(result))
            return

        print(json.dumps({"status": "enrolling", "finger": finger}))
        sys.stdout.flush()

        done = False
        success = False
        timeout_count = 0
        max_timeout = 60

        while not done and timeout_count < max_timeout:
            try:
                msg = bus.pop_message()
                while msg is not None:
                    if msg.get_member() == "EnrollStatus":
                        args = msg.get_args_list()
                        if len(args) >= 2:
                            done = bool(args[0])
                            success = bool(args[1])
                    msg = bus.pop_message()

                if not done:
                    import time
                    time.sleep(0.1)
                    timeout_count += 0.1
            except Exception:
                import time
                time.sleep(0.1)
                timeout_count += 0.1

        if done:
            result["success"] = success
            if not success:
                result["error"] = "Enrollment failed"
        else:
            result["error"] = "Enrollment timed out"

    except Exception as e:
        result["error"] = str(e)

    print(json.dumps(result))


def delete_finger(finger):
    """Delete an enrolled finger."""
    result = {
        "success": False,
        "error": None,
        "finger": finger
    }

    if not HAS_DBUS:
        result["error"] = "python-dbus not installed"
        print(json.dumps(result))
        return

    try:
        bus = get_bus()
        if bus is None:
            result["error"] = "Failed to get D-Bus session bus"
            print(json.dumps(result))
            return

        if not bus.name_has_owner(FPRINTD_SERVICE):
            result["error"] = "fprintd service not running"
            print(json.dumps(result))
            return

        device = dbus.Interface(
            bus.get_object(FPRINTD_SERVICE, FPRINTD_PATH),
            FPRINTD_INTERFACE
        )

        device.DeleteEnrolledFingers(finger)
        result["success"] = True

    except Exception as e:
        result["error"] = str(e)

    print(json.dumps(result))


def list_fingers():
    """List enrolled fingers."""
    result = {
        "available": False,
        "fingers": [],
        "error": None
    }

    if not HAS_DBUS:
        result["error"] = "python-dbus not installed"
        print(json.dumps(result))
        return

    try:
        bus = get_bus()
        if bus is None:
            result["error"] = "Failed to get D-Bus session bus"
            print(json.dumps(result))
            return

        if not bus.name_has_owner(FPRINTD_SERVICE):
            result["error"] = "fprintd service not running"
            print(json.dumps(result))
            return

        result["available"] = True

        device = dbus.Interface(
            bus.get_object(FPRINTD_SERVICE, FPRINTD_PATH),
            FPRINTD_INTERFACE
        )

        fingers = device.ListEnrolledFingers()
        finger_list = []
        for f in fingers:
            if isinstance(f, dbus.String):
                finger_list.append(str(f))
            elif isinstance(f, (list, tuple)):
                for item in f:
                    if isinstance(item, dbus.String):
                        finger_list.append(str(item))

        result["fingers"] = finger_list

    except Exception as e:
        result["error"] = str(e)

    print(json.dumps(result))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command specified"}))
        sys.exit(1)

    command = sys.argv[1]

    if command == "check":
        check_available()
    elif command == "verify":
        verify_finger()
    elif command == "enroll":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No finger specified"}))
            sys.exit(1)
        enroll_finger(sys.argv[2])
    elif command == "delete":
        if len(sys.argv) < 3:
            print(json.dumps({"error": "No finger specified"}))
            sys.exit(1)
        delete_finger(sys.argv[2])
    elif command == "list":
        list_fingers()
    else:
        print(json.dumps({"error": f"Unknown command: {command}"}))
        sys.exit(1)
