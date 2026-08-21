import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool showDate: Config.options.bar.verbose
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 4

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOutline
            text: "•"
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOutline
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent

        onClicked: BarPopups.toggle("clock")

        ClockWidgetPopup {
            hoverTarget: mouseArea
            shown: BarPopups.activePopupId === "clock"
            onDismissRequested: BarPopups.close()
        }
    }
}
