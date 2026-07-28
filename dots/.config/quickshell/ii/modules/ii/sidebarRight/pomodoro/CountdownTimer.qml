import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    readonly property bool idle: !TimerService.countdownRunning && TimerService.countdownSecondsLeft <= 0
    property int inputHours: Math.floor(Config.options.time.countdown.defaultDuration / 3600)
    property int inputMinutes: Math.floor((Config.options.time.countdown.defaultDuration % 3600) / 60)
    property int inputSeconds: Config.options.time.countdown.defaultDuration % 60

    implicitHeight: contentColumn.implicitHeight
    implicitWidth: contentColumn.implicitWidth

    // Fixed measurement for the two-digit number, so the layout doesn't
    // jitter in width as the digits change (e.g. "1" vs "8" vs "00").
    TextMetrics {
        id: digitMetrics
        font.pixelSize: 36
        font.family: Appearance.font.family.numbers
        text: "00"
    }

    // A single hour/minute/second column: up arrow, digit + unit suffix, down arrow
    component DigitStepper: ColumnLayout {
        id: stepper
        required property int value
        property int min: 0
        property int max: 99
        property string unit: ""
        signal changed(int newValue)
        spacing: 2

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colLayer2
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "keyboard_arrow_up"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }
            onClicked: stepper.changed(stepper.value >= stepper.max ? stepper.min : stepper.value + 1)
        }
        Item {
            id: digitContainer
            // Fixed to the digit's own width (not the digit+suffix combined),
            // so the digit itself stays centered under the arrow buttons
            // regardless of how wide the (purely decorative) suffix is.
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: digitMetrics.width
            implicitHeight: digitInput.implicitHeight

            StyledTextInput {
                id: digitInput
                anchors.centerIn: parent
                text: stepper.value.toString().padStart(2, '0')
                font.pixelSize: 36
                font.family: Appearance.font.family.numbers
                horizontalAlignment: TextInput.AlignHCenter
                color: Appearance.m3colors.m3onSurface
                selectByMouse: true
                maximumLength: 2
                validator: IntValidator {
                    bottom: stepper.min
                    top: stepper.max
                }

                function resetToValue() {
                    text = Qt.binding(() => stepper.value.toString().padStart(2, '0'));
                }
                function commit() {
                    let parsed = parseInt(text, 10);
                    if (isNaN(parsed))
                        parsed = stepper.min;
                    parsed = Math.max(stepper.min, Math.min(stepper.max, parsed));
                    stepper.changed(parsed);
                    resetToValue();
                }

                onActiveFocusChanged: {
                    if (activeFocus)
                        Qt.callLater(() => selectAll());
                    else
                        commit();
                }
                onAccepted: root.forceActiveFocus()
                Keys.onEscapePressed: {
                    resetToValue();
                    root.forceActiveFocus();
                }
            }
            StyledText {
                anchors.left: digitInput.right
                anchors.baseline: digitInput.baseline
                anchors.leftMargin: 2
                text: stepper.unit
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colLayer2
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "keyboard_arrow_down"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer2
            }
            onClicked: stepper.changed(stepper.value <= stepper.min ? stepper.max : stepper.value - 1)
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        spacing: 0

        // Duration entry, shown when idle
        RowLayout {
            visible: root.idle
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 40
            Layout.bottomMargin: 40
            spacing: 16

            DigitStepper {
                value: root.inputHours
                max: 23
                unit: Translation.tr("h")
                onChanged: newValue => root.inputHours = newValue
            }
            DigitStepper {
                value: root.inputMinutes
                max: 59
                unit: Translation.tr("m")
                onChanged: newValue => root.inputMinutes = newValue
            }
            DigitStepper {
                value: root.inputSeconds
                max: 59
                unit: Translation.tr("s")
                onChanged: newValue => root.inputSeconds = newValue
            }
        }

        // The countdown ring, shown when running or paused
        CircularProgress {
            visible: !root.idle
            Layout.alignment: Qt.AlignHCenter
            lineWidth: 8
            value: TimerService.countdownDuration > 0 ? (TimerService.countdownSecondsLeft / TimerService.countdownDuration) : 0
            implicitSize: 200
            enableAnimation: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: {
                        const secondsLeft = TimerService.countdownSecondsLeft;
                        const minutes = Math.floor(secondsLeft / 60) % 60;
                        const seconds = Math.floor(secondsLeft % 60).toString().padStart(2, '0');
                        if (TimerService.countdownDuration >= 3600) {
                            const hours = Math.floor(secondsLeft / 3600);
                            return `${hours}:${minutes.toString().padStart(2, '0')}:${seconds}`;
                        }
                        return `${minutes.toString().padStart(2, '0')}:${seconds}`;
                    }
                    font.pixelSize: 36
                    color: Appearance.m3colors.m3onSurface
                }
            }
        }

        // The Start/Pause and Reset buttons
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10

            RippleButton {
                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: TimerService.countdownRunning ? Translation.tr("Pause") : root.idle ? Translation.tr("Start") : Translation.tr("Resume")
                    color: TimerService.countdownRunning ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnPrimary
                }
                implicitHeight: 35
                implicitWidth: 90
                font.pixelSize: Appearance.font.pixelSize.larger
                onClicked: {
                    if (root.idle)
                        TimerService.startCountdown(root.inputHours * 3600 + root.inputMinutes * 60 + root.inputSeconds);
                    else
                        TimerService.toggleCountdown();
                }
                colBackground: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
                colBackgroundHover: TimerService.countdownRunning ? Appearance.colors.colSecondaryContainer : Appearance.colors.colPrimary
            }

            RippleButton {
                implicitHeight: 35
                implicitWidth: 90

                onClicked: TimerService.resetCountdown()
                enabled: !root.idle

                font.pixelSize: Appearance.font.pixelSize.larger
                colBackground: Appearance.colors.colErrorContainer
                colBackgroundHover: Appearance.colors.colErrorContainerHover
                colRipple: Appearance.colors.colErrorContainerActive

                contentItem: StyledText {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: Translation.tr("Reset")
                    color: Appearance.colors.colOnErrorContainer
                }
            }
        }
    }
}
