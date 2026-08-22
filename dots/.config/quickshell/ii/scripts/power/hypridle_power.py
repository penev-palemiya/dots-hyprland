#!/usr/bin/env python3
"""Small, transactional owner for the three Settings-managed hypridle listeners."""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import subprocess
import tempfile
import time
from pathlib import Path


NAMES = ("lock", "dpms-off", "suspend")
MARKER = re.compile(r"^\s*#\s*ii-power-saving:\s*(lock|dpms-off|suspend)(?:\s+\(disabled\))?\s*$")
TIMEOUT = re.compile(r"^(\s*#?\s*timeout\s*=\s*)(\d+)(.*)$")


def config_path() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return config_home / "hypr" / "hypridle.conf"


def sections(text: str) -> dict[str, tuple[int, int, bool]]:
    lines = text.splitlines(keepends=True)
    markers: list[tuple[int, str, bool]] = []
    for index, line in enumerate(lines):
        match = MARKER.match(line.rstrip("\r\n"))
        if match:
            markers.append((index, match.group(1), "(disabled)" in line))
    found: dict[str, tuple[int, int, bool]] = {}
    for index, (start, name, disabled) in enumerate(markers):
        end = markers[index + 1][0] if index + 1 < len(markers) else len(lines)
        if name in found:
            raise ValueError(f"duplicate managed listener marker: {name}")
        found[name] = (start, end, disabled)
    missing = [name for name in NAMES if name not in found]
    if missing:
        raise ValueError(f"missing managed listener marker(s): {', '.join(missing)}")
    return found


def unmanaged_sections(text: str) -> dict[str, tuple[int, int, bool]]:
    """Recognize the pre-managed file by command identity, never by position."""
    lines = text.splitlines(keepends=True)
    candidates: list[tuple[int, int, str]] = []
    for start, line in enumerate(lines):
        if line.strip() != "listener {":
            continue
        depth = 0
        end = None
        for index in range(start, len(lines)):
            depth += lines[index].count("{") - lines[index].count("}")
            if depth == 0:
                end = index + 1
                break
        if end is None:
            raise ValueError("unterminated hypridle listener")
        body = "".join(lines[start:end])
        if "on-timeout = loginctl lock-session" in body:
            name = "lock"
        elif 'hl.dsp.dpms({ action = "disable" })' in body:
            name = "dpms-off"
        elif "on-timeout = $suspend_cmd" in body or "on-timeout = systemctl suspend" in body:
            name = "suspend"
        else:
            continue
        if any(existing[2] == name for existing in candidates):
            raise ValueError(f"multiple unmanaged listeners match {name}")
        candidates.append((start, end, name))
    found = {name: (start, end, False) for start, end, name in candidates}
    missing = [name for name in NAMES if name not in found]
    if missing:
        raise ValueError(f"missing managed listener marker(s): {', '.join(missing)}")
    return found


def managed_sections(text: str) -> dict[str, tuple[int, int, bool]]:
    try:
        return sections(text)
    except ValueError as marked_error:
        try:
            return unmanaged_sections(text)
        except ValueError:
            raise marked_error


def read_values(text: str) -> dict[str, int | None]:
    lines = text.splitlines()
    result: dict[str, int | None] = {}
    for name, (start, end, disabled) in managed_sections(text).items():
        value = None
        for line in lines[start + 1 : end]:
            match = TIMEOUT.match(line)
            if match:
                value = int(match.group(2))
                break
        result[name] = None if disabled else value
    return result


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    with tempfile.NamedTemporaryFile("w", dir=path.parent, prefix=f".{path.name}.", delete=False) as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
        temporary = Path(handle.name)
    os.chmod(temporary, mode)
    os.replace(temporary, path)


def running_pids() -> list[int]:
    try:
        output = subprocess.check_output(["pgrep", "-x", "hypridle"], text=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        return []
    return [int(line) for line in output.split() if line.isdigit()]


def stop_hypridle() -> None:
    for pid in running_pids():
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 2.0
    while running_pids() and time.monotonic() < deadline:
        time.sleep(0.05)
    remaining = running_pids()
    if remaining:
        for pid in remaining:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        time.sleep(0.1)
    if running_pids():
        raise RuntimeError("could not stop the existing hypridle process")


def start_hypridle() -> subprocess.Popen[bytes]:
    process = subprocess.Popen(
        ["hypridle"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    time.sleep(0.35)
    if process.poll() is not None:
        raise RuntimeError(f"new hypridle exited during startup (code {process.returncode})")
    return process


def rewrite(text: str, values: dict[str, int | None]) -> str:
    if any(value is not None and value < 0 for value in values.values()):
        raise ValueError("timeouts must be non-negative or null")
    finite = [values[name] for name in NAMES if values[name] is not None]
    ordered = [value for value in finite if value is not None]
    if ordered != sorted(ordered):
        raise ValueError("finite timeouts must be ordered lock <= dpms-off <= suspend")

    if not any("ii-power-saving:" in line for line in text.splitlines()):
        lines = text.splitlines(keepends=True)
        parsed_unmanaged = unmanaged_sections(text)
        for name in reversed(NAMES):
            start, _end, _disabled = parsed_unmanaged[name]
            lines.insert(start, f"# ii-power-saving: {name}\n")
        text = "".join(lines)
    lines = text.splitlines(keepends=True)
    parsed = sections(text)
    for name in NAMES:
        start, end, _was_disabled = parsed[name]
        active = values[name] is not None
        marker = f"# ii-power-saving: {name}{'' if active else ' (disabled)'}\n"
        body = lines[start + 1 : end]
        normalized: list[str] = []
        for line in body:
            if line.startswith("# "):
                line = line[2:]
            elif line.startswith("#"):
                line = line[1:]
            normalized.append(line)
        if active:
            replaced_timeout = False
            for index, line in enumerate(normalized):
                match = TIMEOUT.match(line.rstrip("\r\n"))
                if match:
                    ending = "\r\n" if line.endswith("\r\n") else "\n" if line.endswith("\n") else ""
                    normalized[index] = f"{match.group(1)}{values[name]}{match.group(3)}{ending}"
                    replaced_timeout = True
                    break
            if not replaced_timeout:
                raise ValueError(f"managed listener {name} has no timeout line")
        else:
            normalized = [f"# {line}" if line.strip() else line for line in normalized]
        lines[start : end] = [marker, *normalized]
        # Recalculate offsets after each replacement.
        parsed = sections("".join(lines))
    return "".join(lines)


def apply(values: dict[str, int | None]) -> dict[str, object]:
    path = config_path()
    previous = path.read_text()
    updated = rewrite(previous, values)
    if updated == previous:
        return {"ok": True, "changed": False, "values": read_values(previous), "pidCount": len(running_pids())}
    atomic_write(path, updated)
    try:
        stop_hypridle()
        start_hypridle()
    except Exception as error:
        atomic_write(path, previous)
        try:
            stop_hypridle()
            start_hypridle()
        except Exception as rollback_error:
            raise RuntimeError(f"hypridle restart failed: {error}; rollback restart failed: {rollback_error}")
        raise RuntimeError(f"hypridle restart failed; previous policy restored: {error}")
    return {"ok": True, "changed": True, "values": read_values(updated), "pidCount": len(running_pids())}


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("read")
    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("values", type=str)
    args = parser.parse_args()
    try:
        path = config_path()
        if args.command == "read":
            print(json.dumps({"ok": True, "values": read_values(path.read_text()), "pidCount": len(running_pids())}))
        else:
            values = json.loads(args.values)
            if set(values) != set(NAMES):
                raise ValueError("values must contain lock, dpms-off, and suspend")
            print(json.dumps(apply({name: (None if values[name] is None else int(values[name])) for name in NAMES})))
        return 0
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
