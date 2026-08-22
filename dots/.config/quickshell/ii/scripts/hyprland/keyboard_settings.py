#!/usr/bin/env python3
"""Small, transactional helper for the Settings keyboard page.

Hyprland remains authoritative at runtime. This helper only owns the managed
keyboard fragment and applies the same values through hyprctl.
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

HOME = Path(os.environ.get("HOME", "~")).expanduser()
HYPR = HOME / ".config" / "hypr"
CUSTOM = HYPR / "custom"
GENERAL = CUSTOM / "general.lua"
KEYBOARD = CUSTOM / "keyboard.lua"
HYPRLAND_LUA = HYPR / "hyprland.lua"
MARKER = "-- illogical-impulse managed keyboard settings"
FIELDS = ("kb_layout", "kb_variant", "kb_model", "kb_options", "repeat_rate", "repeat_delay", "numlock_by_default")


def run(*args, check=False):
    return subprocess.run(args, text=True, capture_output=True, check=check)


def get_option(key):
    result = run("hyprctl", "getoption", f"input:{key}", "-j")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Could not read input:{key}")
    data = json.loads(result.stdout)
    value = data.get("str", data.get("int", data.get("bool", "")))
    if value == "[[EMPTY]]":
        value = ""
    return value


def effective_state():
    return {
        "kb_layout": str(get_option("kb_layout")),
        "kb_variant": str(get_option("kb_variant")),
        "kb_model": str(get_option("kb_model")),
        "kb_options": str(get_option("kb_options")),
        "repeat_rate": int(get_option("repeat_rate")),
        "repeat_delay": int(get_option("repeat_delay")),
        "numlock_by_default": bool(get_option("numlock_by_default")),
    }


def lua_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)


def fragment(state):
    lines = [MARKER, "-- This file is owned by System Settings; keep unrelated input settings in custom/general.lua.", "", "hl.config({", "    input = {"]
    for key in FIELDS:
        lines.append(f"        {key} = {lua_value(state[key])},")
    lines.extend(["    },", "})", ""])
    return "\n".join(lines)


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode if path.exists() else 0o644
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_name, mode & 0o777)
        os.replace(temp_name, path)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def ensure_source():
    if not HYPRLAND_LUA.exists():
        return
    text = HYPRLAND_LUA.read_text(encoding="utf-8")
    source = 'if is_file_exists(HOME .. "/.config/hypr/custom/keyboard.lua") then\n    require("custom.keyboard")\nend\n'
    if 'require("custom.keyboard")' in text:
        return
    anchor = 'if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then\n    require("custom.general")\nend\n'
    if anchor not in text:
        raise RuntimeError("Could not locate custom.general source in hyprland.lua")
    atomic_write(HYPRLAND_LUA, text.replace(anchor, anchor + source, 1))


def remove_owned_lines(text):
    pattern = re.compile(r"^\s*(kb_layout|kb_variant|kb_model|kb_options|repeat_rate|repeat_delay|numlock_by_default)\s*=.*(?:\n|$)", re.MULTILINE)
    return pattern.sub("", text)


def migrate():
    state = effective_state()
    old_general = GENERAL.read_text(encoding="utf-8") if GENERAL.exists() else ""
    old_keyboard = KEYBOARD.read_text(encoding="utf-8") if KEYBOARD.exists() else None
    old_hyprland = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else None
    try:
        ensure_source()
        atomic_write(KEYBOARD, fragment(state))
        if GENERAL.exists():
            atomic_write(GENERAL, remove_owned_lines(old_general))
        return state
    except Exception:
        if old_keyboard is None:
            KEYBOARD.unlink(missing_ok=True)
        else:
            atomic_write(KEYBOARD, old_keyboard)
        if GENERAL.exists() or old_general:
            atomic_write(GENERAL, old_general)
        if old_hyprland is None:
            HYPRLAND_LUA.unlink(missing_ok=True)
        else:
            atomic_write(HYPRLAND_LUA, old_hyprland)
        raise


def ensure_migrated():
    general = GENERAL.read_text(encoding="utf-8") if GENERAL.exists() else ""
    source = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else ""
    managed_in_general = re.search(r"^\s*(kb_layout|kb_variant|kb_model|kb_options|repeat_rate|repeat_delay|numlock_by_default)\s*=", general, re.MULTILINE)
    if not KEYBOARD.exists() or 'require("custom.keyboard")' not in source or managed_in_general:
        return migrate()
    return effective_state()


def apply_state(state):
    state = {key: state[key] for key in FIELDS}
    if not state["kb_layout"].strip():
        raise ValueError("At least one keyboard layout is required")
    if not 1 <= int(state["repeat_rate"]) <= 100:
        raise ValueError("Repeat speed must be between 1 and 100 per second")
    if not 100 <= int(state["repeat_delay"]) <= 1000:
        raise ValueError("Repeat delay must be between 100 and 1000 ms")
    old_state = effective_state()
    old_keyboard = KEYBOARD.read_text(encoding="utf-8") if KEYBOARD.exists() else None
    old_hyprland = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else None
    try:
        ensure_source()
        atomic_write(KEYBOARD, fragment(state))
        for key in FIELDS:
            value = str(state[key]).lower() if isinstance(state[key], bool) else str(state[key])
            result = run("hyprctl", "keyword", f"input:{key}", value)
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Hyprland rejected input:{key}")
        verified = effective_state()
        for key in FIELDS:
            if str(verified[key]) != str(state[key]):
                raise RuntimeError(f"Hyprland did not accept input:{key}")
        return verified
    except Exception:
        if old_keyboard is None:
            KEYBOARD.unlink(missing_ok=True)
        else:
            atomic_write(KEYBOARD, old_keyboard)
        if old_hyprland is None:
            HYPRLAND_LUA.unlink(missing_ok=True)
        else:
            atomic_write(HYPRLAND_LUA, old_hyprland)
        for key in FIELDS:
            value = str(old_state[key]).lower() if isinstance(old_state[key], bool) else str(old_state[key])
            run("hyprctl", "keyword", f"input:{key}", value)
        raise


def catalog():
    path = Path("/usr/share/X11/xkb/rules/evdev.xml")
    root = ET.parse(path).getroot()
    result = []
    seen = set()
    for layout in root.findall(".//layoutList/layout"):
        config = layout.find("configItem")
        if config is None:
            continue
        code = config.findtext("name", "").strip()
        name = config.findtext("description", code).strip()
        if not code or code in seen:
            continue
        seen.add(code)
        result.append({"layout": code, "variant": "", "displayName": name})
    print(json.dumps(result, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", action="store_true")
    parser.add_argument("--migrate", action="store_true")
    parser.add_argument("--catalog", action="store_true")
    parser.add_argument("--apply")
    args = parser.parse_args()
    try:
        if args.catalog:
            catalog()
        elif args.migrate:
            print(json.dumps(migrate(), ensure_ascii=False))
        elif args.apply:
            print(json.dumps(apply_state(json.loads(args.apply)), ensure_ascii=False))
        elif args.state:
            # Migration is intentionally one-shot and idempotent. Runtime
            # values remain authoritative until the user explicitly applies.
            ensure_migrated()
            print(json.dumps(effective_state(), ensure_ascii=False))
        else:
            parser.error("one of --state, --migrate, --catalog, --apply is required")
    except Exception as exc:
        print(str(exc), file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
