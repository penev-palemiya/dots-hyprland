import QtQuick
import QtQuick.Layouts
import qs.modules.common

/**
 * Dialog header: title, a quiet status line under it, and an optional action
 * on the right.
 *
 * Replaces "just a WindowDialogTitle followed by a hard separator". The status
 * line is what a picker dialog was missing — how many things are on offer,
 * whether it's still looking — and the trailing slot gives that state
 * somewhere to be acted on (rescan) instead of being read-only.
 *
 *     WindowDialogHeader {
 *         title: "Wi-Fi"
 *         subtitle: "8 networks nearby"
 *         RippleButton { ... }        // goes in the trailing slot
 *     }
 */
RowLayout {
    id: root

    property string title: ""
    property string subtitle: ""
    default property alias actionData: actionRow.data

    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        StyledText {
            Layout.fillWidth: true
            text: root.title
            color: Appearance.colors.colOnSurface
            elide: Text.ElideRight
            font {
                family: Appearance.font.family.title
                pixelSize: Appearance.font.pixelSize.title
                variableAxes: Appearance.font.variableAxes.title
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.subtitle
            color: Appearance.colors.colOutline
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    RowLayout {
        id: actionRow

        Layout.alignment: Qt.AlignVCenter
        spacing: 6
    }
}
