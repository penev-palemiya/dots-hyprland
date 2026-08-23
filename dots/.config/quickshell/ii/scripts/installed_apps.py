#!/usr/bin/env python3
"""Return one-shot local package/Flatpak enrichment for Installed Apps."""

import json
import os
import re
import subprocess


def run(command):
    try:
        return subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "LC_ALL": "C", "LANG": "C"},
        ).stdout
    except OSError:
        return ""


def parse_qi(text):
    packages = {}
    current = {}
    for line in text.splitlines() + [""]:
        if not line.strip():
            if current.get("Name"):
                packages[current["Name"]] = {
                    "id": current["Name"],
                    "version": current.get("Version", ""),
                    "description": current.get("Description", ""),
                    "installedSize": current.get("Installed Size", ""),
                    "installDate": current.get("Install Date", ""),
                    "installReason": current.get("Install Reason", ""),
                    "repository": current.get("Repository", ""),
                }
            current = {}
            continue
        if " : " in line:
            key, value = line.split(" : ", 1)
            current[key.strip()] = value.strip()
    return packages


def package_ownership():
    ownership = {}
    ambiguous = set()
    for line in run(["pacman", "-Ql"]).splitlines():
        match = re.match(r"([^ ]+)\s+(.+)$", line)
        if not match:
            continue
        package, path = match.groups()
        if not path.endswith(".desktop") or "/applications/" not in path:
            continue
        basename = path.rsplit("/", 1)[-1]
        if basename in ownership and ownership[basename] != package:
            ambiguous.add(basename)
        else:
            ownership[basename] = package
    for basename in ambiguous:
        ownership.pop(basename, None)
    return ownership


def flatpak_apps():
    result = {}
    output = run([
        "flatpak",
        "list",
        "--app",
        "--columns=application,name,version,branch,installation,size",
    ])
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) < 6:
            continue
        app_id, name, version, branch, installation, size = fields[:6]
        if not app_id:
            continue
        result[f"{app_id}.desktop"] = {
            "id": app_id,
            "name": name,
            "version": version,
            "branch": branch,
            "installation": installation,
            "installedSize": size,
        }
    return result


def main():
    ownership = package_ownership()
    owned_packages = sorted(set(ownership.values()))
    # Only application-owning packages are relevant to this page. Keeping the
    # query batched avoids one pacman call per row without serializing the full
    # local database of unrelated libraries and system components.
    packages = parse_qi(run(["pacman", "-Qi", *owned_packages])) if owned_packages else {}
    foreign = set(run(["pacman", "-Qm"]).split())
    for package in foreign:
        if package in packages:
            packages[package]["foreign"] = True
    print(json.dumps({
        "version": 1,
        "ownership": ownership,
        "pacman": packages,
        "flatpak": flatpak_apps(),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
