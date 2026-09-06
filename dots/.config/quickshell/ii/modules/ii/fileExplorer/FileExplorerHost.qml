import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

// Same pattern as SettingsHost.qml: a Loader driven by a launcher singleton
// (FileExplorerLauncher) rather than the layer-shell Loader{active: ...}
// FileExplorer.qml used to use. This is what makes the window a real,
// ordinary ApplicationWindow instance - constructed on open, torn down on
// close - instead of a panel surface that's just shown or hidden.
Item {
    id: root

    readonly property bool loaded: explorerLoader.status === Loader.Ready

    Loader {
        id: explorerLoader
        active: FileExplorerLauncher.active
        sourceComponent: explorerWindowComponent
        onLoaded: {
            item.show();
            item.raise();
            item.requestActivate();
        }
    }

    Component {
        id: explorerWindowComponent

        FileExplorerWindow {
            onCloseRequested: Qt.callLater(() => FileExplorerLauncher.close())
        }
    }

    Connections {
        target: FileExplorerLauncher
        function onActiveChanged() {
            if (!FileExplorerLauncher.active) {
                if (explorerLoader.item) {
                    explorerLoader.item.hide();
                    explorerLoader.item.close();
                }
                return;
            }
            Qt.callLater(() => {
                if (!explorerLoader.item)
                    return;
                explorerLoader.item.visible = true;
                explorerLoader.item.show();
                explorerLoader.item.raise();
                explorerLoader.item.requestActivate();
            });
        }

        function onRaiseRequested() {
            if (!explorerLoader.item)
                return;
            explorerLoader.item.raise();
            explorerLoader.item.requestActivate();
        }
    }

    IpcHandler {
        target: "fileExplorer"

        function toggle(): void {
            FileExplorerLauncher.toggle();
        }

        function open(): void {
            FileExplorerLauncher.open();
        }

        function close(): void {
            if (explorerLoader.item) {
                explorerLoader.item.hide();
                explorerLoader.item.close();
            }
            FileExplorerLauncher.close();
        }
    }

    // Reaches the window's currently ACTIVE pane (FileExplorerWindow.pane
    // already resolves "which of possibly several tabs/split panes is
    // active" down to one FileExplorerPane). Named distinctly from the
    // "fileExplorer" target above for the same reason as the old
    // services/FileExplorer.qml comment explained: two IpcHandlers sharing
    // one target don't error, they silently keep only the first and warn
    // about the second.
    //
    // Addressing a SPECIFIC tab/pane rather than always "whichever is
    // active" isn't wired up yet - not a concern current callers (tests,
    // external tooling) have needed.
    IpcHandler {
        target: "fileExplorerService"

        function setDirectory(path: string): void {
            explorerLoader.item?.pane?.setDirectory(path);
        }

        function clearSelection(): void {
            explorerLoader.item?.pane?.clearSelection();
        }

        function openFile(path: string): void {
            FileExplorer.openFile(path);
        }

        function selectAll(): void {
            const pane = explorerLoader.item?.pane;
            if (!pane) return;
            pane.selectedPaths = pane.entries.slice();
        }

        function deleteSelection(): void {
            explorerLoader.item?.pane?.deleteSelection();
        }

        function copySelection(): void {
            const pane = explorerLoader.item?.pane;
            if (pane) FileExplorer.copySelectionToClipboard(pane);
        }

        function cutSelection(): void {
            const pane = explorerLoader.item?.pane;
            if (pane) FileExplorer.cutSelectionToClipboard(pane);
        }

        function paste(): void {
            const pane = explorerLoader.item?.pane;
            if (pane) FileExplorer.pasteClipboard(pane);
        }

        function renameEntry(oldPath: string, newName: string): void {
            explorerLoader.item?.pane?.renameEntry(oldPath, newName);
        }
    }

    GlobalShortcut {
        name: "fileExplorerToggle"
        description: "Toggle file explorer"
        onPressed: FileExplorerLauncher.toggle()
    }
}
