import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property int hour: 0
    property int minute: 0
    property bool format24Hour: true
    property int editingHour: root.hour
    property int editingMinute: root.minute
    readonly property bool valid: root.editingHour >= 0 && root.editingHour <= 23 && root.editingMinute >= 0 && root.editingMinute <= 59

    signal accepted(int hour, int minute)
    signal canceled()

    Layout.fillWidth: true
    focus: true
    activeFocusOnTab: true
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        NumberInput {
            Layout.preferredWidth: 116
            value: root.editingHour
            minimum: 0
            maximum: 23
            integer: true
            onTextCommitted: text => { if (text.length > 0) root.editingHour = Number(text); }
        }
        StyledText { text: ":"; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.title }
        NumberInput {
            Layout.preferredWidth: 116
            value: root.editingMinute
            minimum: 0
            maximum: 59
            integer: true
            onTextCommitted: text => { if (text.length > 0) root.editingMinute = Number(text); }
        }
        StyledText {
            text: root.format24Hour ? Translation.tr("24-hour") : Translation.tr("12-hour")
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Button { text: Translation.tr("Cancel"); Accessible.name: text; onClicked: root.canceled() }
        Item { Layout.fillWidth: true }
        Button { text: Translation.tr("Set"); enabled: root.valid; Accessible.name: text; onClicked: root.accepted(root.editingHour, root.editingMinute) }
    }

    onVisibleChanged: if (visible) Qt.callLater(() => root.forceActiveFocus())
    Keys.onEscapePressed: root.canceled()
}
