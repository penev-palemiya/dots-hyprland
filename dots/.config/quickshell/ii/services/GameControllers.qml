pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** SDL3-backed gamepad model. It is acquired only by the Settings page. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/game_controllers.py`)
    property list<var> controllers: []
    property var selectedController: null
    property int selectedRuntimeId: -1
    property var testerState: ({ axes: {}, buttons: {} })
    property bool running: false
    property bool ready: false
    property string error: ""
    property bool stopping: false

    function start() {
        if (root.running) return;
        root.error = "";
        root.ready = false;
        root.stopping = false;
        controllerProc.running = true;
        root.running = true;
    }

    function stop() {
        if (!root.running) return;
        root.stopping = true;
        controllerProc.write(JSON.stringify({ command: "quit" }) + "\n");
        controllerProc.running = false;
        root.running = false;
        root.ready = false;
        root.controllers = [];
        root.selectedController = null;
        root.selectedRuntimeId = -1;
        root.testerState = ({ axes: {}, buttons: {} });
    }

    function select(runtimeId) {
        if (!root.running) root.start();
        root.selectedRuntimeId = Number(runtimeId);
        root.selectedController = root.controllers.find(controller => controller.runtimeId === root.selectedRuntimeId) || null;
        controllerProc.write(JSON.stringify({ command: "select", runtimeId: root.selectedRuntimeId }) + "\n");
    }

    function deselect() {
        if (root.running) controllerProc.write(JSON.stringify({ command: "deselect" }) + "\n");
        root.selectedController = null;
        root.selectedRuntimeId = -1;
        root.testerState = ({ axes: {}, buttons: {} });
    }

    function handleLine(line) {
        if (!line || !line.trim()) return;
        try {
            const event = JSON.parse(line);
            if (event.kind === "ready") {
                root.controllers = event.controllers || [];
                root.ready = true;
            } else if (event.kind === "controllers") {
                root.controllers = event.controllers || [];
                if (root.selectedRuntimeId >= 0)
                    root.selectedController = root.controllers.find(controller => controller.runtimeId === root.selectedRuntimeId) || null;
            } else if (event.kind === "selected") {
                root.testerState = event.state || ({ axes: {}, buttons: {} });
                if (root.selectedController) {
                    root.selectedController = Object.assign({}, root.selectedController, {
                        batteryAvailable: Boolean(event.batteryAvailable),
                        battery: Number(event.battery ?? -1),
                        powerState: String(event.powerState || "")
                    });
                }
            } else if (event.kind === "input") {
                if (Number(event.runtimeId) === root.selectedRuntimeId)
                    root.testerState = event.state || ({ axes: {}, buttons: {} });
            } else if (event.kind === "selectedRemoved") {
                root.deselect();
            } else if (event.kind === "error") {
                root.error = String(event.error || "SDL3 controller backend failed.");
            }
        } catch (exception) {
            root.error = "Malformed SDL3 controller event.";
        }
    }

    Process {
        id: controllerProc
        command: ["python3", root.helperPath]
        stdinEnabled: true
        stdout: SplitParser { onRead: line => root.handleLine(line) }
        stderr: SplitParser { onRead: line => { if (line.trim().length > 0) root.error = line.trim(); } }
        onExited: code => {
            root.running = false;
            if (code !== 0 && !root.stopping && root.error.length === 0)
                root.error = Translation.tr("SDL3 controller backend failed.");
        }
    }
}
