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

    GlobalShortcut {
        name: "fileExplorerToggle"
        description: "Toggle file explorer"
        onPressed: FileExplorerLauncher.toggle()
    }
}
