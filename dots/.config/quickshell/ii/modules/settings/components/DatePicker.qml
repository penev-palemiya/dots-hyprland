import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Popup {
    id: root

    property date selectedDate: new Date()
    property date draftDate: new Date(root.selectedDate)
    signal accepted(date value)
    signal canceled()

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    width: Math.min(400, (Overlay.overlay ? Overlay.overlay.width : 700) - 32)
    height: Math.min(570, (Overlay.overlay ? Overlay.overlay.height : 700) - 32)
    padding: 24
    focus: true

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function monthLabel() { return Qt.locale().toString(root.monthDate, "MMMM yyyy"); }
    function selectedLabel() { return Qt.locale().toString(root.draftDate, "ddd, MMM d"); }
    function firstWeekday() { return Qt.locale().firstDayOfWeek || 1; }
    function weekdayLabel(index) { return Qt.locale().dayName(((root.firstWeekday() - 1 + index) % 7) + 1, Locale.ShortFormat); }
    function dayFor(index) {
        const first = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth(), 1);
        const firstAsLocaleDay = first.getDay() === 0 ? 7 : first.getDay();
        const offset = (firstAsLocaleDay - root.firstWeekday() + 7) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - offset + 1);
    }
    function choose(day) {
        if (day.getMonth() !== root.monthDate.getMonth())
            return;
        root.draftDate = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    }
    readonly property date monthDate: new Date(root.draftDate.getFullYear(), root.draftDate.getMonth(), 1)

    background: Rectangle {
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        StyledRectangularShadow { target: parent }
    }

    contentItem: ColumnLayout {
        spacing: 14

        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Select date")
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smaller
        }
        StyledText {
            Layout.fillWidth: true
            text: root.selectedLabel()
            color: Appearance.colors.colOnSurface
            font.pixelSize: Appearance.font.pixelSize.display
            elide: Text.ElideRight
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Appearance.colors.colOutlineVariant }

        RowLayout {
            Layout.fillWidth: true
            ToolButton {
                display: AbstractButton.IconOnly
                Accessible.name: Translation.tr("Previous month")
                onClicked: root.draftDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() - 1, Math.min(root.draftDate.getDate(), 28))
                contentItem: MaterialSymbol { text: "chevron_left"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.monthLabel()
                horizontalAlignment: Text.AlignHCenter
                color: Appearance.colors.colOnSurface
                font.weight: Font.Medium
            }
            ToolButton {
                display: AbstractButton.IconOnly
                Accessible.name: Translation.tr("Next month")
                onClicked: root.draftDate = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth() + 1, Math.min(root.draftDate.getDate(), 28))
                contentItem: MaterialSymbol { text: "chevron_right"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurface }
            }
        }

        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 3
            rowSpacing: 3
            Repeater {
                model: [0, 1, 2, 3, 4, 5, 6]
                StyledText {
                    required property int modelData
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 22
                    text: root.weekdayLabel(modelData)
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
            Repeater {
                model: 42
                delegate: Button {
                    required property int index
                    readonly property date day: root.dayFor(index)
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 36
                    enabled: day.getMonth() === root.monthDate.getMonth()
                    opacity: enabled ? 1 : 0.28
                    flat: true
                    text: day.getDate()
                    Accessible.name: Qt.locale().toString(day, "dd MMMM yyyy")
                    onClicked: root.choose(day)
                    contentItem: StyledText {
                        text: parent.text
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        color: parent.enabled && root.sameDay(parent.day, root.draftDate) ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface
                    }
                    background: Rectangle {
                        width: Math.min(parent.width, parent.height)
                        height: width
                        anchors.centerIn: parent
                        radius: width / 2
                        color: root.sameDay(parent.day, root.draftDate) ? Appearance.colors.colPrimary : "transparent"
                        border.color: !root.sameDay(parent.day, root.draftDate) && root.sameDay(parent.day, new Date()) ? Appearance.colors.colPrimary : "transparent"
                        border.width: 1
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.canceled() }
            DialogButton { buttonText: Translation.tr("OK"); onClicked: root.accepted(new Date(root.draftDate)) }
        }
    }

    onOpened: {
        root.draftDate = new Date(root.selectedDate);
        Qt.callLater(() => root.forceActiveFocus());
    }
    Keys.onEscapePressed: root.canceled()
}
