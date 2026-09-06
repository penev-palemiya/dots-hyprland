import QtQuick
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A normal application window, not a layer-shell overlay - it shows up in
// the taskbar/Alt-Tab, tiles or floats under the compositor's ordinary
// window rules (see hypr/hyprland/rules.lua), and is closed like any other
// app instead of being dismissed by losing focus.
//
// Structurally this is FileExplorerContent (the same grid/address-bar/
// quick-access UI already used by the layer-shell version in
// FileExplorer.qml) wrapped in an ApplicationWindow, following the same
// pattern SettingsWindow.qml uses. It intentionally skips the compositor-blur
// glass SettingsWindow has - that machinery is tied to the wallpaper
// parallax system and is its own separate piece of work - so this window is
// opaque for now.
ApplicationWindow {
    id: root

    signal closeRequested()

    title: "File Explorer"
    minimumWidth: 700
    minimumHeight: 480
    width: Appearance.sizes.fileExplorerWidth
    height: Appearance.sizes.fileExplorerHeight
    color: Appearance.m3colors.m3background

    onClosing: root.closeRequested()
    onVisibleChanged: {
        if (!visible)
            return;
        // Same reasoning as SettingsWindow: an ApplicationWindow can be
        // mapped before the compositor has accepted the surface, so pointer/
        // keyboard input needs activation deferred to the next event turn.
        Qt.callLater(() => {
            if (root.visible) {
                root.raise();
                root.requestActivate();
                content.focusSearch();
            }
        });
    }

    FileExplorerContent {
        id: content
        anchors.fill: parent
        onCloseRequested: root.closeRequested()
    }
}
