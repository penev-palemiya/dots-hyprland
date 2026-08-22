pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Narrow, read-only model of user-facing hardware outside dedicated pages. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/other_devices.py`)
    property list<var> devices: []
    property var selectedDevice: null
    property bool running: false
    property bool ready: false
    property string error: ""
    property bool stopping: false

    function start() {
        if (root.running) return;
        root.error = "";
        root.ready = false;
        root.stopping = false;
        monitorProc.running = true;
        root.running = true;
    }

    function stop() {
        if (!root.running) return;
        root.stopping = true;
        monitorProc.write("quit\n");
        monitorProc.running = false;
        root.running = false;
        root.ready = false;
        root.devices = [];
        root.selectedDevice = null;
    }

    function select(device) { root.selectedDevice = device; }

    function handleLine(line) {
        if (!line || !line.trim()) return;
        try {
            const event = JSON.parse(line);
            if (event.kind === "ready" || event.kind === "devices") {
                root.devices = event.devices || [];
                root.ready = true;
                if (root.selectedDevice)
                    root.selectedDevice = root.devices.find(device => device.id === root.selectedDevice.id) || null;
            } else if (event.kind === "error") {
                root.error = String(event.error || Translation.tr("Device monitor unavailable."));
            }
        } catch (exception) {
            root.error = Translation.tr("Malformed device monitor event.");
        }
    }

    Process {
        id: monitorProc
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.handleLine(line) }
        stderr: SplitParser { onRead: line => { if (line.trim().length > 0) root.error = line.trim(); } }
        onExited: code => {
            root.running = false;
            if (code !== 0 && !root.stopping && root.error.length === 0)
                root.error = Translation.tr("Device monitor unavailable.");
        }
    }
}
