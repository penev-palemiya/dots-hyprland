import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    visible: ScreenRecording.active
    implicitWidth: recordingRow.implicitWidth + 18
    implicitHeight: Appearance.sizes.baseBarHeight - 8
    buttonRadius: Appearance.rounding.full
    colBackground: Appearance.colors.colErrorContainer
    colBackgroundHover: Appearance.colors.colErrorContainerHover
    colRipple: Appearance.colors.colErrorContainerActive
    onPressed: ScreenRecording.stop()

    RowLayout {
        id: recordingRow
        anchors.centerIn: parent
        spacing: 5

        MaterialSymbol {
            text: "fiber_manual_record"
            color: Appearance.colors.colError
            iconSize: Appearance.font.pixelSize.small
        }

        StyledText {
            text: {
                const total = Math.max(0, ScreenRecording.elapsedSeconds);
                const minutes = Math.floor(total / 60).toString().padStart(2, "0");
                const seconds = (total % 60).toString().padStart(2, "0");
                return minutes + ":" + seconds;
            }
            color: Appearance.colors.colOnErrorContainer
            font.pixelSize: Appearance.font.pixelSize.small
        }
    }

    StyledToolTip {
        text: Translation.tr("Stop recording")
    }
}

