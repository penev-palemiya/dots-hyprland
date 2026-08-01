import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

/**
 * Primary row for the notification feed activity: shows the newest pending
 * notification (icon, app name, summary/body) plus one quick-action button
 * if it has any actions. The full backlog (all pending notifications, all
 * their actions, dismiss) lives in NotificationExpanded.qml instead — this
 * row is deliberately compact, matching Media/CapsLock's row shape.
 */
IslandActivityRow {
    id: root

    // Reads the Notifications singleton directly rather than being handed
    // the activity descriptor object — same convention as MediaPrimary.qml
    // (reads MprisController directly) and CapsLockPrimary.qml (reads
    // HyprlandXkb directly).
    readonly property var pending: Notifications.popupList
    readonly property var newest: root.pending.length > 0 ? root.pending[root.pending.length - 1] : null

    // Same priority as NotificationAppIcon.qml: raw image first, then the
    // app's icon (via Quickshell.iconPath, same as Workspaces.qml's app
    // icons), then a generic fallback glyph.
    iconOverride: iconComponent

    Component {
        id: iconComponent
        Item {
            Image {
                anchors.fill: parent
                visible: (root.newest?.image ?? "").length > 0
                source: root.newest?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }
            IconImage {
                anchors.fill: parent
                visible: (root.newest?.image ?? "").length === 0 && (root.newest?.appIcon ?? "").length > 0
                source: Quickshell.iconPath(root.newest?.appIcon ?? "", "image-missing")
            }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: (root.newest?.image ?? "").length === 0 && (root.newest?.appIcon ?? "").length === 0
                fill: 1
                text: "notifications"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.newest?.appName ?? ""
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Appearance.colors.colOnLayer1
                text: {
                    const summary = root.newest?.summary ?? "";
                    const body = root.newest?.body ?? "";
                    if (summary.length > 0 && body.length > 0)
                        return `${summary} — ${body}`;
                    return summary.length > 0 ? summary : body;
                }
            }
        }

        // One quick action — the rest live in the expanded panel. A real
        // button, so clicking it doesn't fall through to the pill's own
        // click-to-expand (same non-conflict as MediaPrimary.qml's controls).
        RippleButton {
            visible: (root.newest?.actions.length ?? 0) > 0
            Layout.alignment: Qt.AlignVCenter
            buttonRadius: Appearance.rounding.full
            implicitHeight: 26
            implicitWidth: quickActionText.implicitWidth + 16
            colBackground: Appearance.colors.colSecondaryContainer
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            contentItem: StyledText {
                id: quickActionText
                anchors.centerIn: parent
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
                text: root.newest?.actions[0]?.text ?? ""
            }
            onClicked: {
                if ((root.newest?.actions.length ?? 0) > 0)
                    Notifications.attemptInvokeAction(root.newest.notificationId, root.newest.actions[0].identifier);
            }
        }
    }
}
