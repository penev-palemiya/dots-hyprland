import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh
    
    Layout.fillWidth: true
    implicitWidth: mainRow.implicitWidth + 32
    implicitHeight: mainRow.implicitHeight + 10

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text

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
                color: Appearance.colors.colOnSurface
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
                color: Appearance.colors.colOutline
                elide: Text.ElideRight
            }

            StyledText {
                id: value
                Layout.fillWidth: true
                font {
                    pixelSize: Appearance.font.pixelSize.small * 0.92
                    weight: Font.Bold
                }
                color: Appearance.colors.colOnSurface 
                elide: Text.ElideRight
            }
        }
    }
}
