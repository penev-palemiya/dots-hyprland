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

    property string searchText: ""
    property bool confirmingWipe: false
    property int storageBytes: -1
    property string storageError: ""

    readonly property var filteredEntries: {
        const query = root.searchText.trim();
        return query.length > 0 ? Cliphist.fuzzyQuery(query) : Cliphist.entries;
    }

    function preview(entry) {
        if (Cliphist.entryIsImage(entry))
            return Translation.tr("Image clipboard item");
        const text = StringUtils.cleanCliphistEntry(entry).replace(/\s+/g, " ").trim();
        return text.length > 0 ? text : Translation.tr("Empty text item");
    }

    function itemId(entry) {
        return String(entry).split("\t", 1)[0];
    }

    function refreshStorageSize() {
        storageProc.running = true;
    }

    Component.onCompleted: root.refreshStorageSize()

    Connections {
        target: Cliphist
        function onEntriesChanged() {
            root.refreshStorageSize();
        }
    }

    Process {
        id: storageProc
        command: ["stat", "-c", "%s", "--", Cliphist.databasePath]

        stdout: StdioCollector {
            onStreamFinished: {
                const value = Number(text.trim());
                root.storageBytes = Number.isFinite(value) ? value : -1;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.storageError = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.storageBytes = -1;
                if (root.storageError.length === 0)
                    root.storageError = Translation.tr("Could not read history size.");
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Clipboard")

        SettingsRow {
            icon: "info"
            title: Translation.tr("Clipboard history")
            description: Translation.tr("Copied text and images may remain stored locally in clipboard history.")
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("History")

        SettingsRow {
            icon: "search"
            title: Translation.tr("Search history")
            description: Translation.tr("Searches locally without starting another history process.")
            registerInSearch: false

            MaterialTextField {
                Layout.preferredWidth: 260
                placeholderText: Translation.tr("Search history…")
                text: root.searchText
                onTextChanged: root.searchText = text
            }
        }

        SettingsRow {
            icon: "history"
            title: Cliphist.available
                ? Translation.tr("%1 items").arg(Cliphist.entries.length)
                : Translation.tr("History unavailable")
            description: root.searchText.trim().length > 0
                ? Translation.tr("Showing %1 matching items").arg(root.filteredEntries.length)
                : Translation.tr("Select an item to restore it to the clipboard.")
            registerInSearch: false
        }

        Rectangle {
            id: historySurface
            Layout.fillWidth: true
            implicitHeight: Math.min(520, Math.max(94, historyList.contentHeight))
            radius: 16
            color: Appearance.colors.colSurfaceContainerHighest
            clip: true

            ListView {
                id: historyList
                anchors.fill: parent
                anchors.margins: 10
                model: root.filteredEntries
                spacing: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: historyItem
                    required property var modelData
                    readonly property string entry: String(modelData)
                    readonly property string idText: root.itemId(entry)
                    readonly property bool imageEntry: Cliphist.entryIsImage(entry)

                    width: historyList.width
                    implicitHeight: itemLayout.implicitHeight + 20
                    radius: 10
                    color: Appearance.colors.colSurfaceContainer

                    RowLayout {
                        id: itemLayout
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 10
                        }
                        spacing: 12

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            text: historyItem.imageEntry ? "image" : "content_paste"
                            iconSize: Appearance.font.pixelSize.huge
                            color: Appearance.colors.colOnSurfaceVariant
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.preview(historyItem.entry)
                                color: Appearance.colors.colOnSurface
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                                maximumLineCount: 2
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: historyItem.imageEntry
                                    ? Translation.tr("Image · ID %1").arg(historyItem.idText)
                                    : Translation.tr("Text · ID %1").arg(historyItem.idText)
                                color: Appearance.colors.colOnSurfaceVariant
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                elide: Text.ElideRight
                            }

                            Loader {
                                Layout.fillWidth: true
                                active: historyItem.imageEntry
                                sourceComponent: CliphistImage {
                                    entry: historyItem.entry
                                    maxWidth: historyList.width - 170
                                    maxHeight: 120
                                    blur: Config.options.workSafety.enable.clipboard
                                }
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignTop
                            spacing: 4

                            RippleButtonWithIcon {
                                materialIcon: "content_copy"
                                mainText: Translation.tr("Copy")
                                onClicked: Cliphist.copy(historyItem.entry)
                            }

                            RippleButtonWithIcon {
                                materialIcon: "delete"
                                mainText: ""
                                onClicked: Cliphist.deleteById(historyItem.idText)
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: historyList.count === 0
                    text: root.searchText.trim().length > 0
                        ? Translation.tr("No matching clipboard items")
                        : Translation.tr("No clipboard history")
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.normal
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Storage & privacy")

        SettingsRow {
            icon: "storage"
            title: Translation.tr("History size")
            description: root.storageError.length > 0 ? root.storageError : Translation.tr("Current clipboard database size on disk")
            registerInSearch: false

            StyledText {
                text: root.storageBytes >= 0 ? Storage.humanSize(root.storageBytes) : Translation.tr("Unavailable")
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }

        SettingsToggleRow {
            icon: "visibility_off"
            title: Translation.tr("Blur image previews")
            description: Translation.tr("Only the preview is blurred; the stored image is unchanged.")
            keywords: "clipboard image preview work safety"
            checked: Config.options.workSafety.enable.clipboard
            onToggled: checked => Config.options.workSafety.enable.clipboard = checked
        }

        SettingsRow {
            visible: Cliphist.error.length > 0
            icon: "error"
            title: Translation.tr("Clipboard history error")
            description: Cliphist.error
            registerInSearch: false
        }

        SettingsRow {
            visible: !root.confirmingWipe
            icon: "delete_sweep"
            title: Translation.tr("Clear history")
            description: Translation.tr("Permanently remove stored history. Current clipboard contents remain unchanged.")
            registerInSearch: false

            DialogButton {
                buttonText: Translation.tr("Clear history")
                onClicked: root.confirmingWipe = true
            }
        }

        SettingsRow {
            visible: root.confirmingWipe
            icon: "warning"
            title: Translation.tr("Clear clipboard history?")
            description: Translation.tr("This permanently removes clipboard history. The current clipboard is not changed.")
            registerInSearch: false

            RowLayout {
                spacing: 8

                DialogButton {
                    buttonText: Translation.tr("Cancel")
                    onClicked: root.confirmingWipe = false
                }

                DialogButton {
                    buttonText: Translation.tr("Clear history")
                    colBackground: Appearance.colors.colError
                    colText: Appearance.colors.colOnError
                    onClicked: {
                        root.confirmingWipe = false;
                        Cliphist.wipe();
                    }
                }
            }
        }
    }
}
