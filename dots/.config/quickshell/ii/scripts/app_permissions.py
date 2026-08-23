#!/usr/bin/env python3
"""Read-only Flatpak sandbox and portal permission state in one batch."""

import json
import os
import pathlib
import subprocess


def run(command):
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            env={**os.environ, "LC_ALL": "C", "LANG": "C"},
        )
        return result.stdout.strip()
    except OSError:
        return ""


def parse_context(text):
    section = ""
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if "=" not in line or not section:
            continue
        key, value = line.split("=", 1)
        result.setdefault(section, {})[key.strip()] = value.strip()
    return result


def parse_flatpak_permissions(text):
    sections = parse_context(text)
    context = sections.get("Context", {})
    return {
        "context": context,
        "sessionBusPolicy": sections.get("Session Bus Policy", {}),
        "environment": sections.get("Environment", {}),
        "features": sections.get("Features", {}),
    }


def installed_apps():
    result = []
    output = run([
        "flatpak", "list", "--app",
        "--columns=application,name,version,installation,size",
    ])
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) < 5 or not fields[0]:
            continue
        app_id, name, version, installation, size = fields[:5]
        effective_text = run(["flatpak", "info", "--show-permissions", app_id])
        location = run(["flatpak", "info", "--show-location", app_id])
        manifest_text = ""
        if location:
            metadata = pathlib.Path(location) / "metadata"
            try:
                manifest_text = metadata.read_text(encoding="utf-8")
            except OSError:
                pass
        user_override = run(["flatpak", "override", "--user", "--show", app_id])
        system_override = run(["flatpak", "override", "--system", "--show", app_id])
        result.append({
            "id": app_id,
            "name": name,
            "version": version,
            "installation": installation,
            "size": size,
            "manifest": parse_flatpak_permissions(manifest_text),
            "effective": parse_flatpak_permissions(effective_text),
            "userOverride": parse_flatpak_permissions(user_override),
            "systemOverride": parse_flatpak_permissions(system_override),
        })
    return result


def portal_entries():
    entries = []
    output = run(["flatpak", "permissions"])
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) < 4:
            fields = line.split(None, 4)
        if len(fields) < 4:
            continue
        table, permission_id, app_id, value = fields[:4]
        data = fields[4] if len(fields) > 4 else ""
        entries.append({
            "table": table,
            "id": permission_id,
            "appId": app_id,
            "value": value,
            "data": data,
        })
    return entries


def portal_health():
    def user_unit_state(unit):
        return run(["systemctl", "--user", "is-active", unit]) or "unknown"

    return {
        "desktop": user_unit_state("xdg-desktop-portal.service"),
        "gtk": user_unit_state("xdg-desktop-portal-gtk.service"),
        "hyprland": user_unit_state("xdg-desktop-portal-hyprland.service"),
        "kde": user_unit_state("plasma-xdg-desktop-portal-kde.service"),
    }


def main():
    apps = installed_apps()
    entries = portal_entries()
    installed_ids = {app["id"] for app in apps}
    print(json.dumps({
        "version": 1,
        "apps": apps,
        "portalEntries": entries,
        "stalePortalEntries": [entry for entry in entries if entry["appId"] not in installed_ids],
        "portalHealth": portal_health(),
    }, ensure_ascii=False))


if __name__ == "__main__":
    main()
