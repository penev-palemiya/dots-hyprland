import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Item {
    id: root

    readonly property bool loaded: settingsLoader.status === Loader.Ready

    Loader {
        id: settingsLoader
        active: SettingsLauncher.active
        sourceComponent: settingsWindowComponent
        onLoaded: {
            item.forceShow = true;
            item.show();
            item.raise();
            item.requestActivate();
        }
    }

    Component {
        id: settingsWindowComponent

        SettingsWindow {
            initialRoute: SettingsLauncher.route
            onCloseRequested: Qt.callLater(() => SettingsLauncher.close())
        }
    }

    Connections {
        target: SettingsLauncher
        function onActiveChanged() {
            if (!SettingsLauncher.active) {
                if (settingsLoader.item) {
                    settingsLoader.item.hide();
                    settingsLoader.item.close();
                }
                return;
            }
            Qt.callLater(() => {
                if (!settingsLoader.item)
                    return;
                settingsLoader.item.forceShow = true;
                settingsLoader.item.visible = true;
                settingsLoader.item.show();
                settingsLoader.item.raise();
                settingsLoader.item.requestActivate();
            });
        }

        function onRaiseRequested() {
            if (!settingsLoader.item)
                return;
            settingsLoader.item.raise();
            settingsLoader.item.requestActivate();
        }
    }

    IpcHandler {
        target: "settings"

        function open(): void {
            SettingsLauncher.open();
        }

        function openRoute(route: string): void {
            SettingsLauncher.open(route);
        }

        function close(): void {
            if (settingsLoader.item) {
                settingsLoader.item.hide();
                settingsLoader.item.close();
            }
            SettingsLauncher.close();
        }
    }

    GlobalShortcut {
        name: "settingsOpen"
        description: "Opens Settings"
        onPressed: SettingsLauncher.open()
    }
}
