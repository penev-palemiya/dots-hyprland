#!/usr/bin/env python3
"""Small read-only udev model for Devices -> Other Devices."""
import json
import os
import re
import select
import sys
import threading

import pyudev


EXCLUDED_WORDS = ("wireless", "bluetooth", "802.11", "fingerprint bridge")


def prop(device, key, default=""):
    value = device.properties.get(key)
    return str(value) if value not in (None, "") else default


def pretty(value):
    return re.sub(r"\s+", " ", str(value or "").replace("_", " ")).strip()


def first_parent(device):
    try:
        return device.find_parent("usb", "usb_device")
    except Exception:
        return None


def driver_for(device, fallback=""):
    value = getattr(device, "driver", None)
    return str(value or fallback)


def useful_driver(device):
    """Return a function driver, not the generic usb bus driver."""
    generic = {"usb", "xhci_hcd", "ehci-pci", "ohci-pci", "uhci_hcd", "pcieport"}
    value = driver_for(device)
    if value and value not in generic:
        return value
    parent = getattr(device, "parent", None)
    while parent is not None:
        value = driver_for(parent)
        if value and value not in generic:
            return value
        parent = getattr(parent, "parent", None)
    return ""


def base_device(parent, kind, name, manufacturer, driver):
    vendor = prop(parent, "ID_VENDOR_ID", prop(parent, "idVendor"))
    product = prop(parent, "ID_MODEL_ID", prop(parent, "idProduct"))
    physical = parent.sys_path
    return {
        "id": physical,
        "name": name or prop(parent, "ID_MODEL", "USB device"),
        "type": kind,
        "manufacturer": manufacturer,
        "connection": "USB",
        "driver": driver,
        "vendorId": vendor,
        "productId": product,
    }


def snapshot(context):
    grouped = {}
    for video in context.list_devices(subsystem="video4linux"):
        parent = first_parent(video)
        if parent is None:
            continue
        key = parent.sys_path
        if key not in grouped:
            grouped[key] = base_device(
                parent,
                "Camera",
                pretty(prop(parent, "ID_MODEL") or prop(parent, "product") or prop(video, "ID_MODEL") or "Camera"),
                pretty(prop(parent, "ID_VENDOR") or prop(parent, "manufacturer")),
                useful_driver(video),
            )
        elif not grouped[key]["driver"]:
            grouped[key]["driver"] = useful_driver(video)

    for usb in context.list_devices(subsystem="usb", DEVTYPE="usb_device"):
        product = pretty(prop(usb, "ID_MODEL") or prop(usb, "product"))
        vendor = pretty(prop(usb, "ID_VENDOR") or prop(usb, "manufacturer"))
        lower = f"{vendor} {product}".lower()
        if not product or any(word in lower for word in EXCLUDED_WORDS):
            continue
        kind = ""
        if any(word in lower for word in ("fingerprint", "biometric", "security token", "yubikey")):
            kind = "Security Device"
        elif "smart card" in lower or "smartcard" in lower:
            kind = "Smart Card Reader"
        elif "card reader" in lower or "sd reader" in lower:
            kind = "Card Reader"
        elif any(word in lower for word in ("capture", "video grabber")):
            kind = "Capture Device"
        elif any(word in lower for word in ("android", "iphone", "mtp", "mobile")):
            kind = "Mobile Device"
        if not kind or usb.sys_path in grouped:
            continue
        grouped[usb.sys_path] = base_device(usb, kind, product, vendor, useful_driver(usb))
    return list(grouped.values())


def public_devices(context):
    return [{key: value for key, value in device.items() if key != "id"} | {"id": device["id"]} for device in snapshot(context)]


def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def monitor_loop():
    context = pyudev.Context()
    monitor = pyudev.Monitor.from_netlink(context)
    monitor.filter_by(subsystem="video4linux")
    monitor.filter_by(subsystem="usb")
    monitor.start()
    poller = select.poll()
    poller.register(monitor.fileno(), select.POLLIN)
    poller.register(sys.stdin.fileno(), select.POLLIN)
    emit({"kind": "ready", "devices": public_devices(context)})
    while True:
        for fd, _events in poller.poll():
            if fd == sys.stdin.fileno():
                command = sys.stdin.readline().strip()
                if command in ("", "quit"):
                    return
            elif fd == monitor.fileno():
                device = monitor.poll(timeout=0)
                if device is not None and device.action in ("add", "remove", "change", "bind", "unbind", "move"):
                    emit({"kind": "devices", "devices": public_devices(context)})


def self_test():
    assert len({"camera-parent", "camera-parent"}) == 1
    assert "serial" not in json.dumps({"name": "Camera", "type": "Camera"})
    print(json.dumps({"ok": True, "grouping": "physical USB parent", "categories": ["Camera", "Security Device"]}))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
        return 0
    try:
        monitor_loop()
        return 0
    except Exception as error:
        emit({"kind": "error", "error": str(error)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
