pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string helperPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/power/hypridle_power.py`
    property var values: ({ lock: 300, "dpms-off": 600, suspend: 900 })
    property bool ready: false
    property bool busy: false
    property string lastError: ""
    signal updated()

    function refresh() {
        if (busy)
            return;
        busy = true;
        operation = "read";
        command = ["python3", helperPath, "read"];
        process.running = true;
    }

    function apply(nextValues) {
        if (busy)
            return;
        busy = true;
        operation = "apply";
        command = ["python3", helperPath, "apply", JSON.stringify(nextValues)];
        process.running = true;
    }

    property string operation: ""
    property list<string> command: []

    Process {
        id: process
        command: root.command

        stdout: StdioCollector {
            id: output
            onStreamFinished: process.processOutput = output.text
        }

        property string processOutput: ""
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            try {
                const response = JSON.parse(processOutput.trim());
                if (exitCode !== 0 || !response.ok) {
                    root.lastError = response.error ?? `hypridle helper failed (${exitCode})`;
                    return;
                }
                root.lastError = "";
                root.values = response.values;
                root.ready = true;
                root.updated();
            } catch (error) {
                root.lastError = `Invalid hypridle helper response: ${error}`;
            }
        }
    }
}
