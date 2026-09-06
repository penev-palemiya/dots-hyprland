pragma Singleton

import QtQuick
import Quickshell

// Same shape as SettingsLauncher.qml: a tiny piece of shared state
// (active/raiseRequested) that FileExplorerHost.qml watches to construct,
// show, and tear down the actual ApplicationWindow. Kept separate from
// FileExplorer.qml (the browsing service - directory, history, search) for
// the same reason SettingsLauncher is separate from the settings data it
// launches a window onto: "is the window open" and "what does the window
// show" are different concerns.
Singleton {
    id: root

    signal raiseRequested()
    property bool active: false

    function open() {
        if (root.active) {
            root.raiseRequested();
            return;
        }
        root.active = true;
    }

    function close() {
        root.active = false;
    }

    function toggle() {
        if (root.active)
            root.close();
        else
            root.open();
    }
}
