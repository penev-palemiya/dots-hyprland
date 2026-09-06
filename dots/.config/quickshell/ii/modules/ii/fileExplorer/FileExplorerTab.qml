import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick

/**
 * One tab: a title, and one or two FileExplorerPane instances (split view is
 * "this tab has two panes side by side", not a separate feature bolted on -
 * see the architecture note in FileExplorerTabBar.qml for why).
 *
 * An Item rather than a plain JS object: each pane owns live QML objects
 * (a FolderListModel, Process children for file operations) that need
 * proper QML lifetime management - a JS object literal couldn't own those
 * the same way, and destroying a tab needs those Process/model children torn
 * down cleanly along with it.
 */
Item {
    id: root

    property string title: Translation.tr("New Tab")
    // Which pane is "active" for actions that need exactly one target - the
    // address bar, keyboard shortcuts, the window title. Always 0 when
    // splitEnabled is false (there is only ever pane 0 then).
    property int activePaneIndex: 0
    property bool splitEnabled: false

    readonly property FileExplorerPane activePane: splitEnabled && activePaneIndex === 1 ? paneB : paneA

    // paneB only exists as a second view once split is turned on; before
    // that it's still instantiated (Loader active bindings would be more
    // machinery than two always-there-but-usually-invisible panes justify
    // for something this lightweight) but simply not shown or addressed.
    FileExplorerPane {
        id: paneA
    }
    FileExplorerPane {
        id: paneB
    }
    property alias paneA: paneA
    property alias paneB: paneB

    function toggleSplit() {
        root.splitEnabled = !root.splitEnabled;
        if (!root.splitEnabled)
            root.activePaneIndex = 0;
    }

    // Keeps the tab's title in sync with whichever pane is active, so the
    // tab bar shows the folder actually being looked at right now rather
    // than whatever pane 0 happened to be showing when the tab was created.
    function currentFolderName() {
        const pane = root.activePane;
        const path = pane.effectiveDirectory;
        if (!path || path === "/") return "/";
        return FileUtils.fileNameForPath(path) || path;
    }
}
