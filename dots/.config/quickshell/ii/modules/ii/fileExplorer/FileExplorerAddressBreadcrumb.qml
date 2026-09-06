import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

// Fork of AddressBreadcrumb.qml (the shared widget used elsewhere, e.g. the
// wallpaper picker) - same segment-button layout, but each segment now
// carries a right-click menu (navigate here / copy this path / paste into
// this folder), which the shared widget has no reason to grow just for this
// one caller.
ListView {
    id: root
    required property var directory
    property var breadcrumbDirectory: ""
    Component.onCompleted: breadcrumbDirectory = directory;
    onDirectoryChanged: {
        if (breadcrumbDirectory.startsWith(directory)) return;
        breadcrumbDirectory = directory
    }

    signal navigateToDirectory(string path)
    // Emitted for the "Paste into this folder" segment action - the
    // breadcrumb itself has no clipboard or pane to paste with, so it hands
    // the target path back up to whoever does (FileExplorerAddressBar).
    signal pasteIntoRequested(string path)

    orientation: ListView.Horizontal
    clip: true
    spacing: 2

    model: breadcrumbDirectory.split("/")
    delegate: SelectionGroupButton {
        id: folderButton
        required property var modelData
        required property int index
        buttonText: index === 0 ? "/" : modelData
        toggled: {
            if (directory.trim() === "/") return index === 0;
            return index === directory.split("/").length - 1
        }
        leftmost: index === 0
        rightmost: index === breadcrumbDirectory.split("/").length - 1

        readonly property string segmentPath: breadcrumbDirectory.split("/").slice(0, index + 1).join("/") || "/"

        onClicked: {
            root.navigateToDirectory(folderButton.segmentPath);
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: eventPoint => {
                contextMenu.actions = [
                    {
                        text: Translation.tr("Open"),
                        icon: "folder_open",
                        onTriggered: () => root.navigateToDirectory(folderButton.segmentPath)
                    },
                    {
                        text: Translation.tr("Copy path"),
                        icon: "content_copy",
                        onTriggered: () => Quickshell.clipboardText = folderButton.segmentPath
                    },
                    {
                        text: Translation.tr("Paste into this folder"),
                        icon: "content_paste",
                        enabled: FileExplorer.clipboardPaths.length > 0,
                        onTriggered: () => root.pasteIntoRequested(folderButton.segmentPath)
                    },
                ];
                contextMenu.openAt(eventPoint.position.x, eventPoint.position.y, folderButton);
            }
        }
    }

    FileExplorerContextMenu {
        id: contextMenu
    }
}
