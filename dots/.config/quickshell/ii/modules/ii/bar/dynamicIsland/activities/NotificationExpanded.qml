import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Full backlog for the notification feed activity: every currently pending
 * notification (newest first), each with its own icon, app name, body, all
 * of its actions, and a dismiss button. The compact primary slot only shows
 * the newest one plus a single quick action — this is where the rest of a
 * 5-7-message burst actually gets read and acted on.
 *
 * Reuses Notifications.attemptInvokeAction/discardNotification directly
 * (the same functions the sidebar's NotificationItem.qml uses), so acting
 * here updates the sidebar too — there's no separate state to keep in sync.
 */
ColumnLayout {
    id: root

    readonly property var pending: Notifications.list

    anchors.fill: parent
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: Translation.tr("Notifications")
            }

            StyledText {
                Layout.fillWidth: true
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
                text: Translation.tr("%1 pending").arg(root.pending.length)
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 30
            implicitHeight: 30
            enabled: root.pending.length > 0
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            onClicked: Notifications.discardAllNotifications()

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                fill: 0
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSecondaryContainer
                text: "delete_sweep"
            }
        }
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
            // colLayer2 bakes its alpha assuming it's composited over the
            // opaque colLayer1Base surface (see solveOverlayColor) — inside
            // the island overlay the real backdrop is the wallpaper+tint
            // material instead, so that baked value reads as a mismatched
            // opaque block against it. Transparentize it further by the same
            // amount the wallpaper tint itself uses, so the card reads as
            // more glass sitting on glass, consistent with the pill above it.
            color: Config.options.appearance.transparency.enable ? ColorUtils.transparentize(Appearance.colors.colLayer2, Appearance.backgroundTransparency) : Appearance.colors.colLayer2

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

                    NotificationAppIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 1
                        scale: 26 / 38
                        appIcon: notifRow.modelData.appIcon ?? ""
                        image: notifRow.modelData.image ?? ""
                        notificationId: notifRow.modelData.notificationId
                        summary: notifRow.modelData.summary ?? ""
                        urgency: notifRow.modelData.urgency
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
                            wrapMode: Text.Wrap
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            textFormat: Text.RichText
                            text: NotificationUtils.processNotificationBody(notifRow.modelData.body ?? "", notifRow.modelData.appName || notifRow.modelData.summary).replace(/\n/g, "<br/>")
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
