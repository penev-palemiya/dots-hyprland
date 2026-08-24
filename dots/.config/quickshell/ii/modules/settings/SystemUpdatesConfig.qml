import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/updates.py`)
    readonly property string statusText: {
        if (root.checking)
            return Translation.tr("Checking…");
        if (root.checkError.length > 0)
            return Translation.tr("Check failed");
        if (!root.checked)
            return Translation.tr("Not checked");
        if (root.updates.length === 0)
            return Translation.tr("System packages are up to date");
        return Translation.tr("%1 updates available").arg(root.updates.length);
    }
    readonly property string statusDescription: {
        if (root.checkError.length > 0)
            return root.checkError;
        if (!root.checked)
            return Translation.tr("Check manually for available system packages.");
        return root.updates.length > 0
            ? Translation.tr("Only Arch and EndeavourOS repository packages are included.")
            : Translation.tr("Only an explicit check can establish this status.");
    }
    readonly property string recentDescription: {
        if (!root.history.available)
            return Translation.tr("No completed package upgrade found.");
        const date = new Date(root.history.timestamp);
        const stamp = isNaN(date.getTime()) ? root.history.timestamp : Qt.formatDateTime(date, "dd MMM yyyy, HH:mm");
        return Translation.tr("%1 · %2 packages").arg(stamp).arg(root.history.upgrades);
    }
    property bool checked: false
    property string checkedAt: ""
    property string checkError: ""
    property var updates: []
    property var history: ({ available: false })
    readonly property bool checking: checkProc.running

    function checkForUpdates() {
        if (root.checking)
            return;
        root.checkError = "";
        checkProc.running = true;
    }

    function applyCheckResult(result) {
        if (!result || result.ok !== true) {
            root.checkError = (result && result.error) ? result.error : Translation.tr("Update check failed.");
            return;
        }
        root.checked = true;
        root.checkedAt = new Date().toISOString();
        root.updates = result.updates || [];
        if (result.malformed > 0 && root.updates.length === 0)
            root.checkError = Translation.tr("Could not parse the update list.");
    }

    function loadHistory() {
        historyProc.running = true;
    }

    function openUpdater() {
        // Keep installation in the existing interactive terminal/pkexec flow.
        Quickshell.execDetached(["bash", "-c", Config.options.apps.update]);
    }

    Component.onCompleted: root.loadHistory()

    Process {
        id: historyProc
        command: ["python3", root.helperPath, "history"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    if (result.ok === true && result.history)
                        root.history = result.history;
                } catch (exception) {
                    root.history = ({ available: false });
                }
            }
        }
    }

    Process {
        id: checkProc
        command: ["python3", root.helperPath, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.applyCheckResult(JSON.parse(text));
                } catch (exception) {
                    root.checkError = Translation.tr("Update check failed.");
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.checkError.length === 0)
                root.checkError = Translation.tr("Update check failed.");
        }
    }

    SettingsGroup {
        title: Translation.tr("System Updates")

        SettingsRow {
            icon: root.checking ? "sync" : root.checkError.length > 0 ? "error" : root.updates.length > 0 ? "system_update" : "check_circle"
            title: root.statusText
            description: root.statusDescription

            DialogButton {
                buttonText: root.checking ? Translation.tr("Checking…") : root.checkError.length > 0 ? Translation.tr("Retry") : Translation.tr("Check for updates")
                enabled: !root.checking
                onClicked: root.checkForUpdates()
            }
        }

        SettingsRow {
            visible: root.checkedAt.length > 0
            icon: "schedule"
            title: Translation.tr("Last checked")
            description: Qt.formatDateTime(new Date(root.checkedAt), "dd MMM yyyy, HH:mm")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.updates.length > 0
            icon: "system_update_alt"
            title: Translation.tr("Update system")
            description: Translation.tr("Opens the existing interactive system updater.")
            registerInSearch: false

            DialogButton {
                buttonText: Translation.tr("Open updater")
                onClicked: root.openUpdater()
            }
        }
    }

    SettingsGroup {
        visible: root.updates.length > 0
        title: Translation.tr("Available system packages")

        SettingsRow {
            icon: "inventory_2"
            title: Translation.tr("Packages")
            description: Translation.tr("Full system upgrades are handled together.")
            registerInSearch: false

            ListView {
                implicitWidth: 360
                width: 360
                implicitHeight: Math.min(contentHeight, 360)
                height: implicitHeight
                clip: true
                model: root.updates
                delegate: RowLayout {
                    required property var modelData
                    width: 360
                    height: 34
                    spacing: 8

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.name
                        elide: Text.ElideRight
                    }
                    StyledText {
                        text: `${modelData.installed} → ${modelData.available}`
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Recent activity")

        SettingsRow {
            icon: "history"
            title: Translation.tr("Last system update")
            description: root.recentDescription
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("Scope")

        SettingsRow {
            icon: "info"
            title: Translation.tr("System packages only")
            description: Translation.tr("AUR, Flatpak, and firmware updates are not checked here yet.")
            registerInSearch: false
        }
    }
}
