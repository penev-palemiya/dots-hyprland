pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Read-only normalized CUPS model for Devices → Printers. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/printers.py`)
    property bool serverAvailable: false
    property bool loading: false
    property string error: ""
    property list<var> printers: []
    property string defaultPrinter: ""
    signal refreshed(bool success)

    function refresh() {
        if (root.loading) return;
        root.loading = true;
        root.error = "";
        snapshotProc.running = true;
    }

    Process {
        id: snapshotProc
        command: ["python3", root.helperPath]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    root.serverAvailable = Boolean(result.serverAvailable);
                    root.printers = result.printers || [];
                    root.defaultPrinter = String(result.defaultPrinter || "");
                    root.error = String(result.error || "");
                    root.refreshed(true);
                } catch (exception) {
                    root.serverAvailable = false;
                    root.printers = [];
                    root.defaultPrinter = "";
                    root.error = Translation.tr("Could not read the printing service.");
                    root.refreshed(false);
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) root.error = text.trim() }
        onExited: code => {
            root.loading = false;
            if (code !== 0) {
                root.serverAvailable = false;
                root.printers = [];
                root.defaultPrinter = "";
                root.error = root.error || Translation.tr("Could not read the printing service.");
                root.refreshed(false);
            }
        }
    }
}
