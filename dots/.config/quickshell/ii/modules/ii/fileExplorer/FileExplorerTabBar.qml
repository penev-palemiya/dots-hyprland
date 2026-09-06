import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models
import QtQuick
import QtQuick.Layouts

// Browser-style tabs, not a fork of the shared ToolbarTabBar.qml: that one
// draws a fixed set of named/iconed destinations with an animated selection
// pill (settings pages, sidebar sections) - closed sets that don't grow or
// shrink at runtime. File explorer tabs open and close constantly and need
// a close button per tab and a "+" to add one, neither of which fits
// ToolbarTabBar's model.
Item {
    id: root

    required property var tabs // list<FileExplorerTab>
    required property int currentIndex
    signal tabSelected(index: int)
    signal tabCloseRequested(index: int)
    signal newTabRequested()
    // Closes the whole File Explorer window, not the current tab - a tab
    // already has its own close button (see the delegate below), so this
    // one plays the role a normal window's titlebar close button would if
    // this bar weren't replacing it.
    signal windowCloseRequested()

    implicitHeight: 36

    RowLayout {
        id: tabRow
        anchors.fill: parent
        spacing: 0

        Repeater {
            id: tabRepeater
            model: root.tabs
            delegate: Item {
                id: tabDelegate
                required property FileExplorerTab modelData
                required property int index
                readonly property bool current: index === root.currentIndex

                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(200, Math.max(100, tabLabel.implicitWidth + 36))
                // Without this, RowLayout is free to shrink tabs below their
                // preferredWidth - all the way toward zero - once enough
                // tabs are open that they no longer all fit, rather than
                // scrolling or eliding gracefully. Confirmed live: with two
                // tabs open, one narrowed to a sliver with no visible label
                // at all. 64px keeps a tab's label readably elided rather
                // than reducing it to just the close button.
                Layout.minimumWidth: 64

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            // Middle-click closes the tab - standard browser
                            // behaviour, and cheap to support alongside the
                            // explicit close button since MouseArea already
                            // has to distinguish the button anyway.
                            root.tabCloseRequested(tabDelegate.index);
                        } else {
                            root.tabSelected(tabDelegate.index);
                        }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 2
                        }
                        spacing: 2

                        StyledText {
                            id: tabLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: tabDelegate.modelData.title
                            color: tabDelegate.current ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnLayer1
                        }

                        RippleButton {
                            implicitWidth: 20
                            implicitHeight: 20
                            buttonRadius: height / 2
                            // Only offered once there's more than one tab -
                            // closing the last tab would leave the window
                            // with nothing to show, which FileExplorerHost
                            // doesn't have a defined behaviour for (it isn't
                            // "close the window", since that's a distinct
                            // action already bound elsewhere).
                            visible: root.tabs.length > 1
                            onClicked: root.tabCloseRequested(tabDelegate.index)
                            contentItem: MaterialSymbol {
                                text: "close"
                                iconSize: Appearance.font.pixelSize.normal
                                color: tabDelegate.current ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }

        RippleButton {
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: height / 2
            onClicked: root.newTabRequested()

            contentItem: MaterialSymbol {
                text: "add"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            StyledToolTip {
                text: Translation.tr("New tab")
            }
        }

        Item { Layout.fillWidth: true } // pushes tabs/add button to the left

        RippleButton {
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: height / 2
            onClicked: root.windowCloseRequested()
            contentItem: MaterialSymbol {
                text: "close"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            StyledToolTip {
                text: Translation.tr("Close")
            }
        }
    }

    // One shared underline for the active tab, not a per-tab background fill
    // - matches the reference (a floating bar that slides/stretches between
    // tabs on switch) rather than each tab drawing its own selected state.
    // itemAt(), not tabRepeater.children: Repeater delegates are reparented
    // onto the Repeater's own parent, not collected as the Repeater's own
    // children, so indexing children here would silently misalign as soon
    // as any non-delegate sibling (the "+"/close buttons) sits alongside it.
    Rectangle {
        id: activeTabIndicator
        // tabRepeater.count is read here purely to make this binding
        // re-evaluate once delegates actually exist - itemAt() has no
        // change signal of its own, so without this the binding runs once
        // while the Repeater is still empty (itemAt returns null, giving a
        // stuck negative width) and never re-runs once tabs are created.
        readonly property Item targetItem: tabRepeater.count > 0 ? tabRepeater.itemAt(root.currentIndex) : null
        readonly property real targetX: targetItem ? targetItem.x : 0
        readonly property real targetWidth: targetItem ? targetItem.width : 0

        height: 2
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        anchors.bottom: root.bottom

        AnimatedTabIndexPair {
            id: leftBound
            idx1Duration: 100
            idx2Duration: 250
            index: activeTabIndicator.targetX + 8
        }
        AnimatedTabIndexPair {
            id: rightBound
            idx1Duration: 100
            idx2Duration: 250
            index: activeTabIndicator.targetX + activeTabIndicator.targetWidth - 8
        }
        x: Math.min(leftBound.idx1, leftBound.idx2)
        width: Math.max(0, Math.max(rightBound.idx1, rightBound.idx2) - x)
    }
}
