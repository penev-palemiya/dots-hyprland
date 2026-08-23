pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Page-lazy, read-only Flatpak and portal permission inventory. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/app_permissions.py`)
    property list<var> flatpakApps: []
    property list<var> portalEntries: []
    property list<var> stalePortalEntries: []
    property var portalHealth: ({})
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
        permissionProc.running = true;
    }

    function parse(text) {
        try {
            const data = JSON.parse(text || "{}");
            root.flatpakApps = data.apps || [];
            root.portalEntries = data.portalEntries || [];
            root.stalePortalEntries = data.stalePortalEntries || [];
            root.portalHealth = data.portalHealth || {};
            root.ready = true;
            root.refreshed(true);
        } catch (exception) {
            root.flatpakApps = [];
            root.portalEntries = [];
            root.stalePortalEntries = [];
            root.portalHealth = ({})
            root.error = Translation.tr("Permission information is unavailable.");
            root.refreshed(false);
        }
    }

    Process {
        id: permissionProc
        command: ["python3", root.helperPath]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && root.error.length === 0) root.error = text.trim()
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.ready) {
                root.error = root.error || Translation.tr("Could not read application permissions.");
                root.refreshed(false);
            }
        }
    }
}
