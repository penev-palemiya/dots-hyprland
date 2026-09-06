import qs.services
import qs.modules.common
import qs.modules.common.widgets
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
    signal splitToggleRequested()

    readonly property bool currentTabSplit: root.tabs[root.currentIndex]?.splitEnabled ?? false

    implicitHeight: 36

    RowLayout {
        anchors.fill: parent
        spacing: 2

        Repeater {
            model: root.tabs
            delegate: Rectangle {
                id: tabDelegate
                required property FileExplorerTab modelData
                required property int index
                readonly property bool current: index === root.currentIndex

                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(200, Math.max(120, tabLabel.implicitWidth + 44))
                // Without this, RowLayout is free to shrink tabs below their
                // preferredWidth - all the way toward zero - once enough
                // tabs are open that they no longer all fit, rather than
                // scrolling or eliding gracefully. Confirmed live: with two
                // tabs open, one narrowed to a sliver with no visible label
                // at all. 80px keeps a tab's label readably elided rather
                // than reducing it to just the close button.
                Layout.minimumWidth: 80
                color: current ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1
                radius: Appearance.rounding.small

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
                            leftMargin: 10
                            rightMargin: 4
                        }
                        spacing: 4

                        StyledText {
                            id: tabLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: tabDelegate.modelData.title
                            color: tabDelegate.current ? Appearance.colors.colOnLayer0 : Appearance.colors.colOnLayer1
                        }

                        RippleButton {
                            implicitWidth: 22
                            implicitHeight: 22
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
            toggled: root.currentTabSplit
            onClicked: root.splitToggleRequested()
            contentItem: MaterialSymbol {
                text: "vertical_split"
                iconSize: Appearance.font.pixelSize.larger
                fill: root.currentTabSplit ? 1 : 0
                color: root.currentTabSplit ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
            }
            StyledToolTip {
                text: root.currentTabSplit ? Translation.tr("Turn off split view") : Translation.tr("Split view")
            }
        }
    }
}
