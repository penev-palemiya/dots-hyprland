import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

// A normal application window, not a layer-shell overlay - it shows up in
// the taskbar/Alt-Tab, tiles or floats under the compositor's ordinary
// window rules (see hypr/hyprland/rules.lua), and is closed like any other
// app instead of being dismissed by losing focus.
//
// Owns a list of FileExplorerTab (browser-style tabs), each rendered by
// FileExplorerSplitView - which shows one or two FileExplorerContent
// instances side by side depending on that tab's own splitEnabled. Tabs and
// split are the same underlying mechanism (a tab IS "one or two panes"),
// not two separate features layered on top of each other.
ApplicationWindow {
    id: root

    signal closeRequested()

    title: {
        const tab = tabs[currentTabIndex];
        return tab ? `${tab.currentFolderName()} - File Explorer` : "File Explorer";
    }
    minimumWidth: 700
    minimumHeight: 480
    width: Appearance.sizes.fileExplorerWidth
    height: Appearance.sizes.fileExplorerHeight
    color: Appearance.m3colors.m3background

    // Exposed so FileExplorerHost's IpcHandler (used for e.g. testing and
    // external tooling) can reach the active tab's active pane.
    readonly property FileExplorerPane pane: {
        const tab = tabs[currentTabIndex];
        return tab ? tab.activePane : null;
    }

    property list<FileExplorerTab> tabs: []
    property int currentTabIndex: 0

    function addTab() {
        const tab = tabComponent.createObject(tabHost);
        root.tabs = [...root.tabs, tab];
        root.currentTabIndex = root.tabs.length - 1;
    }

    function closeTab(index) {
        if (root.tabs.length <= 1) return; // Last tab: nothing to fall back to - see FileExplorerTabBar's own guard for why this isn't "close the window" instead.
        const tab = root.tabs[index];
        const next = root.tabs.slice();
        next.splice(index, 1);
        root.tabs = next;
        tab.destroy();
        if (root.currentTabIndex >= root.tabs.length)
            root.currentTabIndex = root.tabs.length - 1;
        else if (root.currentTabIndex > index)
            root.currentTabIndex -= 1;
    }

    // Holds tab objects outside the visual tree - FileExplorerTab is an Item
    // only because its panes need real QML parenting for their Process/model
    // children (see its own doc comment), not because it's meant to be laid
    // out or shown itself. FileExplorerSplitView is what actually renders
    // the current tab's content.
    Item {
        id: tabHost
        visible: false
    }

    Component {
        id: tabComponent
        FileExplorerTab {}
    }

    Component.onCompleted: root.addTab()

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
            }
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        FileExplorerTabBar {
            Layout.fillWidth: true
            tabs: root.tabs
            currentIndex: root.currentTabIndex
            onTabSelected: index => root.currentTabIndex = index
            onTabCloseRequested: index => root.closeTab(index)
            onNewTabRequested: root.addTab()
            onSplitToggleRequested: {
                const tab = root.tabs[root.currentTabIndex];
                if (tab) tab.toggleSplit();
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Repeater {
                // All tabs are instantiated (not Loader'd per-index) so
                // switching tabs doesn't re-run each pane's directory scan -
                // the trade-off is every open tab's FolderListModel stays
                // live in the background, same reasoning as FileExplorerTab
                // keeping paneB alive even when split is off.
                model: root.tabs
                delegate: FileExplorerSplitView {
                    id: splitViewDelegate
                    required property FileExplorerTab modelData
                    required property int index
                    anchors.fill: parent
                    visible: index === root.currentTabIndex
                    tab: modelData
                    onCloseRequested: root.closeRequested()
                }
            }
        }
    }
}
