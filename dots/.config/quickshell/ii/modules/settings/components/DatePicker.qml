import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root

    property date selectedDate: new Date()
    property date monthDate: new Date(selectedDate.getFullYear(), selectedDate.getMonth(), 1)
    signal accepted(date value)
    signal canceled()

    Layout.fillWidth: true
    focus: true
    activeFocusOnTab: true
    spacing: 12

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function monthLabel() { return Qt.locale().toString(root.monthDate, "MMMM yyyy"); }
    function dayFor(index) {
        const first = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - offset + 1);
    }
    function choose(day) { root.selectedDate = new Date(day.getFullYear(), day.getMonth(), day.getDate()); }

    RowLayout {
        Layout.fillWidth: true
        ToolButton { display: AbstractButton.IconOnly; Accessible.name: Translation.tr("Previous month"); onClicked: root.monthDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() - 1, 1); contentItem: MaterialSymbol { text: "chevron_left"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface } }
        StyledText { Layout.fillWidth: true; text: root.monthLabel(); horizontalAlignment: Text.AlignHCenter; font.pixelSize: Appearance.font.pixelSize.title; color: Appearance.colors.colOnSurface }
        ToolButton { display: AbstractButton.IconOnly; Accessible.name: Translation.tr("Next month"); onClicked: root.monthDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() + 1, 1); contentItem: MaterialSymbol { text: "chevron_right"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface } }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 4
        rowSpacing: 4
        Repeater {
            model: [Translation.tr("Mon"), Translation.tr("Tue"), Translation.tr("Wed"), Translation.tr("Thu"), Translation.tr("Fri"), Translation.tr("Sat"), Translation.tr("Sun")]
            StyledText { required property string modelData; text: modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
        }
        Repeater {
            model: 42
            delegate: Button {
                required property int index
                readonly property date day: root.dayFor(index)
                Layout.fillWidth: true
                implicitHeight: 36
                text: day.getDate()
                enabled: day.getMonth() === root.monthDate.getMonth()
                highlighted: root.sameDay(day, root.selectedDate)
                Accessible.name: Qt.locale().toString(day, "dd MMMM yyyy")
                onClicked: root.choose(day)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Button { text: Translation.tr("Cancel"); Accessible.name: text; onClicked: root.canceled() }
        Item { Layout.fillWidth: true }
        Button { text: Translation.tr("Set"); Accessible.name: text; onClicked: root.accepted(root.selectedDate) }
    }

    onSelectedDateChanged: root.monthDate = new Date(root.selectedDate.getFullYear(), root.selectedDate.getMonth(), 1)
    onVisibleChanged: if (visible) Qt.callLater(() => root.forceActiveFocus())
    Keys.onEscapePressed: root.canceled()
}
