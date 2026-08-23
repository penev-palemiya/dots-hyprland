pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Lazy, read-only health snapshot. No work is performed until refresh(). */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/diagnostics.py`)
    property var checks: []
    property bool loading: false
    property bool ready: false
    property string error: ""
    readonly property int issueCount: root.checks.filter(item => root.isIssue(item)).length
    readonly property string overallState: root.issueCount > 0 ? "warning" : "healthy"
    readonly property string overallText: root.issueCount > 0
        ? Translation.tr("%1 issue(s) detected").arg(root.issueCount)
        : Translation.tr("All systems operational")

    function isIssue(item) {
        if (item.state === "error" || item.state === "warning")
            return true;
        return item.state === "unavailable" && ["Desktop portals", "Audio", "Network"].includes(item.name);
    }

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;
        root.ready = false;
        root.error = "";
        snapshotProc.running = true;
    }

    function parse(text) {
        try {
            const result = JSON.parse(text || "{}");
            if (result.ok !== true || !Array.isArray(result.checks))
                throw new Error("invalid diagnostics result");
            root.checks = result.checks;
            root.ready = true;
        } catch (exception) {
            root.checks = [];
            root.error = Translation.tr("Diagnostic snapshot is unavailable.");
        }
    }

    function stateLabel(state) {
        switch (state) {
        case "healthy": return Translation.tr("Healthy");
        case "warning": return Translation.tr("Warning");
        case "error": return Translation.tr("Error");
        case "unavailable": return Translation.tr("Unavailable");
        default: return Translation.tr("Unknown");
        }
    }

    function rowDescription(item) {
        const label = root.stateLabel(item.state);
        return item.detail && item.detail.length > 0 ? `${label} · ${item.detail}` : label;
    }

    Process {
        id: snapshotProc
        command: ["python3", root.helperPath]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && root.error.length === 0) root.error = text.trim()
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.ready && root.error.length === 0)
                root.error = Translation.tr("Diagnostic snapshot is unavailable.");
        }
    }
}
