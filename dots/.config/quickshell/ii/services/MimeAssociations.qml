pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Event-driven, transactional access to the user XDG MIME associations. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/mime_associations.py`)
    readonly property string mimeFile: `${Directories.config}/mimeapps.list`
    property var values: ({})
    property bool loading: false
    property bool applying: false
    property bool ready: false
    property string error: ""
    property int revision: 0
    property list<string> lastMimes: []

    signal refreshed(bool success)
    signal applied(bool success)

    function sameMimes(mimes) {
        return root.lastMimes.length === mimes.length && root.lastMimes.every((mime, index) => mime === mimes[index]);
    }

    function query(mimes, force = false) {
        if (root.loading || root.applying || !mimes || mimes.length === 0 || (!force && root.ready && root.sameMimes(mimes)))
            return;
        root.loading = true;
        root.error = "";
        root.lastMimes = mimes;
        queryProc.command = ["python3", root.helperPath, "query", ...mimes];
        queryProc.running = true;
    }

    function refresh(mimes, force = false) {
        root.query(mimes, force);
    }

    function apply(desktopId, mimes) {
        if (root.loading || root.applying || !desktopId || !mimes || mimes.length === 0)
            return false;
        root.applying = true;
        root.error = "";
        root.lastMimes = mimes;
        applyProc.command = ["python3", root.helperPath, "apply", desktopId, ...mimes];
        applyProc.running = true;
        return true;
    }

    Process {
        id: queryProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.values = JSON.parse(text);
                    root.ready = true;
                    root.revision++;
                    root.refreshed(true);
                } catch (exception) {
                    root.error = Translation.tr("Could not read default applications.");
                    root.refreshed(false);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.error = text.trim();
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0) {
                root.error = root.error || Translation.tr("Could not read default applications.");
                root.refreshed(false);
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (!result.ok)
                        root.error = result.error || Translation.tr("Could not change the default application.");
                    root.applied(Boolean(result.ok));
                } catch (exception) {
                    root.error = Translation.tr("Could not change the default application.");
                    root.applied(false);
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0) root.error = text.trim();
        }
        onExited: code => {
            root.applying = false;
            if (code !== 0 && !root.error)
                root.error = Translation.tr("Could not change the default application.");
            if (root.lastMimes.length > 0)
                root.query(root.lastMimes, true);
        }
    }

    FileView {
        path: root.mimeFile
        watchChanges: true
        onFileChanged: {
            if (!root.loading && !root.applying)
                root.revision++;
        }
    }
}
