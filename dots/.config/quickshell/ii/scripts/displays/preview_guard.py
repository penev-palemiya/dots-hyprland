#!/usr/bin/env python3
"""One-shot external rollback guard for temporary Hyprland display previews."""

import argparse
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


BEGIN_MARKER = "-- BEGIN QUICKSETTINGS GENERATED MONITORS"
END_MARKER = "-- END QUICKSETTINGS GENERATED MONITORS"
RULE_MARKER = "-- quicksettings-monitor-rule: "


def runtime_root() -> Path:
    return Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "ii-displays-preview"


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "\\r") + '"'


def monitors_path(value=None) -> Path:
    return Path(value or Path.home() / ".config/hypr/monitors.lua")


def number(value):
    return format(float(value), ".8g")


def normal_rule(rule):
    result = {"output": str(rule["output"]), "enabled": bool(rule.get("enabled"))}
    if result["enabled"]:
        mode = rule["mode"]
        result.update({"mode": {"width": int(mode["width"]), "height": int(mode["height"]), "refreshRate": float(mode["refreshRate"])},
                       "x": float(rule["x"]), "y": float(rule["y"]), "scale": float(rule["scale"]),
                       "transform": int(rule["transform"]), "mirrorOf": str(rule.get("mirrorOf") or "")})
    return result


def generated_block(rules):
    lines = [BEGIN_MARKER]
    for rule in sorted((normal_rule(rule) for rule in rules), key=lambda item: item["output"]):
        lines.append(RULE_MARKER + json.dumps(rule, sort_keys=True, separators=(",", ":")))
        if not rule["enabled"]:
            lines.extend(["hl.monitor({", f"    output = {lua_string(rule['output'])},", "    disabled = true", "})"])
            continue
        mode = rule["mode"]
        mode_value = f"{mode['width']}x{mode['height']}@{number(mode['refreshRate'])}"
        position_value = f"{number(rule['x'])}x{number(rule['y'])}"
        lines.extend(["hl.monitor({", f"    output = {lua_string(rule['output'])},", "    disabled = false,",
                      f"    mode = {lua_string(mode_value)},",
                      f"    position = {lua_string(position_value)},",
                      f"    scale = {number(rule['scale'])},", f"    transform = {rule['transform']},",
                      f"    mirror = {lua_string(rule['mirrorOf'])}", "})"])
    lines.append(END_MARKER)
    return "\n".join(lines) + "\n"


def split_generated(text):
    start = text.find(BEGIN_MARKER)
    if start < 0:
        return text, "", ""
    end = text.find(END_MARKER, start)
    if end < 0:
        # Do not guess what malformed manual content means; leave it untouched.
        return text, "", ""
    end += len(END_MARKER)
    if end < len(text) and text[end:end + 1] == "\n":
        end += 1
    return text[:start], text[start:end], text[end:]


def saved_rules(text):
    _, block, _ = split_generated(text)
    rules = {}
    for line in block.splitlines():
        if line.startswith(RULE_MARKER):
            try:
                rule = normal_rule(json.loads(line[len(RULE_MARKER):]))
                rules[rule["output"]] = rule
            except (ValueError, KeyError, TypeError):
                raise RuntimeError("generated monitor rule metadata is invalid")
    return rules


def merged_persistent_text(old_text, incoming, remove_output=None):
    rules = saved_rules(old_text)
    for rule in incoming:
        rules[normal_rule(rule)["output"]] = normal_rule(rule)
    if remove_output:
        rules.pop(remove_output, None)
    before, block, after = split_generated(old_text)
    generated = generated_block(rules.values())
    if block:
        return before + generated + after
    # Preserve arbitrary manual file byte-for-byte; append our owned block.
    separator = "" if not old_text or old_text.endswith("\n") else "\n"
    return old_text + separator + generated


def write_atomic(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    old_mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    temporary = path.parent / f".{path.name}.quickshell-{os.getpid()}.tmp"
    try:
        with open(temporary, "w", encoding="utf-8", newline="") as handle:
            os.fchmod(handle.fileno(), old_mode)
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory_fd = os.open(path.parent, os.O_DIRECTORY)
        try: os.fsync(directory_fd)
        finally: os.close(directory_fd)
    finally:
        temporary.unlink(missing_ok=True)


def save_persistent_backup(directory, path):
    backup = {"path": str(path), "existed": path.exists()}
    if backup["existed"]:
        backup["content"] = base64.b64encode(path.read_bytes()).decode("ascii")
        backup["mode"] = path.stat().st_mode & 0o777
    (directory / "persistent-backup.json").write_text(json.dumps(backup))


def restore_persistence(directory):
    backup_path = directory / "persistent-backup.json"
    if not backup_path.exists():
        return {"ok": True, "restored": False}
    backup = json.loads(backup_path.read_text())
    path = Path(backup["path"])
    if backup["existed"]:
        write_atomic(path, base64.b64decode(backup["content"]).decode("utf-8"))
        os.chmod(path, backup.get("mode", 0o644))
    else:
        path.unlink(missing_ok=True)
    return {"ok": True, "restored": True}


def reload_config():
    result = subprocess.run(["hyprctl", "reload"], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"hyprctl reload failed: {result.stderr.strip() or result.stdout.strip()}")


def live_monitors():
    result = subprocess.run(["hyprctl", "-j", "monitors", "all"], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"hyprctl monitors all failed: {result.stderr.strip()}")
    data = json.loads(result.stdout)
    if not isinstance(data, list):
        raise RuntimeError("hyprctl monitors all did not return an array")
    return data


def mode_string(monitor):
    return f'{int(monitor["width"])}x{int(monitor["height"])}@{float(monitor["refreshRate"]):.6f}'


def raw_to_rules(monitors):
    rules = []
    for monitor in monitors:
        disabled = bool(monitor.get("disabled", False))
        rules.append({
            "output": monitor["name"],
            "enabled": not disabled,
            "mode": None if disabled else {
                "width": monitor.get("width", 0),
                "height": monitor.get("height", 0),
                "refreshRate": monitor.get("refreshRate", 0),
            },
            "x": monitor.get("x", 0),
            "y": monitor.get("y", 0),
            "scale": monitor.get("scale", 1),
            "transform": monitor.get("transform", 0),
            "mirrorOf": "" if monitor.get("mirrorOf", "none") == "none" else monitor.get("mirrorOf"),
        })
    return rules


def lua_monitor(rule):
    output = lua_string(str(rule["output"]))
    if not rule.get("enabled", False):
        return f"hl.monitor({{ output = {output}, disabled = true }})"
    mode = rule["mode"]
    mode_value = f'{int(mode["width"])}x{int(mode["height"])}@{float(mode["refreshRate"]):.6f}'
    position = f'{float(rule["x"]):g}x{float(rule["y"]):g}'
    mirror = lua_string(str(rule.get("mirrorOf") or ""))
    return "hl.monitor({ " + ", ".join([
        f"output = {output}", "disabled = false", f"mode = {lua_string(mode_value)}",
        f"position = {lua_string(position)}", f"scale = {float(rule['scale']):.8g}",
        f"transform = {int(rule['transform'])}", f"mirror = {mirror}",
    ]) + " })"


def run_lua(rules):
    if not rules:
        return {"ok": True, "applied": []}
    code = "; ".join(lua_monitor(rule) for rule in rules)
    result = subprocess.run(["hyprctl", "eval", code], capture_output=True, text=True)
    if result.returncode != 0 or result.stdout.strip() != "ok":
        raise RuntimeError(f"hyprctl eval failed: {result.stderr.strip() or result.stdout.strip()}")
    return {"ok": True, "applied": [rule["output"] for rule in rules]}


def usable_count(monitors):
    return sum(not monitor.get("disabled", False) and monitor.get("mirrorOf", "none") == "none" for monitor in monitors)


def rule_matches_live(rule, monitor):
    """Whether a phase-3-owned rule is already present at runtime."""
    if bool(rule.get("enabled")) != (not bool(monitor.get("disabled", False))):
        return False
    if not rule.get("enabled"):
        return True
    mode = rule.get("mode") or {}
    if (int(mode.get("width", -1)) != int(monitor.get("width", -2))
            or int(mode.get("height", -1)) != int(monitor.get("height", -2))
            or abs(float(mode.get("refreshRate", -1)) - float(monitor.get("refreshRate", -2))) > 0.1):
        return False
    if (abs(float(rule.get("x", 0)) - float(monitor.get("x", 0))) > 0.01
            or abs(float(rule.get("y", 0)) - float(monitor.get("y", 0))) > 0.01
            or abs(float(rule.get("scale", 1)) - float(monitor.get("scale", 1))) > 0.001
            or int(rule.get("transform", 0)) != int(monitor.get("transform", 0))):
        return False
    wanted_mirror = rule.get("mirrorOf") or "none"
    actual_mirror = monitor.get("mirrorOf") or "none"
    return wanted_mirror == actual_mirror


def apply_rules(rules, best_effort=False):
    current = live_monitors()
    current_by_name = {monitor["name"]: monitor for monitor in current}
    current_names = set(current_by_name)
    skipped = [rule["output"] for rule in rules if rule["output"] not in current_names]
    # Never send a monitor command for an output already matching the rule.
    # Besides avoiding pointless modesets, this keeps a preview limited to the
    # outputs the draft actually changes (important for the primary display).
    candidates = [rule for rule in rules if rule["output"] in current_names
                  and not rule_matches_live(rule, current_by_name[rule["output"]])]
    extended = [rule for rule in candidates if rule.get("enabled") and not rule.get("mirrorOf")]
    mirrors = [rule for rule in candidates if rule.get("enabled") and rule.get("mirrorOf")]
    disabled = [rule for rule in candidates if not rule.get("enabled")]
    applied = []
    errors = []

    for stage in (extended, mirrors):
        try:
            applied.extend(run_lua(stage)["applied"])
        except Exception as error:
            if not best_effort:
                raise
            errors.append(str(error))

    for rule in disabled:
        try:
            live = live_monitors()
            target = next((monitor for monitor in live if monitor["name"] == rule["output"]), None)
            if target and not target.get("disabled", False) and target.get("mirrorOf", "none") == "none" and usable_count(live) <= 1:
                raise RuntimeError(f"refusing to disable last usable output {rule['output']}")
            applied.extend(run_lua([rule])["applied"])
        except Exception as error:
            if not best_effort:
                raise
            errors.append(str(error))
    return {"ok": not errors, "applied": applied, "skipped": skipped, "errors": errors}


def transaction_paths(directory: Path):
    return directory / "snapshot.json", directory / "active.json", directory / "lock"


def acquire_lock(directory: Path):
    _, _, lock = transaction_paths(directory)
    try:
        lock.mkdir()
        return True
    except FileExistsError:
        return False


def restore(directory: Path):
    snapshot_path, active_path, _ = transaction_paths(directory)
    if not snapshot_path.exists():
        return {"ok": False, "errors": ["rollback snapshot is missing"], "skipped": [], "applied": []}
    if not acquire_lock(directory):
        return {"ok": False, "errors": ["rollback already in progress"], "skipped": [], "applied": []}
    snapshot = json.loads(snapshot_path.read_text())
    persistence = {"ok": True, "restored": False}
    errors = []
    try:
        persistence = restore_persistence(directory)
        if persistence["restored"]:
            reload_config()
    except Exception as error:
        errors.append(f"persistent rollback failed: {error}")
    result = apply_rules(raw_to_rules(snapshot["monitors"]), best_effort=True)
    result["persistence"] = persistence
    result["errors"] = errors + result.get("errors", [])
    result["ok"] = not result["errors"]
    if result["ok"]:
        active_path.unlink(missing_ok=True)
        shutil.rmtree(directory, ignore_errors=True)
    return result


def pid_alive(pid):
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def watchdog(directory: Path):
    _, active_path, _ = transaction_paths(directory)
    while active_path.exists():
        try:
            active = json.loads(active_path.read_text())
        except (OSError, json.JSONDecodeError):
            return
        if time.time() >= active["deadline"] or not pid_alive(active["ownerPid"]):
            restore(directory)
            return
        time.sleep(0.25)


def begin(args):
    directory = runtime_root() / args.transaction
    directory.mkdir(parents=True, exist_ok=False)
    monitors = json.loads(args.snapshot_json)
    if not isinstance(monitors, list):
        raise RuntimeError("snapshot must be a monitor array")
    snapshot_path, active_path, _ = transaction_paths(directory)
    snapshot_path.write_text(json.dumps({"version": 1, "createdAt": time.time(), "monitors": monitors}))
    active_path.write_text(json.dumps({"ownerPid": os.getppid(), "deadline": time.time() + args.timeout}))
    child = os.fork()
    if child == 0:
        os.setsid()
        watchdog(directory)
        os._exit(0)
    print(json.dumps({"ok": True, "directory": str(directory), "deadline": time.time() + args.timeout}))


def confirm(directory: Path):
    _, active_path, _ = transaction_paths(directory)
    active_path.unlink(missing_ok=True)
    shutil.rmtree(directory, ignore_errors=True)
    print(json.dumps({"ok": True}))


def commit(directory: Path, rules, path_value=None, remove_output=None):
    if not (directory / "snapshot.json").exists():
        raise RuntimeError("preview transaction is missing its live snapshot")
    path = monitors_path(path_value)
    save_persistent_backup(directory, path)
    old_text = path.read_text(encoding="utf-8") if path.exists() else ""
    new_text = merged_persistent_text(old_text, rules, remove_output)
    if new_text != old_text:
        write_atomic(path, new_text)
    reload_config()
    print(json.dumps({"ok": True, "changed": new_text != old_text, "path": str(path)}))


def recover():
    root = runtime_root()
    recovered = []
    if not root.exists():
        print(json.dumps({"ok": True, "recovered": recovered}))
        return
    current_owner = os.getppid()
    for directory in root.iterdir():
        _, active_path, _ = transaction_paths(directory)
        if not active_path.exists():
            continue
        try:
            active = json.loads(active_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        if active.get("ownerPid") == current_owner or not pid_alive(active.get("ownerPid", -1)):
            recovered.append({"directory": str(directory), "result": restore(directory)})
    print(json.dumps({"ok": True, "recovered": recovered}))


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)
    begin_parser = subparsers.add_parser("begin")
    begin_parser.add_argument("--transaction", required=True)
    begin_parser.add_argument("--timeout", type=float, required=True)
    begin_parser.add_argument("--snapshot-json", required=True)
    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("--rules-json", required=True)
    directory_parser = lambda name: subparsers.add_parser(name).add_argument("--directory", required=True)
    directory_parser("confirm")
    directory_parser("revert")
    commit_parser = subparsers.add_parser("commit")
    commit_parser.add_argument("--directory", required=True)
    commit_parser.add_argument("--rules-json", required=True)
    commit_parser.add_argument("--monitors-path")
    commit_parser.add_argument("--remove-output")
    subparsers.add_parser("recover")
    args = parser.parse_args()
    try:
        if args.action == "begin":
            begin(args)
        elif args.action == "apply":
            print(json.dumps(apply_rules(json.loads(args.rules_json))))
        elif args.action == "confirm":
            confirm(Path(args.directory))
        elif args.action == "revert":
            print(json.dumps(restore(Path(args.directory))))
        elif args.action == "commit":
            commit(Path(args.directory), json.loads(args.rules_json), args.monitors_path, args.remove_output)
        else:
            recover()
    except Exception as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
