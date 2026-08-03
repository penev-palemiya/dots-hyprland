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

    // .reload() is asynchronous (see the `loaded` signal in Quickshell.Io) -
    // reading .text() in the same tick as calling it returns the *previous*
    // content, always one change behind. That was invisible while a 100ms
    // poll kept re-triggering it fast enough to "catch up" unnoticed, but
    // became a permanent, visible lag once the poll was removed in favor of
    // one read per real change. These two functions now only kick off the
    // reload; the actual read happens in each FileView's onLoaded below,
    // once the new content genuinely exists.
    property bool pendingBrightnessNotify: true

    function readSysfs(notify = true) {
        if (brightnessPath.length === 0 || maxBrightnessPath.length === 0)
            return;
        root.pendingBrightnessNotify = notify;
        brightnessFile.reload();
    }

    function readHardwareSysfs() {
        if (hardwareBrightnessPath.length === 0 || maxBrightnessPath.length === 0)
            return;
        hardwareBrightnessFile.reload();
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
        // Fires once the reload triggered by readSysfs() (or the initial
        // automatic load) has actually completed - this is the only place
        // .text() is guaranteed current.
        onLoaded: root.updateBrightness(Number(brightnessFile.text().trim()), Number(maxBrightnessFile.text().trim()), root.pendingBrightnessNotify)
    }

    FileView {
        id: hardwareBrightnessFile
        path: root.hardwareBrightnessPath
        watchChanges: true
        onFileChanged: root.readHardwareSysfs()
        onLoaded: root.updateBrightness(Number(hardwareBrightnessFile.text().trim()), Number(maxBrightnessFile.text().trim()))
    }

    FileView {
        id: maxBrightnessFile
        path: root.maxBrightnessPath
    }

    // No polling timer here on purpose - tested on real hardware (Fn+kbd-
    // illum key, physically pressed, 12s inotify watch on this exact LED's
    // brightness AND brightness_hw_changed, plus a fresh evtest capture of
    // "Asus WMI hotkeys": zero evdev event, zero inotify event, and the
    // sysfs brightness value itself didn't move at all). On this machine
    // the Fn key has no OS-visible effect whatsoever, so the old 100ms poll
    // was never catching anything real - it was pure overhead. The
    // interactive path (Fn key -> Hyprland keybind -> IpcHandler above)
    // already updates root.brightness the instant the key is pressed, and
    // brightnessFile's watchChanges above (plain inotify on a real write())
    // catches any *other* process changing the value on disk - standard,
    // reliable POSIX behavior, nothing exotic. If a different ASUS model
    // genuinely does move the LED via firmware without any OS-visible
    // write (the scenario the removed timer was guarding against), that
    // would need re-adding for that specific hardware - it doesn't apply
    // here.

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
