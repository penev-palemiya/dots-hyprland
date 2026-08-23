#!/usr/bin/env python3
"""Small, non-resident update/status helper for Settings.

The check path delegates repository comparison to Arch's checkupdates.  That
tool owns the temporary database and never changes /var/lib/pacman/sync.
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path


UPDATE_RE = re.compile(r"^(\S+)\s+(.+?)\s+->\s+(\S+)\s*$")
UPGRADE_RE = re.compile(r"^\[([^]]+)\]\s+\[ALPM\]\s+upgraded\s+([^ ]+)\s+\((.+?)\s+->\s+(.+?)\)$")
START_RE = re.compile(r"^\[([^]]+)\]\s+\[ALPM\]\s+transaction started$")
DONE_RE = re.compile(r"^\[([^]]+)\]\s+\[ALPM\]\s+transaction completed$")


def parse_updates(text):
    updates = []
    malformed = 0
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        match = UPDATE_RE.match(line)
        if not match:
            malformed += 1
            continue
        updates.append({
            "name": match.group(1),
            "installed": match.group(2),
            "available": match.group(3),
        })
    return updates, malformed


def check_updates():
    try:
        result = subprocess.run(
            ["/usr/bin/checkupdates", "--nocolor"],
            capture_output=True,
            text=True,
            timeout=300,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"ok": False, "error": str(exc)}

    # checkupdates returns 2 for a successful empty result and 0 when it
    # printed updates. Other statuses indicate a failed repository check.
    if result.returncode not in (0, 2):
        return {"ok": False, "error": "Update check failed."}

    updates, malformed = parse_updates(result.stdout)
    return {"ok": True, "updates": updates, "malformed": malformed}


def parse_history(text):
    current = None
    completed = []
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        start = START_RE.match(line)
        if start:
            current = {"timestamp": start.group(1), "upgrades": 0}
            continue
        if current is None:
            continue
        upgrade = UPGRADE_RE.match(line)
        if upgrade:
            current["upgrades"] += 1
            continue
        done = DONE_RE.match(line)
        if done:
            if current["upgrades"] > 0:
                completed.append(current)
            current = None
            continue
        if "[ALPM] transaction failed" in line:
            current = None

    if not completed:
        return {"available": False}
    latest = completed[-1]
    return {
        "available": True,
        "timestamp": latest["timestamp"],
        "upgrades": latest["upgrades"],
    }


def read_history(path="/var/log/pacman.log"):
    try:
        return parse_history(Path(path).read_text(errors="replace"))
    except OSError:
        return {"available": False}


def main(argv):
    if len(argv) < 2:
        print(json.dumps({"ok": False, "error": "Missing operation."}))
        return 2
    if argv[1] == "check":
        result = check_updates()
    elif argv[1] == "history":
        result = {"ok": True, "history": read_history()}
    else:
        result = {"ok": False, "error": "Unknown operation."}
    print(json.dumps(result, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
