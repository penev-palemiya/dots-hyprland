import qs.modules.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Renders one FileExplorerTab's content: a single FileExplorerContent when
 * splitEnabled is false, or two side by side (with a drag handle between
 * them) when it's true. Which pane is "active" (gets keyboard focus,
 * determines the window title) follows whichever pane the pointer is over,
 * like most split-view editors - hovering a side makes it the one further
 * actions (paste, delete, keyboard shortcuts) act on.
 *
 * Tracked via pointerActive() (a HoverHandler on FileExplorerContent), not a
 * click: that content's own MouseArea only accepts Back/Forward mouse
 * buttons (see its onPressed), so a plain left click never reaches an
 * onPressed there at all - it falls through to the grid/delegates
 * underneath, which have no reason to know which split side they're in.
 */
Item {
    id: root

    required property FileExplorerTab tab

    signal closeRequested()

    SplitView {
        id: splitView
        anchors.fill: parent
        visible: root.tab.splitEnabled
        orientation: Qt.Horizontal

        FileExplorerContent {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 300
            pane: root.tab.paneA
            splitEnabled: root.tab.splitEnabled
            onCloseRequested: root.closeRequested()
            onPointerActive: root.tab.activePaneIndex = 0
            onSplitToggleRequested: root.tab.toggleSplit()
        }

        FileExplorerContent {
            SplitView.fillWidth: true
            SplitView.minimumWidth: 300
            pane: root.tab.paneB
            splitEnabled: root.tab.splitEnabled
            onCloseRequested: root.closeRequested()
            onPointerActive: root.tab.activePaneIndex = 1
            onSplitToggleRequested: root.tab.toggleSplit()
        }
    }

    // The single-pane case is a wholly separate FileExplorerContent instance
    // rather than "SplitView with one child hidden" - a hidden SplitView
    // child still reserves layout space and its own Process/FolderListModel
    // children keep running underneath, which is exactly the kind of
    // resource-for-nothing this avoided in the Singleton-based design this
    // whole file exists to move away from.
    FileExplorerContent {
        anchors.fill: parent
        visible: !root.tab.splitEnabled
        pane: root.tab.paneA
        splitEnabled: root.tab.splitEnabled
        onCloseRequested: root.closeRequested()
        onSplitToggleRequested: root.tab.toggleSplit()
    }
}
