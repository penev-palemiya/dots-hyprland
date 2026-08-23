pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Page-lazy, normalized common MIME inventory. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/mime_type_inventory.py`)
    property list<var> items: []
    property bool loading: false
    property bool ready: false
    property string error: ""
    signal refreshed(bool success)

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;
        root.ready = false;
        root.error = "";
        inventoryProc.running = true;
    }

    function parse(text) {
        try {
            const data = JSON.parse(text || "{}");
            root.items = data.items || [];
            root.ready = true;
            root.refreshed(true);
        } catch (exception) {
            root.items = [];
            root.error = Translation.tr("Could not read file type information.");
            root.refreshed(false);
        }
    }

    Process {
        id: inventoryProc
        command: ["python3", root.helperPath]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && root.error.length === 0) root.error = text.trim()
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.ready) {
                root.error = root.error || Translation.tr("Could not read file type information.");
                root.refreshed(false);
            }
        }
    }
}
