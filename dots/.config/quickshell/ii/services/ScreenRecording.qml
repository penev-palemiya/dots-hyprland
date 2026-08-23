pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string runtimeStatePath: Directories.screenRecordingStatePath
    readonly property string scriptPath: Directories.recordScriptPath
    property bool active: false
    property int startedAt: 0
    property string mode: ""
    property bool withSystemAudio: false
    property string outputPath: ""
    property string lastError: ""
    property bool runtimeReady: false
    property int elapsedSeconds: active && startedAt > 0 ? Math.max(0, Math.floor(Date.now() / 1000) - startedAt) : 0

    signal stateChangedExternally()

    function normalizeDirectory(path) {
        let value = String(path ?? "").trim();
        if (value.startsWith("file://"))
            value = value.slice(7);
        while (value.length > 1 && value.endsWith("/"))
            value = value.slice(0, -1);
        return value;
    }

    function migrateLegacyDirectory() {
        if (!Config.ready)
            return;
        const legacy = normalizeDirectory(Config.options.screenRecord.savePath);
        if (legacy.length > 0) {
            Config.options.screenRecord.saveDirectory = legacy;
            Config.options.screenRecord.savePath = "";
        }
    }

    function clearState() {
        root.active = false;
        root.startedAt = 0;
        root.mode = "";
        root.withSystemAudio = false;
        root.outputPath = "";
        root.elapsedSeconds = 0;
    }

    function parseState(text) {
        const values = {};
        String(text ?? "").split("\n").forEach(line => {
            const separator = line.indexOf("=");
            if (separator > 0)
                values[line.slice(0, separator)] = line.slice(separator + 1);
        });
        if (values.active === "0" || !values.pid) {
            root.clearState();
            return;
        }
        root.active = true;
        root.startedAt = Number(values.started_at || 0);
        root.mode = values.mode || "";
        root.withSystemAudio = values.system_audio === "1";
        root.outputPath = values.output_path || "";
        root.elapsedSeconds = root.startedAt > 0 ? Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt) : 0;
    }

    function refreshState() {
        stateFile.reload();
    }

    function start(mode = "region", withAudio = false, region = "") {
        if (root.active) {
            root.lastError = "A recording is already active.";
            return false;
        }
        root.lastError = "";
        let command = [root.scriptPath, "start"];
        if (mode === "monitor")
            command.push("--fullscreen");
        else if (region.length > 0)
            command.push("--region", region);
        if (withAudio)
            command.push("--sound");
        Quickshell.execDetached(command);
        return true;
    }

    function stop() {
        if (!root.active) {
            root.lastError = "";
            return false;
        }
        root.lastError = "";
        controlProcess.command = [root.scriptPath, "stop"];
        controlProcess.running = true;
        return true;
    }

    function toggle(mode = "region", withAudio = false, region = "") {
        return root.active ? root.stop() : root.start(mode, withAudio, region);
    }

    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.elapsedSeconds = root.startedAt > 0
            ? Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt) : 0
    }

    FileView {
        id: stateFile
        path: root.runtimeReady ? root.runtimeStatePath : ""
        watchChanges: root.runtimeReady
        onFileChanged: root.refreshState()
        onLoaded: root.parseState(stateFile.text())
        onLoadFailed: root.clearState()
    }

    Process {
        id: runtimeInit
        command: ["bash", "-c", `mkdir -p '${root.runtimeStatePath.substring(0, root.runtimeStatePath.lastIndexOf("/"))}' && if [ ! -e '${root.runtimeStatePath}' ]; then printf 'active=0\\n' > '${root.runtimeStatePath}'; chmod 600 '${root.runtimeStatePath}'; fi`]
        onExited: (exitCode) => root.runtimeReady = (exitCode === 0)
        running: true
    }

    Process {
        id: controlProcess
        command: []
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.lastError = text.trim();
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.lastError.length === 0)
                root.lastError = "Recording operation failed.";
            root.refreshState();
        }
    }

    Process {
        id: statusProcess
        command: [root.scriptPath, "status"]
        stdout: StdioCollector {
            onStreamFinished: root.parseState(text)
        }
        stderr: StdioCollector {}
        running: true
    }

    Component.onCompleted: root.migrateLegacyDirectory()
    Connections {
        target: Config
        function onReadyChanged() { root.migrateLegacyDirectory(); }
    }
}
