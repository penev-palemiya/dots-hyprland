pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal backlightChanged()

    property string deviceName: ""
    property string brightnessPath: ""
    property string hardwareBrightnessPath: ""
    property string maxBrightnessPath: ""
    property int brightness: 0
    property int maxBrightness: 0
    readonly property real value: maxBrightness > 0 ? brightness / maxBrightness : 0
    readonly property bool available: deviceName.length > 0 && maxBrightness > 0

    function load() {
        discoverProc.running = true;
    }

    function refresh() {
        if (!available)
            discoverProc.running = true;
        else
            readSysfs();
    }

    function updateBrightness(nextBrightness, nextMaxBrightness = root.maxBrightness, notify = true) {
        if (Number.isNaN(nextBrightness) || Number.isNaN(nextMaxBrightness))
            return;
        const changed = root.brightness !== nextBrightness || root.maxBrightness !== nextMaxBrightness;
        root.brightness = nextBrightness;
        root.maxBrightness = nextMaxBrightness;
        if (notify && changed)
            root.backlightChanged();
    }

    function readSysfs(notify = true) {
        if (brightnessPath.length === 0 || maxBrightnessPath.length === 0)
            return;
        brightnessFile.reload();
        maxBrightnessFile.reload();
        updateBrightness(Number(brightnessFile.text().trim()), Number(maxBrightnessFile.text().trim()), notify);
    }

    function readHardwareSysfs() {
        if (hardwareBrightnessPath.length === 0 || maxBrightnessPath.length === 0)
            return;
        hardwareBrightnessFile.reload();
        maxBrightnessFile.reload();
        updateBrightness(Number(hardwareBrightnessFile.text().trim()), Number(maxBrightnessFile.text().trim()));
    }

    function setBrightness(value) {
        if (!available)
            return;
        const next = Math.max(0, Math.min(root.maxBrightness, Math.round(value)));
        root.updateBrightness(next);
        setProc.exec(["brightnessctl", "--class", "leds", "--device", root.deviceName, "s", `${next}`, "--quiet"]);
    }

    function increaseBrightness() {
        if (!available) {
            root.refresh();
            return;
        }
        root.setBrightness(root.brightness + 1);
    }

    function decreaseBrightness() {
        if (!available) {
            root.refresh();
            return;
        }
        root.setBrightness(root.brightness - 1);
    }

    function cycleBrightness() {
        if (!available) {
            root.refresh();
            return;
        }
        root.setBrightness(root.brightness >= root.maxBrightness ? 0 : root.brightness + 1);
    }

    function statusText() {
        return `available=${root.available} device=${root.deviceName || "-"} brightness=${root.brightness}/${root.maxBrightness} value=${Math.round(root.value * 100)}% brightnessPath=${root.brightnessPath || "-"} hardwareBrightnessPath=${root.hardwareBrightnessPath || "-"}`;
    }

    Process {
        id: discoverProc
        running: true
        command: ["sh", "-c", "brightnessctl --list | sed -n \"s/^Device '\\([^']*kbd_backlight[^']*\\)' of class 'leds':/\\1/p\" | head -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                const output = text.trim();
                if (output.length > 0) {
                    root.deviceName = output;
                    root.brightnessPath = `/sys/class/leds/${output}/brightness`;
                    root.hardwareBrightnessPath = `/sys/class/leds/${output}/brightness_hw_changed`;
                    root.maxBrightnessPath = `/sys/class/leds/${output}/max_brightness`;
                    readProc.running = true;
                }
            }
        }
    }

    Process {
        id: readProc
        command: ["sh", "-c", `brightnessctl --class leds --device '${root.deviceName}' g && brightnessctl --class leds --device '${root.deviceName}' m`]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split(/\n/);
                if (lines.length < 2)
                    return;
                root.updateBrightness(Number(lines[0]), Number(lines[1]), false);
            }
        }
    }

    FileView {
        id: brightnessFile
        path: root.brightnessPath
        watchChanges: true
        onFileChanged: root.readSysfs()
    }

    FileView {
        id: hardwareBrightnessFile
        path: root.hardwareBrightnessPath
        watchChanges: true
        onFileChanged: root.readHardwareSysfs()
    }

    FileView {
        id: maxBrightnessFile
        path: root.maxBrightnessPath
    }

    // ASUS updates the sysfs brightness value for Fn-key changes, but this
    // LED node does not consistently emit inotify events. Re-reading one tiny
    // sysfs file is cheaper and more reliable than spawning brightnessctl.
    Timer {
        interval: 250
        running: root.available
        repeat: true
        onTriggered: root.readSysfs()
    }

    Process {
        id: setProc

        onExited: root.readSysfs(false)
    }

    IpcHandler {
        target: "keyboardBacklight"
        property bool available: root.available
        property string deviceName: root.deviceName
        property int brightness: root.brightness
        property int maxBrightness: root.maxBrightness
        property real value: root.value

        function increase(): void {
            root.increaseBrightness();
        }

        function decrease(): void {
            root.decreaseBrightness();
        }

        function cycle(): void {
            root.cycleBrightness();
        }

        function refresh(): void {
            root.refresh();
        }

        function status(): string {
            return root.statusText();
        }
    }
}
