import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Popup {
    id: root

    property int hour: 0
    property int minute: 0
    property bool format24Hour: true
    property int draftHour: root.hour
    property int draftMinute: root.minute
    property bool inputMode: false
    property bool minuteMode: false
    signal accepted(int hour, int minute)
    signal canceled()

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    width: Math.min(328, (Overlay.overlay ? Overlay.overlay.width : 700) - 32)
    height: Math.min(inputMode ? 360 : 500, (Overlay.overlay ? Overlay.overlay.height : 700) - 32)
    padding: 24
    focus: true


    function hour12() { const value = root.draftHour % 12; return value === 0 ? 12 : value; }
    function period() { return root.draftHour >= 12 ? "PM" : "AM"; }
    function setPeriod(value) { const h = root.hour12(); root.draftHour = value === "PM" ? (h === 12 ? 12 : h + 12) : (h === 12 ? 0 : h); }
    function valid() { return root.draftHour >= 0 && root.draftHour <= 23 && root.draftMinute >= 0 && root.draftMinute <= 59; }
    function dialAngle() { return (root.minuteMode ? root.draftMinute / 5 : root.hour12() % 12) * 30; }
    function dialHandLength() {
        return !root.minuteMode && root.format24Hour && root.draftHour >= 12 ? dial.radius * 0.56 : dial.radius;
    }
    function dialValueAt(x, y) {
        const dx = x - dial.width / 2, dy = y - dial.height / 2;
        let degrees = Math.atan2(dy, dx) * 180 / Math.PI + 90;
        if (degrees < 0) degrees += 360;
        const index = Math.round(degrees / 30) % 12;
        if (root.minuteMode) return index * 5;
        if (!root.format24Hour) return index === 0 ? 12 : index;
        const inner = Math.sqrt(dx * dx + dy * dy) < dial.radius * 0.76;
        return inner ? (index === 0 ? 12 : index + 12) : index;
    }
    function chooseDial(x, y) {
        const value = root.dialValueAt(x, y);
        if (root.minuteMode) root.draftMinute = value;
        else { root.draftHour = value; root.minuteMode = true; }
    }
    function adjustDial(delta) {
        if (root.minuteMode)
            root.draftMinute = (root.draftMinute + delta * 5 + 60) % 60;
        else if (root.format24Hour)
            root.draftHour = (root.draftHour + delta + 24) % 24;
        else {
            const next = ((root.hour12() - 1 + delta + 12) % 12) + 1;
            root.draftHour = root.period() === "PM" ? (next === 12 ? 12 : next + 12) : (next === 12 ? 0 : next);
        }
    }
    function setHourText(text) {
        const value = Number(text);
        if (Number.isInteger(value) && value >= (root.format24Hour ? 0 : 1) && value <= (root.format24Hour ? 23 : 12))
            root.draftHour = root.format24Hour ? value : (root.period() === "PM" ? (value === 12 ? 12 : value + 12) : (value === 12 ? 0 : value));
    }

    background: Rectangle {
        radius: Appearance.rounding.verylarge
        // A modal dialog inside an already-blurred window is a plain surface,
        // not a second sheet of glass. The compositor blurs what is behind the
        // *window*; this sits on top of the window's own content, so imitating
        // wallpaper glass here meant hand-cropping the wallpaper and tracking
        // the host window's position to keep the crop aligned - which is late
        // by construction and went stale the moment that tracking was removed.
        // Opaque is also what M3 and the ChromeOS reference specify for dialogs.
        color: Appearance.m3colors.m3surfaceContainerHigh
        StyledRectangularShadow { target: parent }
    }

    component DisplayCell: Button {
        id: displayCell
        required property bool selected
        required property string label
        implicitWidth: 96
        implicitHeight: 80
        Accessible.name: label
        contentItem: StyledText { text: displayCell.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Appearance.font.family.numbers; font.pixelSize: Appearance.font.pixelSize.display; color: displayCell.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface }
        background: Rectangle {
            radius: Appearance.rounding.verysmall
            color: displayCell.selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSurfaceContainerHighest
            border.width: displayCell.activeFocus ? 2 : 0
            border.color: Appearance.colors.colPrimary
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: displayCell.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSurface
                opacity: displayCell.hovered || displayCell.down ? (displayCell.down ? 0.10 : 0.08) : 0
                Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
            }
            Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
        }
    }

    contentItem: ColumnLayout {
        spacing: 12
        StyledText { Layout.fillWidth: true; text: root.inputMode ? Translation.tr("Enter time") : Translation.tr("Select time"); color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            DisplayCell { text: (root.format24Hour ? root.draftHour : root.hour12()).toString().padStart(2, "0"); selected: !root.minuteMode; label: Translation.tr("Hour"); onClicked: root.minuteMode = false }
            StyledText { text: ":"; color: Appearance.colors.colOnSurface; font.pixelSize: Appearance.font.pixelSize.display }
            DisplayCell { text: root.draftMinute.toString().padStart(2, "0"); selected: root.minuteMode; label: Translation.tr("Minute"); onClicked: root.minuteMode = true }
            Rectangle {
                visible: !root.format24Hour
                implicitWidth: 52
                implicitHeight: 80
                radius: Appearance.rounding.verysmall
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutline
                Column {
                    anchors.fill: parent
                    Repeater {
                        model: ["AM", "PM"]
                        delegate: Button {
                            id: periodButton
                            required property string modelData
                            width: 50; height: 40
                            text: modelData
                            Accessible.name: modelData
                            onClicked: root.setPeriod(modelData)
                            contentItem: StyledText { text: periodButton.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; color: root.period() === periodButton.text ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnSurface }
                            background: Rectangle {
                                radius: Appearance.rounding.verysmall
                                color: root.period() === periodButton.text ? Appearance.colors.colTertiaryContainer : "transparent"
                                border.width: periodButton.activeFocus ? 2 : 0
                                border.color: Appearance.colors.colPrimary
                                Rectangle {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    color: root.period() === periodButton.text ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnSurface
                                    opacity: periodButton.hovered || periodButton.down ? (periodButton.down ? 0.10 : 0.08) : 0
                                    Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            visible: root.inputMode
            Layout.fillWidth: true
            spacing: 8
            TextField {
                id: hourField
                Layout.fillWidth: true
                text: (root.format24Hour ? root.draftHour : root.hour12()).toString().padStart(2, "0")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: root.format24Hour ? 0 : 1; top: root.format24Hour ? 23 : 12 }
                Accessible.name: Translation.tr("Hour")
                horizontalAlignment: TextInput.AlignHCenter
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurface
                onAccepted: root.setHourText(text)
                onEditingFinished: root.setHourText(text)
                background: Rectangle {
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colSurfaceContainerHighest
                    border.width: hourField.activeFocus ? 2 : 0
                    border.color: Appearance.colors.colPrimary
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.colors.colOnSurface
                        opacity: hourField.hovered ? 0.08 : 0
                        Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                    }
                }
            }
            TextField {
                id: minuteField
                Layout.fillWidth: true
                text: root.draftMinute.toString().padStart(2, "0")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 59 }
                Accessible.name: Translation.tr("Minute")
                horizontalAlignment: TextInput.AlignHCenter
                font.family: Appearance.font.family.numbers
                font.pixelSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnSurface
                onAccepted: { const value = Number(text); if (Number.isInteger(value) && value >= 0 && value <= 59) root.draftMinute = value; }
                onEditingFinished: { const value = Number(text); if (Number.isInteger(value) && value >= 0 && value <= 59) root.draftMinute = value; }
                background: Rectangle {
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colSurfaceContainerHighest
                    border.width: minuteField.activeFocus ? 2 : 0
                    border.color: Appearance.colors.colPrimary
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Appearance.colors.colOnSurface
                        opacity: minuteField.hovered ? 0.08 : 0
                        Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                    }
                }
            }
        }

        Item {
            visible: !root.inputMode
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 256
            implicitHeight: 256
            Item {
                id: dial
                anchors.fill: parent
                property real radius: width / 2 - 24
                Rectangle { anchors.fill: parent; radius: width / 2; color: Appearance.colors.colSurfaceContainerHighest }
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colors.colOnSurface
                    opacity: dialMouse.containsMouse || dialMouse.pressed ? (dialMouse.pressed ? 0.10 : 0.08) : 0
                    Behavior on opacity { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this) }
                }
                Rectangle {
                    id: hand
                    width: 2; height: root.dialHandLength()
                    x: dial.width / 2 - width / 2; y: dial.height / 2 - height
                    color: Appearance.colors.colPrimary
                    transform: Rotation {
                        id: handRotation
                        origin.x: 1
                        origin.y: hand.height
                        angle: root.dialAngle()
                        Behavior on angle { NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve } }
                    }
                }
                Rectangle { width: 8; height: 8; anchors.centerIn: parent; radius: Appearance.rounding.full; color: Appearance.colors.colPrimary }
                Repeater {
                    model: 12
                    delegate: Item {
                        required property int index
                        readonly property real angle: index * Math.PI / 6 - Math.PI / 2
                        readonly property bool active: root.minuteMode ? index * 5 === root.draftMinute : (root.format24Hour ? root.draftHour < 12 && index === root.draftHour : (index === 0 ? 12 : index) === root.hour12())
                        width: 48; height: 48
                        x: dial.width / 2 + Math.cos(angle) * dial.radius - width / 2
                        y: dial.height / 2 + Math.sin(angle) * dial.radius - height / 2
                        Rectangle { anchors.fill: parent; radius: Appearance.rounding.full; color: parent.active ? Appearance.colors.colPrimary : "transparent" }
                        StyledText { anchors.centerIn: parent; text: root.minuteMode ? (index * 5).toString().padStart(2, "0") : (root.format24Hour ? index.toString().padStart(2, "0") : (index === 0 ? 12 : index)); font.family: Appearance.font.family.numbers; color: parent.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface }
                    }
                }
                Repeater {
                    visible: root.format24Hour && !root.minuteMode
                    model: 12
                    delegate: Item {
                        required property int index
                        readonly property real angle: index * Math.PI / 6 - Math.PI / 2
                        readonly property int value: index === 0 ? 12 : index + 12
                        readonly property bool active: root.draftHour === value
                        width: 48; height: 48
                        x: dial.width / 2 + Math.cos(angle) * dial.radius * 0.56 - width / 2
                        y: dial.height / 2 + Math.sin(angle) * dial.radius * 0.56 - height / 2
                        Rectangle { anchors.fill: parent; radius: Appearance.rounding.full; color: parent.active ? Appearance.colors.colPrimary : "transparent" }
                        StyledText { anchors.fill: parent; text: parent.value.toString().padStart(2, "0"); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Appearance.font.family.numbers; color: parent.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurfaceVariant }
                    }
                }
                MouseArea {
                    id: dialMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    activeFocusOnTab: true
                    Accessible.name: root.minuteMode ? Translation.tr("Minutes clock") : Translation.tr("Hours clock")
                    Accessible.role: Accessible.Button
                    onPressed: mouse => root.chooseDial(mouse.x, mouse.y)
                    onPositionChanged: mouse => { if (pressed) root.chooseDial(mouse.x, mouse.y); }
                    Keys.onLeftPressed: root.adjustDial(-1)
                    Keys.onDownPressed: root.adjustDial(-1)
                    Keys.onRightPressed: root.adjustDial(1)
                    Keys.onUpPressed: root.adjustDial(1)
                }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            RippleButton {
                implicitWidth: 40; implicitHeight: 40; buttonRadius: Appearance.rounding.full
                Accessible.name: root.inputMode ? Translation.tr("Use clock mode") : Translation.tr("Enter time")
                colBackground: "transparent"; colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover; colRipple: Appearance.colors.colSurfaceContainerHighestActive
                onClicked: root.inputMode = !root.inputMode
                contentItem: MaterialSymbol { text: root.inputMode ? "schedule" : "keyboard"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurfaceVariant }
            }
            Item { Layout.fillWidth: true }
            DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.canceled() }
            DialogButton { buttonText: Translation.tr("OK"); enabled: root.valid(); onClicked: root.accepted(root.draftHour, root.draftMinute) }
        }
    }

    onOpened: { root.draftHour = root.hour; root.draftMinute = root.minute; root.minuteMode = false; root.inputMode = false; Qt.callLater(() => root.forceActiveFocus()); }
    Keys.onEscapePressed: root.canceled()
    Keys.onReturnPressed: if (root.valid()) root.accepted(root.draftHour, root.draftMinute)
}
