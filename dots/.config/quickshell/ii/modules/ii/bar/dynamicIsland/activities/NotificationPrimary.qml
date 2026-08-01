import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Widgets

/**
 * Primary row for the notification feed activity: shows the newest persistent
 * notification (sender/avatar, message, app badge) plus one quick-action
 * button if it has any actions. The full backlog (all pending notifications,
 * all their actions, dismiss) lives in NotificationExpanded.qml instead —
 * this row is deliberately compact, matching Media/CapsLock's row shape.
 */
IslandActivityRow {
    id: root

    // Reads the Notifications singleton directly rather than being handed
    // the activity descriptor object — same convention as MediaPrimary.qml
    // (reads MprisController directly) and CapsLockPrimary.qml (reads
    // HyprlandXkb directly).
    readonly property var pending: Notifications.list
    readonly property var newest: root.pending.length > 0 ? root.pending[root.pending.length - 1] : null
    readonly property string senderText: (root.newest?.body ?? "").length > 0 ? (root.newest?.summary || root.newest?.appName || Translation.tr("Notification")) : (root.newest?.appName || Translation.tr("Notification"))
    readonly property string messageText: root.newest?.body || root.newest?.summary || ""

    // Main image is the sender/avatar. The tiny badge at bottom-right carries
    // the app identity, so "Telegram Desktop" doesn't waste text space.
    iconOverride: iconComponent

    Component {
        id: iconComponent
        Item {
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Appearance.colors.colSecondaryContainer
                clip: true

                Image {
                    anchors.fill: parent
                    visible: (root.newest?.image ?? "").length > 0
                    source: root.newest?.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: (root.newest?.image ?? "").length === 0
                    fill: 1
                    text: "person"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.m3colors.m3onSecondaryContainer
                }
            }

            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                }
                width: 12
                height: 12
                radius: width / 2
                color: Appearance.colors.colLayer1
                border.width: 1
                border.color: Appearance.colors.colLayer1
                clip: true
                visible: (root.newest?.appIcon ?? "").length > 0

                IconImage {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: Quickshell.iconPath(root.newest?.appIcon ?? "", "image-missing")
                }
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(notificationText.implicitHeight, quickActionButton.implicitHeight)
        spacing: 6
        clip: true

        IslandCompactText {
            id: notificationText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - (quickActionButton.visible ? quickActionButton.width + parent.spacing : 0))
            metadataText: root.senderText
            primaryText: root.messageText
            primaryMarquee: true
        }

        // One quick action — the rest live in the expanded panel. A real
        // button, so clicking it doesn't fall through to the pill's own
        // click-to-expand.
        RippleButton {
            id: quickActionButton
            visible: (root.newest?.actions.length ?? 0) > 0
            anchors.verticalCenter: parent.verticalCenter
            buttonRadius: Appearance.rounding.full
            implicitHeight: 22
            implicitWidth: implicitHeight
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                fill: 0
                iconSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSecondaryContainer
                text: "open_in_new"
            }
            onClicked: {
                if ((root.newest?.actions.length ?? 0) > 0)
                    Notifications.attemptInvokeAction(root.newest.notificationId, root.newest.actions[0].identifier);
            }
        }
    }
}
