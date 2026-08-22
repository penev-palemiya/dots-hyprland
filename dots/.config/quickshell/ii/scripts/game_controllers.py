#!/usr/bin/env python3
"""SDL3 gamepad/joystick event bridge for Settings (read-only)."""
import ctypes
import json
import os
import queue
import signal
import sys
import threading

SDL = ctypes.CDLL("libSDL3.so.0")

class GUID(ctypes.Structure):
    _fields_ = [("data", ctypes.c_uint8 * 16)]

class Event(ctypes.Structure):
    _fields_ = [("type", ctypes.c_uint32), ("reserved", ctypes.c_uint32), ("timestamp", ctypes.c_uint64), ("which", ctypes.c_int32), ("a", ctypes.c_uint8), ("b", ctypes.c_uint8), ("c", ctypes.c_uint8), ("d", ctypes.c_uint8), ("value", ctypes.c_int16), ("padding", ctypes.c_uint16), ("tail", ctypes.c_uint8 * 96)]

SDL.SDL_Init.argtypes = [ctypes.c_uint32]
SDL.SDL_Init.restype = ctypes.c_bool
SDL.SDL_Quit.argtypes = []
SDL.SDL_GetError.restype = ctypes.c_char_p
SDL.SDL_GetJoysticks.argtypes = [ctypes.POINTER(ctypes.c_int)]
SDL.SDL_GetJoysticks.restype = ctypes.POINTER(ctypes.c_int32)
SDL.SDL_IsGamepad.argtypes = [ctypes.c_int32]
SDL.SDL_IsGamepad.restype = ctypes.c_bool
SDL.SDL_GetJoystickNameForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetJoystickNameForID.restype = ctypes.c_char_p
SDL.SDL_GetJoystickPathForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetJoystickPathForID.restype = ctypes.c_char_p
SDL.SDL_GetJoystickGUIDForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetJoystickGUIDForID.restype = GUID
SDL.SDL_GetJoystickVendorForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetJoystickVendorForID.restype = ctypes.c_uint16
SDL.SDL_GetJoystickProductForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetJoystickProductForID.restype = ctypes.c_uint16
SDL.SDL_GetGamepadTypeForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetGamepadTypeForID.restype = ctypes.c_int
SDL.SDL_GetGamepadMappingForID.argtypes = [ctypes.c_int32]
SDL.SDL_GetGamepadMappingForID.restype = ctypes.c_char_p
SDL.SDL_OpenGamepad.argtypes = [ctypes.c_int32]
SDL.SDL_OpenGamepad.restype = ctypes.c_void_p
SDL.SDL_CloseGamepad.argtypes = [ctypes.c_void_p]
SDL.SDL_GetGamepadAxis.argtypes = [ctypes.c_void_p, ctypes.c_int]
SDL.SDL_GetGamepadAxis.restype = ctypes.c_int16
SDL.SDL_GetGamepadButton.argtypes = [ctypes.c_void_p, ctypes.c_int]
SDL.SDL_GetGamepadButton.restype = ctypes.c_bool
SDL.SDL_GetGamepadPowerInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)]
SDL.SDL_GetGamepadPowerInfo.restype = ctypes.c_int
SDL.SDL_WaitEvent.argtypes = [ctypes.POINTER(Event)]
SDL.SDL_WaitEvent.restype = ctypes.c_bool
SDL.SDL_PushEvent.argtypes = [ctypes.POINTER(Event)]
SDL.SDL_PushEvent.restype = ctypes.c_bool
SDL.SDL_free.argtypes = [ctypes.c_void_p]

INIT_GAMEPAD = 0x00002000
EVENT_AXIS = 0x650
EVENT_BUTTON_DOWN = 0x651
EVENT_BUTTON_UP = 0x652
EVENT_ADDED = 0x653
EVENT_REMOVED = 0x654
EVENT_REMAPPED = 0x655
EVENT_COMMAND = 0x8000
AXES = ("leftX", "leftY", "rightX", "rightY", "leftTrigger", "rightTrigger")
BUTTONS = ("south", "east", "west", "north", "back", "guide", "start", "leftStick", "rightStick", "leftShoulder", "rightShoulder", "dpadUp", "dpadDown", "dpadLeft", "dpadRight")


def s(value):
    return value.decode("utf-8", "replace") if value else ""


def normalize_stick(value):
    return max(-1.0, min(1.0, float(value) / 32767.0))


def normalize_trigger(value):
    return max(0.0, min(1.0, float(value) / 32767.0))


def transport(path):
    if not path:
        return ""
    real = os.path.realpath(path)
    lower = real.lower()
    if "bluetooth" in lower:
        return "Bluetooth"
    if "/usb" in lower or "usb" in lower:
        return "USB"
    if "receiver" in lower or "dongle" in lower:
        return "Wireless receiver"
    return "Unknown"


def type_name(value):
    return {
        1: "Generic Gamepad", 2: "Xbox 360", 3: "Xbox One", 4: "PlayStation 3",
        5: "PlayStation 4", 6: "PlayStation 5", 7: "Nintendo Switch Pro",
        11: "GameCube",
    }.get(value, "Generic Gamepad" if value else "Joystick")


def controller(runtime_id):
    name = s(SDL.SDL_GetJoystickNameForID(runtime_id)) or "Controller"
    path = s(SDL.SDL_GetJoystickPathForID(runtime_id))
    mapped = bool(SDL.SDL_IsGamepad(runtime_id))
    guid = bytes(SDL.SDL_GetJoystickGUIDForID(runtime_id).data).hex()
    mapping = s(SDL.SDL_GetGamepadMappingForID(runtime_id)) if mapped else ""
    return {
        "runtimeId": int(runtime_id), "name": name, "guid": guid,
        "vendorId": int(SDL.SDL_GetJoystickVendorForID(runtime_id)),
        "productId": int(SDL.SDL_GetJoystickProductForID(runtime_id)),
        "type": type_name(SDL.SDL_GetGamepadTypeForID(runtime_id)) if mapped else "Joystick",
        "transport": transport(path), "mapped": mapped, "connected": True,
        "batteryAvailable": False, "battery": -1, "powerState": "",
        "mapping": "Standard gamepad mapping" if mapped else "Controller mapping unavailable",
        "_path": path, "_mapping": mapping,
    }


def is_virtual(item):
    value = f"{item['name']} {item['_path']}".lower()
    return any(word in value for word in ("keyd", "ydotool", "virtual"))


def list_controllers():
    count = ctypes.c_int(0)
    pointer = SDL.SDL_GetJoysticks(ctypes.byref(count))
    result = []
    if pointer:
        for index in range(max(0, count.value)):
            item = controller(pointer[index])
            if not is_virtual(item):
                item.pop("_path", None); item.pop("_mapping", None)
                result.append(item)
        SDL.SDL_free(pointer)
    return result


def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def read_commands(commands):
    for line in sys.stdin:
        try:
            commands.put(json.loads(line))
            event = Event(); event.type = EVENT_COMMAND
            SDL.SDL_PushEvent(ctypes.byref(event))
        except (json.JSONDecodeError, OSError):
            continue


def tester_state(gamepad):
    if not gamepad:
        return {"axes": {axis: 0 for axis in AXES}, "buttons": {button: False for button in BUTTONS}}
    axes = {}
    for index, axis in enumerate(AXES):
        value = SDL.SDL_GetGamepadAxis(gamepad, index)
        axes[axis] = normalize_trigger(value) if index >= 4 else normalize_stick(value)
    return {"axes": axes, "buttons": {button: bool(SDL.SDL_GetGamepadButton(gamepad, index)) for index, button in enumerate(BUTTONS)}}


def run():
    if not SDL.SDL_Init(INIT_GAMEPAD):
        emit({"kind": "error", "error": "SDL3 gamepad backend unavailable: " + s(SDL.SDL_GetError())})
        return 1
    commands = queue.Queue()
    def stop_signal(_signum, _frame):
        commands.put({"command": "quit"})
        event = Event(); event.type = EVENT_COMMAND
        SDL.SDL_PushEvent(ctypes.byref(event))
    signal.signal(signal.SIGTERM, stop_signal)
    signal.signal(signal.SIGINT, stop_signal)
    threading.Thread(target=read_commands, args=(commands,), daemon=True).start()
    selected = None
    gamepad = None
    emit({"kind": "ready", "controllers": list_controllers()})
    try:
        while True:
            event = Event()
            if not SDL.SDL_WaitEvent(ctypes.byref(event)):
                continue
            if event.type == EVENT_COMMAND:
                while not commands.empty():
                    command = commands.get_nowait()
                    if command.get("command") == "quit":
                        return 0
                    if command.get("command") == "select":
                        selected = int(command.get("runtimeId", -1))
                        if gamepad: SDL.SDL_CloseGamepad(gamepad); gamepad = None
                        if selected >= 0 and SDL.SDL_IsGamepad(selected):
                            gamepad = SDL.SDL_OpenGamepad(selected)
                            if gamepad:
                                percent = ctypes.c_int(-1)
                                power = SDL.SDL_GetGamepadPowerInfo(gamepad, ctypes.byref(percent))
                                emit({"kind": "selected", "runtimeId": selected, "state": tester_state(gamepad), "batteryAvailable": percent.value >= 0, "battery": percent.value if percent.value >= 0 else -1, "powerState": str(power)})
                        else:
                            emit({"kind": "selected", "runtimeId": selected, "state": tester_state(None)})
                    if command.get("command") == "deselect":
                        selected = None
                        if gamepad: SDL.SDL_CloseGamepad(gamepad); gamepad = None
                continue
            if event.type in (EVENT_ADDED, EVENT_REMAPPED):
                items = list_controllers(); emit({"kind": "controllers", "controllers": items})
            elif event.type == EVENT_REMOVED:
                if selected == event.which:
                    selected = None
                    if gamepad: SDL.SDL_CloseGamepad(gamepad); gamepad = None
                    emit({"kind": "selectedRemoved", "runtimeId": event.which})
                emit({"kind": "controllers", "controllers": list_controllers()})
            elif event.type in (EVENT_AXIS, EVENT_BUTTON_DOWN, EVENT_BUTTON_UP) and selected == event.which and gamepad:
                emit({"kind": "input", "runtimeId": selected, "state": tester_state(gamepad)})
    finally:
        if gamepad: SDL.SDL_CloseGamepad(gamepad)
        SDL.SDL_Quit()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        assert normalize_stick(-32768) == -1.0
        assert normalize_stick(32767) == 1.0
        assert normalize_trigger(-32768) == 0.0
        assert normalize_trigger(32767) == 1.0
        print(json.dumps({"ok": True, "axes": AXES, "buttons": BUTTONS}))
        return 0
    try:
        return run()
    except OSError as error:
        emit({"kind": "error", "error": str(error)})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
