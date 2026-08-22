#!/usr/bin/env python3
"""Read-only libcups snapshot for Devices -> Printers."""
import ctypes
import json
import os
import socket
import sys
from urllib.parse import urlsplit, urlunsplit


class CupsOption(ctypes.Structure):
    _fields_ = [("name", ctypes.c_char_p), ("value", ctypes.c_char_p)]


class CupsDest(ctypes.Structure):
    _fields_ = [
        ("name", ctypes.c_char_p),
        ("instance", ctypes.c_char_p),
        ("is_default", ctypes.c_int),
        ("num_options", ctypes.c_int),
        ("options", ctypes.POINTER(CupsOption)),
    ]


class CupsJob(ctypes.Structure):
    _fields_ = [
        ("id", ctypes.c_int),
        ("dest", ctypes.c_char_p),
        ("title", ctypes.c_char_p),
        ("user", ctypes.c_char_p),
        ("format", ctypes.c_char_p),
        ("state", ctypes.c_int),
        ("size", ctypes.c_int),
        ("priority", ctypes.c_int),
        ("completed_time", ctypes.c_long),
        ("creation_time", ctypes.c_long),
        ("processing_time", ctypes.c_long),
    ]


def text(value):
    if not value:
        return ""
    return value.decode("utf-8", "replace") if isinstance(value, bytes) else str(value)


def option_map(dest):
    return {
        text(dest.options[index].name): text(dest.options[index].value)
        for index in range(dest.num_options)
        if dest.options[index].name
    }


def bool_value(value, default=True):
    if value is None or value == "":
        return default
    return str(value).lower() not in {"0", "false", "no", "off"}


def safe_uri(uri):
    """Remove credentials before exposing a device URI to QML or logs."""
    if not uri:
        return ""
    try:
        parsed = urlsplit(uri)
        if not parsed.scheme or not parsed.netloc:
            return uri.split("@", 1)[-1] if "@" in uri else uri
        host = parsed.hostname or ""
        if parsed.port:
            host = f"{host}:{parsed.port}"
        return urlunsplit((parsed.scheme, host, parsed.path, parsed.query, parsed.fragment))
    except (ValueError, TypeError):
        return uri.split("@", 1)[-1] if "@" in uri else uri


def normalized_state(value, reason=""):
    raw = str(value or "").lower()
    if raw in {"3", "idle", "ready"}:
        return "Ready"
    if raw in {"4", "processing", "printing"}:
        return "Printing"
    if raw in {"5", "stopped", "paused"}:
        return "Paused"
    if any(word in raw for word in ("offline", "unreachable", "no\u002daccess")):
        return "Offline"
    if any(word in raw for word in ("error", "fatal", "reject")):
        return "Error"
    # IPP printer-state is idle=3, processing=4, stopped=5.
    if raw.isdigit():
        return {"3": "Ready", "4": "Printing", "5": "Paused"}.get(raw, "Unknown")
    if reason and any(word in reason.lower() for word in ("offline", "unavailable")):
        return "Offline"
    return "Unknown"


def printer_from_fixture(item, default_name=""):
    options = item.get("options", item)
    queue = str(item.get("id") or item.get("name") or options.get("printer-name") or "")
    reason = str(options.get("printer-state-reasons") or "")
    return {
        "id": queue,
        "name": queue,
        "displayName": str(item.get("displayName") or options.get("printer-info") or queue),
        "model": str(item.get("model") or options.get("printer-make-and-model") or ""),
        "deviceUri": safe_uri(str(item.get("deviceUri") or options.get("device-uri") or "")),
        "state": normalized_state(options.get("printer-state"), reason),
        "accepting": bool_value(options.get("printer-is-accepting-jobs"), True),
        "enabled": bool_value(options.get("printer-state"), True),
        "isDefault": queue == default_name,
        "jobCount": int(item.get("jobCount", options.get("job-count", 0)) or 0),
    }


def server_reachable():
    server = os.environ.get("CUPS_SERVER", "").strip()
    if server:
        host, _, port = server.rpartition(":")
        if not host:
            host, port = server, "631"
        try:
            with socket.create_connection((host, int(port or 631)), timeout=0.5):
                return True
        except OSError:
            return False
    for path in ("/run/cups/cups.sock", "/var/run/cups/cups.sock"):
        if os.path.exists(path):
            return True
    try:
        with socket.create_connection(("127.0.0.1", 631), timeout=0.5):
            return True
    except OSError:
        return False


def snapshot():
    try:
        cups = ctypes.CDLL("libcups.so.2")
    except OSError as error:
        return {"serverAvailable": False, "printers": [], "defaultPrinter": "", "error": "libcups unavailable"}

    cups.cupsGetDests.argtypes = [ctypes.POINTER(ctypes.POINTER(CupsDest))]
    cups.cupsGetDests.restype = ctypes.c_int
    cups.cupsFreeDests.argtypes = [ctypes.c_int, ctypes.POINTER(CupsDest)]
    cups.cupsGetDefault.restype = ctypes.c_char_p
    cups.cupsGetJobs.argtypes = [ctypes.POINTER(ctypes.POINTER(CupsJob)), ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
    cups.cupsGetJobs.restype = ctypes.c_int
    cups.cupsFreeJobs.argtypes = [ctypes.c_int, ctypes.POINTER(CupsJob)]

    destinations = ctypes.POINTER(CupsDest)()
    count = cups.cupsGetDests(ctypes.byref(destinations))
    available = server_reachable() or count > 0
    if not available:
        return {"serverAvailable": False, "printers": [], "defaultPrinter": "", "error": ""}

    default_name = text(cups.cupsGetDefault())
    printers = []
    for index in range(max(count, 0)):
        dest = destinations[index]
        options = option_map(dest)
        queue = text(dest.name)
        jobs = ctypes.POINTER(CupsJob)()
        job_count = cups.cupsGetJobs(ctypes.byref(jobs), queue.encode(), 0, 0)
        if job_count > 0:
            cups.cupsFreeJobs(job_count, jobs)
        item = printer_from_fixture({"id": queue, "options": options, "jobCount": max(job_count, 0)}, default_name)
        printers.append(item)
    cups.cupsFreeDests(count, destinations)
    return {"serverAvailable": True, "printers": printers, "defaultPrinter": default_name, "error": ""}


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--fixture":
        fixture = json.loads(sys.stdin.read())
        default_name = str(fixture.get("defaultPrinter") or "")
        result = {
            "serverAvailable": True,
            "defaultPrinter": default_name,
            "printers": [printer_from_fixture(item, default_name) for item in fixture.get("printers", [])],
            "error": "",
        }
    else:
        result = snapshot()
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
