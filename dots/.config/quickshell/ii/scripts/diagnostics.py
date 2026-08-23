#!/usr/bin/env python3
"""One-shot, local-only subsystem health snapshot for Settings."""

import json
import os
import pathlib
import subprocess


def command(argv, user=False):
    args = ["systemctl", "--user"] if user else ["systemctl"]
    args += argv
    try:
        result = subprocess.run(
            args, capture_output=True, text=True, timeout=5, check=False,
            env={**os.environ, "LC_ALL": "C", "LANG": "C"},
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, "", str(exc)


def process(argv):
    try:
        result = subprocess.run(
            argv, capture_output=True, text=True, timeout=5, check=False,
            env={**os.environ, "LC_ALL": "C", "LANG": "C"},
        )
        return result.returncode, result.stdout.strip(), result.stderr.strip()
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 127, "", str(exc)


def unit_state(unit, user=False):
    code, out, _ = command(["is-active", unit], user)
    state = out or "unknown"
    return state, code


def result(name, state, detail=""):
    return {"name": name, "state": state, "detail": detail}


def process_running(names):
    try:
        for entry in pathlib.Path("/proc").iterdir():
            if not entry.name.isdigit():
                continue
            try:
                comm = (entry / "comm").read_text(errors="replace").strip()
            except OSError:
                continue
            if comm in names:
                return True
    except OSError:
        pass
    return False


def portals():
    states = {unit: unit_state(unit, True)[0] for unit in (
        "xdg-desktop-portal.service",
        "xdg-desktop-portal-hyprland.service",
        "xdg-desktop-portal-gtk.service",
    )}
    failed = [unit for unit, state in states.items() if state == "failed"]
    missing = [unit for unit, state in states.items() if state in ("unknown", "inactive")]
    if failed:
        return result("Desktop portals", "error", "Failed: " + ", ".join(failed))
    if missing:
        return result("Desktop portals", "warning", "Unavailable: " + ", ".join(missing))
    return result("Desktop portals", "healthy")


def audio():
    states = {unit: unit_state(unit, True)[0] for unit in ("pipewire.service", "wireplumber.service")}
    failed = [unit for unit, state in states.items() if state == "failed"]
    missing = [unit for unit, state in states.items() if state in ("unknown", "inactive")]
    if failed:
        return result("Audio", "error", "Failed: " + ", ".join(failed))
    if missing:
        return result("Audio", "unavailable", "PipeWire audio stack is not running")
    return result("Audio", "healthy")


def network():
    state, _ = unit_state("NetworkManager.service")
    if state == "active":
        return result("Network", "healthy")
    if state == "failed":
        return result("Network", "error", "NetworkManager is failed")
    return result("Network", "unavailable", "NetworkManager is not running")


def bluetooth():
    state, _ = unit_state("bluetooth.service")
    adapter = any(pathlib.Path("/sys/class/bluetooth").glob("hci*"))
    if state == "failed":
        return result("Bluetooth", "error", "Bluetooth service is failed")
    if not adapter:
        return result("Bluetooth", "unavailable", "No Bluetooth adapter detected")
    if state != "active":
        return result("Bluetooth", "unavailable", "Bluetooth service is not running")
    return result("Bluetooth", "healthy")


def failed_services():
    code, out, _ = command(["--failed", "--type=service", "--no-legend", "--no-pager"], True)
    if code != 0:
        return result("Background services", "unknown", "Failed-service state unavailable")
    names = []
    for line in out.splitlines():
        fields = line.split()
        if fields:
            names.append(fields[0])
    if names:
        return result("Background services", "warning", f"{len(names)} failed")
    return result("Background services", "healthy")


def compositor():
    if process_running({"Hyprland"}):
        return result("Compositor", "healthy")
    return result("Compositor", "error", "Hyprland is not running")


def configuration():
    code, out, err = process(["hyprctl", "configerrors", "-j"])
    if code != 0:
        return result("Configuration", "unknown", "Read-only config error query unavailable")
    try:
        errors = json.loads(out or "[]")
        count = len(errors) if isinstance(errors, list) else int(errors.get("count", 0))
        return result("Configuration", "healthy" if count == 0 else "error", "" if count == 0 else f"{count} errors")
    except (ValueError, TypeError, AttributeError):
        return result("Configuration", "unknown", err or "Could not parse config error state")


def snapshot():
    checks = [
        result("Shell", "healthy") if process_running({"qs", "quickshell"}) else result("Shell", "error", "Quickshell is not running"),
        compositor(),
        configuration(),
        portals(),
        audio(),
        network(),
        bluetooth(),
        failed_services(),
        result("Update backend", "healthy") if os.access("/usr/bin/checkupdates", os.X_OK) else result("Update backend", "unavailable", "checkupdates is not installed"),
    ]
    return {"ok": True, "checks": checks}


if __name__ == "__main__":
    print(json.dumps(snapshot(), separators=(",", ":")))
