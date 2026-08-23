#!/usr/bin/env python3
import configparser
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

MANAGED = "X-IllogicalImpulse-StartupApps-Managed"
DISABLE_MARKER = "X-IllogicalImpulse-StartupApps-Disabled"
DESKTOPS = (".desktop",)


def paths():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    config_dirs = os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg").split(":")
    user = config_home / "autostart"
    system = [Path(p) / "autostart" for p in config_dirs if p]
    return user, system


def parse(path):
    data = {"path": str(path)}
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
        section = parser["Desktop Entry"]
    except (OSError, configparser.Error, KeyError):
        return None
    for key in ("Type", "Name", "GenericName", "Comment", "Icon", "Exec", "TryExec",
                "Hidden", "OnlyShowIn", "NotShowIn", "AutostartCondition", "NoDisplay",
                MANAGED, DISABLE_MARKER):
        if key in section:
            data[key] = section.get(key, "")
    data["basename"] = path.name
    return data


def truth(value):
    return str(value).lower() in ("1", "true", "yes", "on")


def desktop_applicable(item):
    desktop = os.environ.get("XDG_CURRENT_DESKTOP", "").split(":")
    only = [x for x in item.get("OnlyShowIn", "").split(";") if x]
    not_show = [x for x in item.get("NotShowIn", "").split(";") if x]
    if only and not any(x in desktop for x in only):
        return False
    if any(x in desktop for x in not_show):
        return False
    return True


def executable_available(item):
    try_exec = item.get("TryExec", "").strip()
    if not try_exec:
        return True
    return (Path(try_exec).is_file() and os.access(try_exec, os.X_OK)) or bool(shutil.which(try_exec))


def infrastructure(item):
    text = (item.get("basename", "") + " " + item.get("Name", "") + " " + item.get("Exec", "")).lower()
    needles = ("portal", "polkit", "keyring", "pipewire", "wireplumber", "dbus", "quickshell",
               "xdg-user-dirs", "baloo", "plasma", "kglobalaccel", "at-spi", "geoclue", "wallpaper-once")
    return any(needle in text for needle in needles)


def find_effective():
    user, system_dirs = paths()
    system = {}
    for directory in system_dirs:
        if not directory.is_dir():
            continue
        for path in directory.glob("*.desktop"):
            system.setdefault(path.name, path)
    user_files = {path.name: path for path in user.glob("*.desktop")} if user.is_dir() else {}
    result = []
    for basename in sorted(set(system) | set(user_files), key=str.casefold):
        system_path = system.get(basename)
        user_path = user_files.get(basename)
        base = parse(user_path or system_path)
        if not base:
            continue
        system_item = parse(system_path) if system_path else None
        managed = base.get(MANAGED, "").lower() == "true"
        hidden = truth(base.get("Hidden", "false"))
        # A minimal managed disable override inherits the vendor metadata.
        if system_item and user_path and managed and truth(base.get(DISABLE_MARKER, "false")):
            merged = dict(system_item)
            merged.update({"Hidden": "true", MANAGED: "true", DISABLE_MARKER: "true"})
            base = merged
            hidden = True
        item = {
            "id": basename,
            "basename": basename,
            "name": base.get("Name", basename.removesuffix(".desktop")),
            "genericName": base.get("GenericName", ""),
            "comment": base.get("Comment", ""),
            "icon": base.get("Icon", "application-x-executable"),
            "exec": base.get("Exec", ""),
            "tryExec": base.get("TryExec", ""),
            "hidden": hidden,
            "enabled": not hidden,
            "applicable": desktop_applicable(base),
            "available": executable_available(base),
            "infrastructure": infrastructure(base),
            "userPath": str(user_path) if user_path else "",
            "systemPath": str(system_path) if system_path else "",
            "effectivePath": str(user_path or system_path),
            "userOwned": bool(user_path),
            "managed": managed,
            "removable": bool(user_path and managed and not system_path),
        }
        if item["applicable"] and not item["infrastructure"]:
            result.append(item)
    return result


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


def set_field(content, key, value):
    lines = content.splitlines(keepends=True)
    in_entry = False
    found = False
    out = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("["):
            in_entry = stripped == "[Desktop Entry]"
        if in_entry and line.split("=", 1)[0].strip() == key:
            out.append(f"{key}={value}\n")
            found = True
        else:
            out.append(line)
    if not found:
        index = next((i for i, line in enumerate(out) if line.strip() == "[Desktop Entry]"), 0)
        out.insert(index + 1, f"{key}={value}\n")
    return "".join(out)


def toggle(basename, enabled):
    user, system_dirs = paths()
    system = next((directory / basename for directory in system_dirs if (directory / basename).is_file()), None)
    user_path = user / basename
    if system and not user_path.exists():
        if enabled:
            return True
        atomic_write(user_path, "[Desktop Entry]\nHidden=true\nX-IllogicalImpulse-StartupApps-Managed=true\nX-IllogicalImpulse-StartupApps-Disabled=true\n")
        return True
    if not user_path.exists():
        return False
    content = user_path.read_text(encoding="utf-8")
    managed = f"{MANAGED}=true" in content and (f"{DISABLE_MARKER}=true" in content or not system)
    if enabled and system and managed and f"{DISABLE_MARKER}=true" in content:
        user_path.unlink()
        return True
    atomic_write(user_path, set_field(content, "Hidden", "false" if enabled else "true"))
    return True


def desktop_source(desktop_id):
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    dirs = [data_home] + [Path(x) for x in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if x]
    for directory in dirs:
        path = directory / "applications" / desktop_id
        if path.is_file():
            return path
    return None


def add(desktop_id):
    source = desktop_source(desktop_id)
    if not source:
        return False
    user, _ = paths()
    target = user / source.name
    if target.exists():
        return False
    content = source.read_text(encoding="utf-8")
    content = set_field(content, MANAGED, "true")
    content = set_field(content, "Hidden", "false")
    atomic_write(target, content)
    return True


def remove(basename):
    user, system_dirs = paths()
    path = user / basename
    system = any((directory / basename).is_file() for directory in system_dirs)
    if not path.is_file() or system:
        return False
    content = path.read_text(encoding="utf-8")
    if f"{MANAGED}=true" not in content:
        return False
    path.unlink()
    return True


def main():
    op = sys.argv[1] if len(sys.argv) > 1 else "list"
    ok = True
    if op == "toggle":
        ok = toggle(sys.argv[2], sys.argv[3].lower() == "true")
    elif op == "add":
        ok = add(sys.argv[2])
    elif op == "remove":
        ok = remove(sys.argv[2])
    elif op != "list":
        ok = False
    print(json.dumps({"ok": ok, "entries": find_effective() if ok else []}, ensure_ascii=False))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
