pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

/** Authoritative Hyprland pointer/touchpad policy for Mouse & Touchpad. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/hyprland/pointer_settings.py`)
    property var state: ({})
    property list<var> devices: []
    readonly property list<var> userDevices: root.devices.filter(device => !/(keyd|ydotool|virtual|aux)/i.test(device.name))
    readonly property bool hasTouchpad: root.userDevices.some(device => device.type === "Touchpad")
    readonly property real sensitivity: Number(root.state.sensitivity ?? 0)
    readonly property string accelProfile: String(root.state.accel_profile || "adaptive")
    readonly property bool naturalScroll: Boolean(root.state.natural_scroll)
    readonly property bool touchpadNaturalScroll: Boolean(root.state.touchpad_natural_scroll)
    readonly property real touchpadScrollFactor: Number(root.state.touchpad_scroll_factor ?? 1)
    readonly property bool touchpadTapToClick: Boolean(root.state.touchpad_tap_to_click)
    readonly property bool touchpadTapAndDrag: Boolean(root.state.touchpad_tap_and_drag)
    readonly property bool touchpadDisableWhileTyping: Boolean(root.state.touchpad_disable_while_typing)
    readonly property bool touchpadClickfingerBehavior: Boolean(root.state.touchpad_clickfinger_behavior)
    readonly property bool touchpadMiddleButtonEmulation: Boolean(root.state.touchpad_middle_button_emulation)

    property bool ready: false
    property bool applying: false
    property string error: ""
    signal applied(bool success)

    function refresh() {
        if (!stateProc.running) stateProc.running = true;
        if (!deviceProc.running) deviceProc.running = true;
    }

    function applyState(nextState) {
        if (root.applying) return false;
        root.error = "";
        root.applying = true;
        applyProc.command = ["python3", root.helperPath, "--apply", JSON.stringify(nextState)];
        applyProc.running = true;
        return true;
    }

    function applyField(key, value) {
        const next = Object.assign({}, root.state);
        next[key] = value;
        return root.applyState(next);
    }

    Process {
        id: stateProc
        command: ["python3", root.helperPath, "--state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); root.ready = true; }
                catch (exception) { root.error = "Could not read Hyprland pointer settings."; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) root.error = text.trim() }
        onExited: code => { if (code !== 0) root.error = root.error || "Could not read Hyprland pointer settings."; }
    }

    Process {
        id: deviceProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mice = JSON.parse(text).mice || [];
                    root.devices = mice.map(mouse => ({
                        name: String(mouse.name || ""),
                        type: /touchpad/i.test(String(mouse.name || "")) ? "Touchpad" : "Mouse"
                    }));
                } catch (exception) { root.devices = []; }
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); }
                catch (exception) { if (text.trim().length > 0) root.error = text.trim(); }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) root.error = text.trim() }
        onExited: code => {
            root.applying = false;
            if (code !== 0 && root.error.length === 0) root.error = "Hyprland rejected the pointer settings.";
            root.applied(code === 0);
            if (code === 0) root.refresh();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["configreloaded", "deviceadded", "deviceremoved"].includes(event.name)) root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
