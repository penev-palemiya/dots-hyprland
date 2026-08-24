import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Popup {
    id: root

    property date selectedDate: new Date()
    property date draftDate: new Date(root.selectedDate)
    property bool yearMode: false
    property int yearPageStart: Math.floor(root.draftDate.getFullYear() / 12) * 12
    signal accepted(date value)
    signal canceled()

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    width: Math.min(328, (Overlay.overlay ? Overlay.overlay.width : 700) - 32)
    height: Math.min(yearMode ? 440 : 512, (Overlay.overlay ? Overlay.overlay.height : 700) - 32)
    padding: 24
    focus: true

    readonly property var hostWindow: Window.window
    readonly property var wallpaperScreen: root.hostWindow?.wallpaperScreen
        ?? Quickshell.screens.find(screen => screen.name === root.hostWindow?.screen?.name)
        ?? Quickshell.screens[0]
        ?? null
    readonly property real hostScreenX: root.hostWindow?.wallpaperScreenX
        ?? (root.hostWindow?.x ?? 0) - (root.wallpaperScreen?.x ?? 0)
    readonly property real hostScreenY: root.hostWindow?.wallpaperScreenY
        ?? (root.hostWindow?.y ?? 0) - (root.wallpaperScreen?.y ?? 0)

    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
    function monthLabel() { return Qt.locale().toString(root.monthDate, "MMMM yyyy"); }
    function selectedLabel() { return Qt.locale().toString(root.draftDate, "ddd, MMM d"); }
    function firstWeekday() { return Qt.locale().firstDayOfWeek || 1; }
    function weekdayLabel(index) { return Qt.locale().dayName(((root.firstWeekday() - 1 + index) % 7) + 1, Locale.ShortFormat); }
    function clampedDate(year, month, day) {
        return new Date(year, month, Math.min(day, new Date(year, month + 1, 0).getDate()));
    }
    function dayFor(index) {
        const first = new Date(root.monthDate.getFullYear(), root.monthDate.getMonth(), 1);
        const firstAsLocaleDay = first.getDay() === 0 ? 7 : first.getDay();
        const offset = (firstAsLocaleDay - root.firstWeekday() + 7) % 7;
        return new Date(first.getFullYear(), first.getMonth(), index - offset + 1);
    }
    function moveMonth(delta) {
        root.draftDate = root.clampedDate(root.monthDate.getFullYear(), root.monthDate.getMonth() + delta, root.draftDate.getDate());
    }
    function choose(day) {
        if (day.getMonth() !== root.monthDate.getMonth()) return;
        root.draftDate = new Date(day.getFullYear(), day.getMonth(), day.getDate());
    }
    function moveSelection(days) {
        root.draftDate = new Date(root.draftDate.getFullYear(), root.draftDate.getMonth(), root.draftDate.getDate() + days);
    }
    readonly property date monthDate: new Date(root.draftDate.getFullYear(), root.draftDate.getMonth(), 1)

    background: Rectangle {
        id: modalBackground
        radius: Appearance.rounding.verylarge
        color: Config.options.appearance.transparency.enable
            ? Appearance.colors.colBackgroundSurfaceContainer
            : Appearance.colors.colSurfaceContainerHigh
        clip: true
        layer.enabled: Config.options.appearance.transparency.enable
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: modalBackground.width
                height: modalBackground.height
                radius: Math.min(modalBackground.radius, width / 2, height / 2)
            }
        }
        Loader {
            anchors.fill: parent
            active: Config.options.appearance.transparency.enable && root.wallpaperScreen !== null
            asynchronous: true
            sourceComponent: WallpaperBackdrop {
                screen: root.wallpaperScreen
                screenX: root.hostScreenX + root.x
                screenY: root.hostScreenY + root.y
            }
        }
        StyledRectangularShadow { target: parent }
    }

    component IconAction: RippleButton {
        required property string symbol
        required property string accessibleLabel
        implicitWidth: 48
        implicitHeight: 48
        buttonRadius: Appearance.rounding.full
        Accessible.name: accessibleLabel
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
        colRipple: Appearance.colors.colSurfaceContainerHighestActive
        contentItem: MaterialSymbol {
            text: parent.symbol
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurface
        }
    }

    component DayCell: Button {
        id: dayCell
        required property int index
        readonly property date day: root.dayFor(index)
        readonly property bool currentMonth: day.getMonth() === root.monthDate.getMonth()
        readonly property bool selected: root.sameDay(day, root.draftDate)
        readonly property bool today: root.sameDay(day, new Date())
        Layout.preferredWidth: 40
        Layout.preferredHeight: 40
        enabled: currentMonth
        opacity: currentMonth ? 1 : 0.38
        text: day.getDate()
        Accessible.name: Qt.locale().toString(day, "dd MMMM yyyy")
        Accessible.role: Accessible.Button
        onClicked: root.choose(day)
        Keys.onLeftPressed: root.moveSelection(-1)
        Keys.onRightPressed: root.moveSelection(1)
        Keys.onUpPressed: root.moveSelection(-7)
        Keys.onDownPressed: root.moveSelection(7)
        contentItem: StyledText {
            text: dayCell.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: dayCell.selected ? Appearance.colors.colOnPrimary : (dayCell.today ? Appearance.colors.colPrimary : Appearance.colors.colOnSurface)
            font.family: Appearance.font.family.numbers
        }
        background: Rectangle {
            width: 40
            height: 40
            anchors.centerIn: parent
            radius: Appearance.rounding.full
            color: dayCell.selected ? Appearance.colors.colPrimary : "transparent"
            border.width: dayCell.activeFocus ? 2 : (!dayCell.selected && dayCell.today ? 1 : 0)
            border.color: dayCell.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colPrimary
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: Appearance.colors.colOnSurface
                opacity: !dayCell.selected && dayCell.enabled && (dayCell.hovered || dayCell.down) ? (dayCell.down ? 0.10 : 0.08) : 0
                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            }
            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
        }
    }

    contentItem: ColumnLayout {
        spacing: 8

        StyledText { Layout.fillWidth: true; text: Translation.tr("Select date"); color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
        StyledText { Layout.fillWidth: true; text: root.selectedLabel(); color: Appearance.colors.colOnSurface; font.pixelSize: Appearance.font.pixelSize.display; elide: Text.ElideRight }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Appearance.colors.colOutlineVariant }

        RowLayout {
            Layout.fillWidth: true
            IconAction { symbol: "chevron_left"; accessibleLabel: root.yearMode ? Translation.tr("Previous years") : Translation.tr("Previous month"); onClicked: root.yearMode ? root.yearPageStart -= 12 : root.moveMonth(-1) }
            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                Accessible.name: root.yearMode ? Translation.tr("Select month") : Translation.tr("Select year")
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                colRipple: Appearance.colors.colSurfaceContainerHighestActive
                onClicked: { root.yearMode = !root.yearMode; root.yearPageStart = Math.floor(root.draftDate.getFullYear() / 12) * 12; }
                contentItem: RowLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    StyledText { text: root.yearMode ? `${root.yearPageStart}–${root.yearPageStart + 11}` : root.monthLabel(); color: Appearance.colors.colOnSurface; font.weight: Font.Medium }
                    MaterialSymbol { text: root.yearMode ? "arrow_drop_up" : "arrow_drop_down"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSurface }
                }
            }
            IconAction { symbol: "chevron_right"; accessibleLabel: root.yearMode ? Translation.tr("Next years") : Translation.tr("Next month"); onClicked: root.yearMode ? root.yearPageStart += 12 : root.moveMonth(1) }
        }

        GridLayout {
            visible: !root.yearMode
            Layout.alignment: Qt.AlignHCenter
            columns: 7
            columnSpacing: 0
            rowSpacing: 0
            Repeater {
                model: 7
                StyledText {
                    required property int index
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    text: root.weekdayLabel(index)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                }
            }
            Repeater { model: 42; DayCell {} }
        }

        GridLayout {
            visible: root.yearMode
            Layout.alignment: Qt.AlignHCenter
            columns: 3
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: 12
                delegate: RippleButton {
                    required property int index
                    readonly property int year: root.yearPageStart + index
                    implicitWidth: 80
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.full
                    Accessible.name: year.toString()
                    colBackground: year === root.draftDate.getFullYear() ? Appearance.colors.colPrimaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
                    colRipple: Appearance.colors.colSurfaceContainerHighestActive
                    onClicked: { root.draftDate = root.clampedDate(year, root.draftDate.getMonth(), root.draftDate.getDate()); root.yearMode = false; }
                    contentItem: StyledText { text: parent.year; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: parent.year === root.draftDate.getFullYear() ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface }
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

    onOpened: { root.draftDate = new Date(root.selectedDate); root.yearMode = false; Qt.callLater(() => root.forceActiveFocus()); }
    Keys.onEscapePressed: root.canceled()
    Keys.onReturnPressed: root.accepted(new Date(root.draftDate))
}
