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
//
// Each tab is its own pill: the active one filled with the secondary
// container colour, inactive ones with the flat layer colour, per the
// design reference. That's why there's no separate sliding indicator here -
// the pill IS the selected state, and it animates via Behavior on color
// rather than by moving a shared marker between tabs.
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

    implicitHeight: 40

    RowLayout {
        id: tabRow
        anchors {
            fill: parent
            leftMargin: 8
            rightMargin: 8
        }
        spacing: 4

        Repeater {
            id: tabRepeater
            model: root.tabs
            delegate: Rectangle {
                id: tabDelegate
                required property FileExplorerTab modelData
                required property int index
                readonly property bool current: index === root.currentIndex

                Layout.preferredHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.min(200, tabContentRow.implicitWidth + 24)
                // Without this, RowLayout is free to shrink tabs below their
                // preferredWidth - all the way toward zero - once enough
                // tabs are open that they no longer all fit, rather than
                // scrolling or eliding gracefully. Confirmed live: with two
                // tabs open, one narrowed to a sliver with no visible label
                // at all. This keeps a tab's label readably elided rather
                // than reducing it to just the close button.
                Layout.minimumWidth: 72

                radius: Appearance.rounding.full
                // Inactive tabs use the same surface token as the address
                // bar below rather than colLayer1: on this theme colLayer1
                // sits ~7/255 from the window background (measured on
                // screen), so inactive pills read as invisible instead of
                // as the distinct plates the reference shows.
                color: tabDelegate.current ? Appearance.colors.colSecondaryContainer : Appearance.colors.colSurfaceContainerHigh
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
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
                        id: tabContentRow
                        anchors {
                            fill: parent
                            leftMargin: 12
                            rightMargin: 6
                        }
                        spacing: 4

                        StyledText {
                            id: tabLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            text: tabDelegate.modelData.title
                            color: tabDelegate.current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                        }

                        // Always present, unlike the earlier design where it
                        // only appeared once a second tab existed: the
                        // reference shows a close affordance on every tab,
                        // and closing the last one is handled by closeTab()
                        // refusing rather than by hiding the control.
                        RippleButton {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: 18
                            implicitHeight: 18
                            buttonRadius: height / 2
                            onClicked: root.tabCloseRequested(tabDelegate.index)
                            colBackground: "transparent"
                            contentItem: MaterialSymbol {
                                text: "close"
                                iconSize: Appearance.font.pixelSize.small
                                color: tabDelegate.current ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 26
            implicitHeight: 26
            buttonRadius: height / 2
            onClicked: root.newTabRequested()
            colBackground: Appearance.colors.colSurfaceContainerHigh

            contentItem: MaterialSymbol {
                text: "add"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            StyledToolTip {
                text: Translation.tr("New tab")
            }
        }

        Item { Layout.fillWidth: true } // pushes tabs/add button to the left

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: height / 2
            onClicked: root.windowCloseRequested()
            colBackground: "transparent"
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
}
