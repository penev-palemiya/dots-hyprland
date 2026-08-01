import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Full backlog for the notification feed activity: every currently pending
 * notification (newest first), each with its own icon, app name, body, all
 * of its actions, and a dismiss button. NotificationPrimary.qml only ever
 * shows the newest one plus a single quick action — this is where the rest
 * of a 5-7-message burst actually gets read and acted on.
 *
 * Reuses Notifications.attemptInvokeAction/discardNotification directly
 * (the same functions the sidebar's NotificationItem.qml uses), so acting
 * here updates the sidebar too — there's no separate state to keep in sync.
 */
ColumnLayout {
    id: root

    readonly property var pending: Notifications.popupList

    anchors.fill: parent
    spacing: 10

    StyledText {
        Layout.fillWidth: true
        font.weight: Font.Bold
        color: Appearance.colors.colOnLayer1
        text: `${Translation.tr("Notifications")} (${root.pending.length})`
    }

    ListView {
        id: notifList
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 320)
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds

        // Newest first — same ordering as the primary row's "newest".
        model: [...root.pending].reverse()

        delegate: Rectangle {
            id: notifRow
            required property var modelData

            width: notifList.width
            implicitHeight: notifContent.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2

            ColumnLayout {
                id: notifContent
                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer
                        clip: true

                        Image {
                            anchors.fill: parent
                            visible: (notifRow.modelData.image ?? "").length > 0
                            source: notifRow.modelData.image ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }
                        IconImage {
                            anchors.fill: parent
                            visible: (notifRow.modelData.image ?? "").length === 0 && (notifRow.modelData.appIcon ?? "").length > 0
                            source: Quickshell.iconPath(notifRow.modelData.appIcon ?? "", "image-missing")
                        }
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: (notifRow.modelData.image ?? "").length === 0 && (notifRow.modelData.appIcon ?? "").length === 0
                            fill: 1
                            text: "notifications"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSecondaryContainer
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: notifRow.modelData.appName ?? ""
                        }
                        StyledText {
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnLayer1
                            text: notifRow.modelData.summary ?? ""
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            elide: Text.ElideRight
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            text: notifRow.modelData.body ?? ""
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: notifRow.modelData.actions ?? []
                        delegate: RippleButton {
                            required property var modelData
                            implicitHeight: 24
                            implicitWidth: actionText.implicitWidth + 14
                            buttonRadius: Appearance.rounding.full
                            colBackground: Appearance.colors.colSecondaryContainer
                            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                            contentItem: StyledText {
                                id: actionText
                                anchors.centerIn: parent
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colOnSecondaryContainer
                                text: modelData.text
                            }
                            onClicked: Notifications.attemptInvokeAction(notifRow.modelData.notificationId, modelData.identifier)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RippleButton {
                        implicitHeight: 24
                        implicitWidth: dismissText.implicitWidth + 14
                        buttonRadius: Appearance.rounding.full
                        colBackground: Appearance.colors.colLayer3
                        colBackgroundHover: Appearance.colors.colLayer3Hover
                        contentItem: StyledText {
                            id: dismissText
                            anchors.centerIn: parent
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colOnLayer1
                            text: Translation.tr("Dismiss")
                        }
                        onClicked: Notifications.discardNotification(notifRow.modelData.notificationId)
                    }
                }
            }
        }
    }
}
