import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Numeric setting editor: a single tonal pill holding [-] [value unit] [+].
 *
 * Shaped as a sibling of StyledComboBox (same 40px height, same pill radius,
 * same secondary-container tone) so a row with a stepper and a row with a
 * dropdown read as the same kind of control. The older layout - an outlined
 * text field with two loose square buttons next to it - was three competing
 * shapes in a row that only holds one setting.
 *
 * The value stays directly editable: the centre is a real text input, so
 * typing a number works exactly as before and the steppers are just a faster
 * path for small adjustments.
 */
RowLayout {
    id: root

    property real value: 0
    property real minimum: 0
    property real maximum: 999999
    property real step: 1
    property bool integer: true
    property bool allowEmpty: false
    property string unit: ""
    property string editingText: root.formatValue(root.value)
    property bool inputValid: root.validate(root.editingText)
    signal committed(real value)
    signal textCommitted(string text)

    // SettingsRow places trailing controls in a plain Item rather than a
    // Layout, so Layout.preferredWidth alone would leave this editor at its
    // default zero width. Keep both hints for use in either context.
    implicitWidth: 150
    Layout.preferredWidth: 150
    spacing: 0

    function formatValue(value) { return root.integer ? Math.round(value).toString() : Number(value).toString(); }
    function validate(text) {
        const trimmed = String(text).trim();
        if (trimmed === "") return root.allowEmpty;
        if (trimmed === "-" || trimmed === "." || trimmed === "-.") return false;
        if (!/^[-+]?\d+(\.\d+)?$/.test(trimmed)) return false;
        const number = Number(trimmed);
        return Number.isFinite(number) && number >= root.minimum && number <= root.maximum;
    }
    function commit() {
        if (!root.validate(root.editingText)) { invalidFlash.restart(); return false; }
        if (String(root.editingText).trim() === "") { root.textCommitted(""); return true; }
        const next = root.integer ? Math.round(Number(root.editingText)) : Number(root.editingText);
        root.editingText = root.formatValue(next);
        root.committed(next);
        root.textCommitted(root.editingText);
        return true;
    }
    function stepBy(delta) {
        const next = Math.max(root.minimum, Math.min(root.maximum, Number(root.value) + delta * root.step));
        root.editingText = root.formatValue(next);
        root.commit();
    }

    onValueChanged: if (!field.activeFocus) root.editingText = root.formatValue(root.value)

    component StepButton: Item {
        id: stepButton

        required property string symbol
        required property real delta
        required property string accessibleName

        readonly property bool actionable: stepButton.enabled && root.enabled

        implicitWidth: 40
        implicitHeight: 40
        activeFocusOnTab: stepButton.actionable
        Accessible.name: stepButton.accessibleName
        Accessible.role: Accessible.Button
        opacity: stepButton.actionable ? 1 : 0.38

        // Round state layer inside the pill's square end, the way an M3 icon
        // button sits inside a segmented container.
        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: width / 2
            color: Appearance.colors.colOnSecondaryContainer
            opacity: stepButton.actionable && (buttonArea.containsMouse || stepButton.activeFocus)
                ? (buttonArea.pressed ? 0.1 : 0.08) : 0

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: stepButton.symbol
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSecondaryContainer
        }

        MouseArea {
            id: buttonArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: stepButton.actionable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stepBy(stepButton.delta)

            // Press-and-hold to run through a range instead of clicking 20 times.
            onPressAndHold: repeatTimer.start()
            onReleased: repeatTimer.stop()
            onCanceled: repeatTimer.stop()
        }

        Timer {
            id: repeatTimer
            interval: 90
            repeat: true
            onTriggered: root.stepBy(stepButton.delta)
        }

        Keys.onEnterPressed: if (stepButton.actionable) root.stepBy(stepButton.delta)
        Keys.onReturnPressed: if (stepButton.actionable) root.stepBy(stepButton.delta)
        Keys.onSpacePressed: if (stepButton.actionable) root.stepBy(stepButton.delta)
    }

    Rectangle {
        id: pill
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        // Two 40px ends plus room for a couple of digits; below this the
        // steppers would start eating the value.
        Layout.minimumWidth: 120
        implicitWidth: 150
        implicitHeight: 40
        radius: height / 2
        color: Appearance.colors.colSecondaryContainer
        border.color: field.activeFocus ? Appearance.colors.colPrimary : "transparent"
        border.width: field.activeFocus ? 2 : 0
        opacity: root.enabled ? 1 : 0.4

        RowLayout {
            anchors.fill: parent
            spacing: 0

            StepButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "remove"
                delta: -1
                accessibleName: Translation.tr("Decrease")
                enabled: root.value > root.minimum
            }

            // The value and its unit travel together as one centred block, so
            // "20 %" doesn't drift left while the unit hugs the plus button.
            // The clipping Item keeps a long unit ("Minute") from spilling out
            // past the pill's rounded end.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    StyledTextInput {
                        id: field
                        anchors.verticalCenter: parent.verticalCenter
                        // Sized to the text so the pair stays centred as a
                        // unit; a floor keeps single digits from collapsing
                        // the caret out of sight.
                        width: Math.max(18, contentWidth + 2)
                        text: root.editingText
                        horizontalAlignment: TextInput.AlignRight
                        inputMethodHints: root.integer ? Qt.ImhDigitsOnly : Qt.ImhFormattedNumbersOnly
                        Accessible.name: root.unit ? Translation.tr("Value") + " (" + root.unit + ")" : Translation.tr("Value")
                        color: root.inputValid ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colError
                        font.family: Appearance.font.family.numbers
                        font.variableAxes: Appearance.font.variableAxes.numbers
                        font.pixelSize: Appearance.font.pixelSize.normal
                        onTextChanged: if (text !== root.editingText) root.editingText = text
                        onAccepted: root.commit()
                        onEditingFinished: root.commit()
                        onActiveFocusChanged: {
                            if (activeFocus)
                                selectAll();
                            else
                                root.commit();
                        }

                        Keys.onUpPressed: root.stepBy(1)
                        Keys.onDownPressed: root.stepBy(-1)
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.unit.length > 0
                        text: root.unit
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnSecondaryContainer
                        opacity: 0.7
                    }
                }
            }

            StepButton {
                Layout.alignment: Qt.AlignVCenter
                symbol: "add"
                delta: 1
                accessibleName: Translation.tr("Increase")
                enabled: root.value < root.maximum
            }
        }
    }

    SequentialAnimation {
        id: invalidFlash
        NumberAnimation {
            target: pill
            property: "opacity"
            to: 0.55
            duration: 80
        }
        NumberAnimation {
            target: pill
            property: "opacity"
            to: 1
            duration: 180
        }
    }
}
