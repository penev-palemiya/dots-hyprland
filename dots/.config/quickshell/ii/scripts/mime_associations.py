#!/usr/bin/env python3
"""Small one-shot XDG MIME association helper for Settings."""

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


MIME_FILE = Path.home() / ".config" / "mimeapps.list"


def query_one(mime: str) -> str:
    result = subprocess.run(
        ["xdg-mime", "query", "default", mime],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""


def query(mimes: list[str]) -> None:
    print(json.dumps({mime: query_one(mime) for mime in mimes}, separators=(",", ":")))


def restore_snapshot(existed: bool, contents: bytes, mode: int | None) -> None:
    if not existed:
        try:
            MIME_FILE.unlink()
        except FileNotFoundError:
            pass
        return
    MIME_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".mimeapps.list.", dir=MIME_FILE.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(contents)
            stream.flush()
            os.fsync(stream.fileno())
        if mode is not None:
            os.chmod(temp_name, mode)
        os.replace(temp_name, MIME_FILE)
    finally:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass


def apply(desktop_id: str, mimes: list[str]) -> None:
    existed = MIME_FILE.exists()
    contents = MIME_FILE.read_bytes() if existed else b""
    mode = MIME_FILE.stat().st_mode & 0o777 if existed else None
    try:
        MIME_FILE.parent.mkdir(parents=True, exist_ok=True)
        for mime in mimes:
            result = subprocess.run(
                ["xdg-mime", "default", desktop_id, mime],
                text=True,
                capture_output=True,
                check=False,
            )
            if result.returncode != 0:
                raise RuntimeError(result.stderr.strip() or f"Could not set {mime}.")
        values = {mime: query_one(mime) for mime in mimes}
        if any(value != desktop_id for value in values.values()):
            raise RuntimeError("The system did not accept every association.")
        print(json.dumps({"ok": True, "values": values}, separators=(",", ":")))
    except Exception as error:
        try:
            restore_snapshot(existed, contents, mode)
        except Exception as rollback_error:
            print(json.dumps({"ok": False, "error": f"{error}; rollback failed: {rollback_error}"}))
            return
        print(json.dumps({"ok": False, "error": str(error), "rolledBack": True}))


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    query_parser = subparsers.add_parser("query")
    query_parser.add_argument("mimes", nargs="+")
    apply_parser = subparsers.add_parser("apply")
    apply_parser.add_argument("desktop_id")
    apply_parser.add_argument("mimes", nargs="+")
    args = parser.parse_args()
    if args.command == "query":
        query(args.mimes)
    else:
        apply(args.desktop_id, args.mimes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
