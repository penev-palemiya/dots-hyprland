import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    
    radius: Appearance.rounding.small
    topLeftRadius: root.corners ? root.corners.topLeft : root.radius
    topRightRadius: root.corners ? root.corners.topRight : root.radius
    bottomLeftRadius: root.corners ? root.corners.bottomLeft : root.radius
    bottomRightRadius: root.corners ? root.corners.bottomRight : root.radius
    color: Appearance.colors.colSurfaceContainerHighest
    
    Layout.fillWidth: true
    implicitWidth: mainRow.implicitWidth + 32
    implicitHeight: mainRow.implicitHeight + 10

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text
    // Optional per-corner radii, supplied by GroupedGrid so a grid of cards
    // can read as one rounded block. Null means "just use `radius`", which is
    // what every standalone use of this card wants.
    property var corners: null
    // Optional hairline usage bar under the value, for the one case
    // docs/design/bar-popups.md says a bar earns its place: a value that
    // genuinely is "N out of a total". Negative (the default) draws nothing,
    // so every existing caller — weather's own tiles, BatteryPopup — is
    // untouched. This is deliberately an extension of the one tile component
    // rather than a third card variant, which that doc warns against.
    property real percentage: -1
    property bool warning: false

    RowLayout {
        id: mainRow
        anchors {
             left: parent.left
             right: parent.right
             verticalCenter: parent.verticalCenter
             leftMargin: 8
             rightMargin: 16
        }
        spacing: 8

        Rectangle {
            id: iconContainer
            width: Appearance.font.pixelSize.large * 2
            height: Appearance.font.pixelSize.large * 2
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHighest ?? Appearance.colors.colSurfaceVariant
            
            Layout.alignment: Qt.AlignVCenter

            MaterialSymbol {
                id: symbol
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 1
                fill: 0
                iconSize: Appearance.font.pixelSize.large
                color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
            }
        }

        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1 
            

            StyledText {
                id: title
                Layout.fillWidth: true
                font {
                    pixelSize: Appearance.font.pixelSize.smaller * 0.92
                    weight: Font.Normal
                }
                color: Appearance.colors.colOnSurfaceVariant
                elide: Text.ElideRight
            }

            StyledText {
                id: value
                Layout.fillWidth: true
                font {
                    pixelSize: Appearance.font.pixelSize.small * 0.92
                    weight: Font.Bold
                }
                color: root.warning ? Appearance.colors.colError : Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }

            Rectangle {
                id: barTrack
                visible: root.percentage >= 0
                Layout.fillWidth: true
                Layout.topMargin: 2
                implicitHeight: 3
                radius: height / 2
                color: Appearance.colors.colSurfaceContainerHighest

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.percentage))
                    height: parent.height
                    radius: parent.radius
                    color: root.warning ? Appearance.colors.colError : Appearance.colors.colPrimary

                    Behavior on width {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                }
            }
        }
    }
}
