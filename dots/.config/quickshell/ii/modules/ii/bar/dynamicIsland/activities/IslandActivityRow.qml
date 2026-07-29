import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Shared skeleton for a primary activity row: an icon chip on the left,
 * then whatever activity-specific content fills the rest of the width.
 * This lives INSIDE the bar's fixed-height pill, so icon-chip sizing must
 * follow the bar-scale convention — matched to Workspaces.qml's
 * workspaceButtonWidth (26px), not the popup-card scale (WeatherCard/
 * ResourceCard use a bigger chip because popups have much more room —
 * see docs/design/bar-popups.md).
 */
RowLayout {
    id: root

    default property alias content: contentSlot.data
    property alias icon: iconSymbol.text
    property alias iconColor: iconSymbol.color

    spacing: 6

    Rectangle {
        Layout.alignment: Qt.AlignVCenter
        radius: Appearance.rounding.full
        color: Appearance.colors.colSecondaryContainer
        implicitWidth: 26
        implicitHeight: implicitWidth

        MaterialSymbol {
            id: iconSymbol
            anchors.centerIn: parent
            fill: 1
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSecondaryContainer
        }
    }

    Item {
        id: contentSlot
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: childrenRect.height
    }
}
