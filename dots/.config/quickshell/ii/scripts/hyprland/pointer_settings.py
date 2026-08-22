#!/usr/bin/env python3
"""Transactional persistence/runtime helper for Mouse & Touchpad settings."""
import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path

HOME = Path(os.environ.get("HOME", "~")).expanduser()
HYPR = HOME / ".config" / "hypr"
CUSTOM = HYPR / "custom"
POINTER = CUSTOM / "pointer.lua"
HYPRLAND_LUA = HYPR / "hyprland.lua"
FIELDS = (
    "sensitivity", "accel_profile", "natural_scroll",
    "touchpad_natural_scroll", "touchpad_scroll_factor",
    "touchpad_tap_to_click", "touchpad_tap_and_drag",
    "touchpad_disable_while_typing", "touchpad_clickfinger_behavior",
    "touchpad_middle_button_emulation",
)
MARKER = "-- illogical-impulse managed pointer settings"


def run(*args):
    return subprocess.run(args, text=True, capture_output=True)


def get_option(name):
    result = run("hyprctl", "getoption", f"input:{name}", "-j")
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Could not read input:{name}")
    value = json.loads(result.stdout)
    value = value.get("str", value.get("float", value.get("bool", "")))
    if value == "[[EMPTY]]":
        value = ""
    return value


def state():
    profile = str(get_option("accel_profile")) or "adaptive"
    return {
        "sensitivity": float(get_option("sensitivity")),
        "accel_profile": profile,
        "natural_scroll": bool(get_option("natural_scroll")),
        "touchpad_natural_scroll": bool(get_option("touchpad:natural_scroll")),
        "touchpad_scroll_factor": float(get_option("touchpad:scroll_factor")),
        "touchpad_tap_to_click": bool(get_option("touchpad:tap_to_click")),
        "touchpad_tap_and_drag": bool(get_option("touchpad:tap_and_drag")),
        "touchpad_disable_while_typing": bool(get_option("touchpad:disable_while_typing")),
        "touchpad_clickfinger_behavior": bool(get_option("touchpad:clickfinger_behavior")),
        "touchpad_middle_button_emulation": bool(get_option("touchpad:middle_button_emulation")),
    }


def lua(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    return json.dumps(str(value))


def apply_runtime(key, value):
    """Hyprland 0.56's non-legacy parser applies live config through eval."""
    parts = key.split(":")
    expression = f"hl.config({{ {parts[0]} = {{"
    if len(parts) == 2:
        expression += f" {parts[1]} = {lua(value)} "
    else:
        expression += f" {parts[1]} = {{ {parts[2]} = {lua(value)} }} "
    expression += "} })"
    result = run("hyprctl", "eval", expression)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"Hyprland rejected {key}")


def fragment(values):
    return "\n".join([
        MARKER,
        "-- This file is owned by System Settings; unrelated input stays in custom/general.lua.",
        "",
        "hl.config({",
        "    input = {",
        f"        sensitivity = {lua(values['sensitivity'])},",
        f"        accel_profile = {lua(values['accel_profile'])},",
        f"        natural_scroll = {lua(values['natural_scroll'])},",
        "        touchpad = {",
        f"            natural_scroll = {lua(values['touchpad_natural_scroll'])},",
        f"            scroll_factor = {lua(values['touchpad_scroll_factor'])},",
        f"            tap_to_click = {lua(values['touchpad_tap_to_click'])},",
        f"            tap_and_drag = {lua(values['touchpad_tap_and_drag'])},",
        f"            disable_while_typing = {lua(values['touchpad_disable_while_typing'])},",
        f"            clickfinger_behavior = {lua(values['touchpad_clickfinger_behavior'])},",
        f"            middle_button_emulation = {lua(values['touchpad_middle_button_emulation'])},",
        "        },",
        "    },",
        "})",
        "",
    ])


def atomic_write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode if path.exists() else 0o644
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(name, mode & 0o777)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def ensure_source():
    if not HYPRLAND_LUA.exists():
        return
    text = HYPRLAND_LUA.read_text(encoding="utf-8")
    if 'require("custom.pointer")' in text:
        return
    source = 'if is_file_exists(HOME .. "/.config/hypr/custom/pointer.lua") then\n    require("custom.pointer")\nend\n'
    anchor = 'if is_file_exists(HOME .. "/.config/hypr/custom/keyboard.lua") then\n    require("custom.keyboard")\nend\n'
    if anchor not in text:
        anchor = 'if is_file_exists(HOME .. "/.config/hypr/custom/general.lua") then\n    require("custom.general")\nend\n'
    if anchor not in text:
        raise RuntimeError("Could not locate custom input source in hyprland.lua")
    atomic_write(HYPRLAND_LUA, text.replace(anchor, anchor + source, 1))


def migrate():
    values = state()
    old_pointer = POINTER.read_text(encoding="utf-8") if POINTER.exists() else None
    old_hyprland = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else None
    try:
        ensure_source()
        atomic_write(POINTER, fragment(values))
        return values
    except Exception:
        if old_pointer is None:
            POINTER.unlink(missing_ok=True)
        else:
            atomic_write(POINTER, old_pointer)
        if old_hyprland is None:
            HYPRLAND_LUA.unlink(missing_ok=True)
        else:
            atomic_write(HYPRLAND_LUA, old_hyprland)
        raise


def ensure_migrated():
    source = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else ""
    if not POINTER.exists() or 'require("custom.pointer")' not in source:
        return migrate()
    return state()


def apply(values):
    values = {key: values[key] for key in FIELDS}
    values["sensitivity"] = float(values["sensitivity"])
    values["touchpad_scroll_factor"] = float(values["touchpad_scroll_factor"])
    if not -1.0 <= values["sensitivity"] <= 1.0:
        raise ValueError("Pointer speed must be between -1.0 and 1.0")
    if not 0.2 <= values["touchpad_scroll_factor"] <= 2.0:
        raise ValueError("Touchpad scroll speed must be between 0.2 and 2.0")
    if values["accel_profile"] not in ("adaptive", "flat"):
        raise ValueError("Unsupported acceleration profile")
    old = state()
    old_pointer = POINTER.read_text(encoding="utf-8") if POINTER.exists() else None
    old_hyprland = HYPRLAND_LUA.read_text(encoding="utf-8") if HYPRLAND_LUA.exists() else None
    runtime = {
        "sensitivity": values["sensitivity"],
        "accel_profile": values["accel_profile"],
        "natural_scroll": values["natural_scroll"],
        "touchpad:natural_scroll": values["touchpad_natural_scroll"],
        "touchpad:scroll_factor": values["touchpad_scroll_factor"],
        "touchpad:tap_to_click": values["touchpad_tap_to_click"],
        "touchpad:tap_and_drag": values["touchpad_tap_and_drag"],
        "touchpad:disable_while_typing": values["touchpad_disable_while_typing"],
        "touchpad:clickfinger_behavior": values["touchpad_clickfinger_behavior"],
        "touchpad:middle_button_emulation": values["touchpad_middle_button_emulation"],
    }
    try:
        ensure_source()
        atomic_write(POINTER, fragment(values))
        for key, value in runtime.items():
            apply_runtime(f"input:{key}", value)
        verified = state()
        for key in FIELDS:
            if str(verified[key]) != str(values[key]):
                raise RuntimeError(f"Hyprland did not accept {key}")
        return verified
    except Exception:
        if old_pointer is None:
            POINTER.unlink(missing_ok=True)
        else:
            atomic_write(POINTER, old_pointer)
        if old_hyprland is None:
            HYPRLAND_LUA.unlink(missing_ok=True)
        else:
            atomic_write(HYPRLAND_LUA, old_hyprland)
        for key, value in {
            "sensitivity": old["sensitivity"], "accel_profile": old["accel_profile"],
            "natural_scroll": old["natural_scroll"],
            "touchpad:natural_scroll": old["touchpad_natural_scroll"],
            "touchpad:scroll_factor": old["touchpad_scroll_factor"],
            "touchpad:tap_to_click": old["touchpad_tap_to_click"],
            "touchpad:tap_and_drag": old["touchpad_tap_and_drag"],
            "touchpad:disable_while_typing": old["touchpad_disable_while_typing"],
            "touchpad:clickfinger_behavior": old["touchpad_clickfinger_behavior"],
            "touchpad:middle_button_emulation": old["touchpad_middle_button_emulation"],
        }.items():
            apply_runtime(f"input:{key}", value)
        raise


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", action="store_true")
    parser.add_argument("--migrate", action="store_true")
    parser.add_argument("--apply")
    args = parser.parse_args()
    try:
        if args.migrate:
            print(json.dumps(migrate()))
        elif args.apply:
            print(json.dumps(apply(json.loads(args.apply))))
        elif args.state:
            ensure_migrated()
            print(json.dumps(state()))
        else:
            parser.error("one of --state, --migrate, --apply is required")
    except Exception as exc:
        print(str(exc), file=os.sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
