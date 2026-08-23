pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/autostart.py`)
    readonly property string userAutostartPath: `${Directories.config}/autostart`
    property var entries: []
    property bool loading: false
    property bool applying: false
    property bool ready: false
    property string error: ""
    property int revision: 0
    property bool pendingRefresh: false
    property bool lastMutationOk: false

    signal changed(bool success)

    function refresh(force = false) {
        if (root.loading) {
            if (force)
                root.pendingRefresh = true;
            return;
        }
        if (root.applying) {
            root.pendingRefresh = true;
            return;
        }
        root.loading = true;
        listProc.command = ["python3", root.helperPath, "list"];
        listProc.running = true;
    }

    function toggle(entry, enabled) {
        if (root.loading || root.applying || !entry?.basename)
            return;
        root.applying = true;
        root.lastMutationOk = false;
        mutationProc.command = ["python3", root.helperPath, "toggle", entry.basename, enabled ? "true" : "false"];
        mutationProc.running = true;
    }

    function add(desktopId) {
        if (root.loading || root.applying || !desktopId)
            return;
        root.applying = true;
        root.lastMutationOk = false;
        mutationProc.command = ["python3", root.helperPath, "add", desktopId];
        mutationProc.running = true;
    }

    function remove(entry) {
        if (root.loading || root.applying || !entry?.basename)
            return;
        root.applying = true;
        root.lastMutationOk = false;
        mutationProc.command = ["python3", root.helperPath, "remove", entry.basename];
        mutationProc.running = true;
    }

    function applyResult(text) {
        try {
            const result = JSON.parse(text);
            if (!result.ok) {
                root.error = Translation.tr("Could not change startup applications.");
                return false;
            }
            root.entries = result.entries || [];
            root.ready = true;
            root.revision++;
            root.error = "";
            return true;
        } catch (exception) {
            root.error = Translation.tr("Could not read startup applications.");
            return false;
        }
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const success = root.applyResult(text);
                root.changed(success);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.error = text.trim();
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.error)
                root.error = Translation.tr("Could not read startup applications.");
        }
    }

    Process {
        id: mutationProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.lastMutationOk = !!result.ok;
                    if (!root.lastMutationOk)
                        root.error = Translation.tr("Could not change startup applications.");
                } catch (exception) {
                    root.lastMutationOk = false;
                    root.error = Translation.tr("Could not change startup applications.");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.error = text.trim();
        }
        onExited: code => {
            root.applying = false;
            if (code === 0 && root.lastMutationOk) {
                root.pendingRefresh = false;
                root.refresh(true);
            } else if (code !== 0 && !root.error) {
                root.error = Translation.tr("Could not change startup applications.");
                root.changed(false);
            }
        }
    }

    Connections {
        target: root
        function onPendingRefreshChanged() {
            if (root.pendingRefresh && !root.loading && !root.applying)
                root.refresh(true);
        }
    }

}
