import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Sidebar entry: icon plus a title and a subtitle hinting at what's inside,
 * so the nav reads as a table of contents rather than a row of bare labels.
 */
Item {
    id: root

    property string icon: ""
    property real iconRotation: 0
    property string title: ""
    property string subtitle: ""
    property bool selected: false

    signal clicked()

    Layout.fillWidth: true
    implicitHeight: Math.max(60, contentRow.implicitHeight + 14 * 2)

    Rectangle {
        id: background
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: root.selected ? Appearance.colors.colSecondaryContainer : "transparent"

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Rectangle { // Hover/press state layer
            anchors.fill: parent
            radius: parent.radius
            color: Appearance.colors.colOnSurface
            visible: !root.selected
            opacity: mouseArea.containsMouse ? (mouseArea.pressed ? 0.1 : 0.06) : 0

            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    RowLayout {
        id: contentRow
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 16
            rightMargin: 14
        }
        spacing: 14

        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            text: root.icon
            rotation: root.iconRotation
            iconSize: Appearance.font.pixelSize.huge
            fill: root.selected ? 1 : 0
            color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: root.selected ? Font.DemiBold : Font.Medium
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colSubtext
                opacity: root.selected ? 0.9 : 1
                elide: Text.ElideRight
            }
        }
    }
}
