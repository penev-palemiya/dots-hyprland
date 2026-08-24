import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Popup {
    id: root

    property int hour: 0
    property int minute: 0
    property bool format24Hour: true
    property int draftHour: root.hour
    property int draftMinute: root.minute
    property bool inputMode: root.format24Hour
    property bool minuteMode: false
    signal accepted(int hour, int minute)
    signal canceled()

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    modal: true
    dim: true
    closePolicy: Popup.NoAutoClose
    width: Math.min(430, (Overlay.overlay ? Overlay.overlay.width : 700) - 32)
    height: Math.min(600, (Overlay.overlay ? Overlay.overlay.height : 700) - 32)
    padding: 24
    focus: true

    function hour12() { const value = root.draftHour % 12; return value === 0 ? 12 : value; }
    function period() { return root.draftHour >= 12 ? "PM" : "AM"; }
    function setPeriod(value) {
        const h = root.hour12();
        root.draftHour = value === "PM" ? (h === 12 ? 12 : h + 12) : (h === 12 ? 0 : h);
    }
    function valid() { return root.draftHour >= 0 && root.draftHour <= 23 && root.draftMinute >= 0 && root.draftMinute <= 59; }
    function dialValueAt(x, y) {
        const cx = dial.width / 2;
        const cy = dial.height / 2;
        let degrees = Math.atan2(y - cy, x - cx) * 180 / Math.PI + 90;
        if (degrees < 0) degrees += 360;
        const index = Math.round(degrees / 30) % 12;
        return root.minuteMode ? index * 5 : (index === 0 ? 12 : index);
    }
    function chooseDial(x, y) {
        const value = root.dialValueAt(x, y);
        if (root.minuteMode)
            root.draftMinute = value;
        else {
            const h = value === 12 ? 0 : value;
            root.draftHour = root.format24Hour ? (root.period() === "PM" ? h + 12 : h) : (root.period() === "PM" ? h + 12 : h);
            root.minuteMode = true;
        }
    }

    background: Rectangle {
        radius: Appearance.rounding.large
        color: Appearance.m3colors.m3surfaceContainerHigh
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        StyledRectangularShadow { target: parent }
    }

    contentItem: ColumnLayout {
        spacing: 14

        StyledText { Layout.fillWidth: true; text: root.inputMode ? Translation.tr("Enter time") : Translation.tr("Select time"); color: Appearance.colors.colOnSurfaceVariant; font.pixelSize: Appearance.font.pixelSize.smaller }
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            Button {
                Accessible.name: Translation.tr("Hour")
                flat: true
                text: (root.format24Hour ? root.draftHour : root.hour12()).toString().padStart(2, "0")
                highlighted: !root.minuteMode
                onClicked: root.minuteMode = false
                contentItem: StyledText { text: parent.text; color: parent.highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface; font.pixelSize: Appearance.font.pixelSize.display; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: Appearance.rounding.normal; color: parent.highlighted ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest }
            }
            StyledText { text: ":"; color: Appearance.colors.colOnSurface; font.pixelSize: Appearance.font.pixelSize.display }
            Button {
                Accessible.name: Translation.tr("Minute")
                flat: true
                text: root.draftMinute.toString().padStart(2, "0")
                highlighted: root.minuteMode
                onClicked: root.minuteMode = true
                contentItem: StyledText { text: parent.text; color: parent.highlighted ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface; font.pixelSize: Appearance.font.pixelSize.display; horizontalAlignment: Text.AlignHCenter }
                background: Rectangle { radius: Appearance.rounding.normal; color: parent.highlighted ? Appearance.colors.colPrimary : Appearance.colors.colSurfaceContainerHighest }
            }
            ColumnLayout {
                visible: !root.format24Hour
                spacing: 3
                Button { text: "AM"; flat: true; highlighted: root.period() === "AM"; Accessible.name: Translation.tr("AM"); onClicked: root.setPeriod("AM") }
                Button { text: "PM"; flat: true; highlighted: root.period() === "PM"; Accessible.name: Translation.tr("PM"); onClicked: root.setPeriod("PM") }
            }
        }

        RowLayout {
            visible: root.inputMode
            Layout.fillWidth: true
            NumberInput { Layout.fillWidth: true; value: root.format24Hour ? root.draftHour : root.hour12(); minimum: root.format24Hour ? 0 : 1; maximum: root.format24Hour ? 23 : 12; unit: Translation.tr("Hour"); onCommitted: value => root.draftHour = root.format24Hour ? value : (root.period() === "PM" ? (value === 12 ? 12 : value + 12) : (value === 12 ? 0 : value)) }
            NumberInput { Layout.fillWidth: true; value: root.draftMinute; minimum: 0; maximum: 59; unit: Translation.tr("Minute"); onCommitted: value => root.draftMinute = value }
        }

        Item {
            id: dialArea
            visible: !root.inputMode
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 270
            Layout.preferredHeight: 270
            Canvas {
                id: dial
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    const cx = width / 2, cy = height / 2, radius = width * 0.44;
                    ctx.clearRect(0, 0, width, height);
                    ctx.fillStyle = Appearance.colors.colSurfaceContainerHighest;
                    ctx.beginPath(); ctx.arc(cx, cy, radius + 12, 0, Math.PI * 2); ctx.fill();
                    const count = 12;
                    for (let i = 0; i < count; i++) {
                        const value = root.minuteMode ? i * 5 : (i === 0 ? 12 : i);
                        const angle = i * Math.PI / 6 - Math.PI / 2;
                        const x = cx + Math.cos(angle) * radius;
                        const y = cy + Math.sin(angle) * radius;
                        const active = root.minuteMode ? value === root.draftMinute : value === root.hour12();
                        if (active) { ctx.fillStyle = Appearance.colors.colPrimary; ctx.beginPath(); ctx.arc(x, y, 18, 0, Math.PI * 2); ctx.fill(); }
                        ctx.fillStyle = active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSurface;
                        ctx.font = `${Appearance.font.pixelSize.normal}px sans-serif`;
                        ctx.textAlign = "center"; ctx.textBaseline = "middle"; ctx.fillText(value.toString(), x, y);
                    }
                    const selected = root.minuteMode ? root.draftMinute / 5 : root.hour12() % 12;
                    const handAngle = selected * Math.PI / 6 - Math.PI / 2;
                    ctx.strokeStyle = Appearance.colors.colPrimary; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(handAngle) * radius, cy + Math.sin(handAngle) * radius); ctx.stroke();
                    ctx.fillStyle = Appearance.colors.colPrimary; ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI * 2); ctx.fill();
                }
                MouseArea { anchors.fill: parent; onClicked: root.chooseDial(mouse.x, mouse.y) }
            }
        }

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            ToolButton { display: AbstractButton.IconOnly; Accessible.name: root.inputMode ? Translation.tr("Use clock mode") : Translation.tr("Enter time"); onClicked: root.inputMode = !root.inputMode; contentItem: MaterialSymbol { text: root.inputMode ? "schedule" : "keyboard"; iconSize: Appearance.font.pixelSize.larger; color: Appearance.colors.colOnSurfaceVariant } }
            Item { Layout.fillWidth: true }
            DialogButton { buttonText: Translation.tr("Cancel"); onClicked: root.canceled() }
            DialogButton { buttonText: Translation.tr("OK"); enabled: root.valid(); onClicked: root.accepted(root.draftHour, root.draftMinute) }
        }
    }

    onOpened: {
        root.draftHour = root.hour;
        root.draftMinute = root.minute;
        root.minuteMode = false;
        Qt.callLater(() => root.forceActiveFocus());
    }
    Keys.onEscapePressed: root.canceled()
}
