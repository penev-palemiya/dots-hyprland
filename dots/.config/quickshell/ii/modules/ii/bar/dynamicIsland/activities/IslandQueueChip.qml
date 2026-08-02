import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var activity
    property string iconName: activity ? (activity.queueIcon || "") : ""
    property int badgeCount: activity ? (activity.queueBadgeCount || 0) : 0

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    scale: 0
    Component.onCompleted: scale = 1

    RippleButton {
        id: button

        implicitWidth: 26
        implicitHeight: 26
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        onClicked: root.clicked()

        anchors {
            left: parent.left
            bottom: parent.bottom
        }

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            fill: 1
            iconSize: Appearance.font.pixelSize.normal
            text: root.iconName
            color: Appearance.colors.colOnLayer2
        }

    }

    Rectangle {
        visible: root.badgeCount > 0
        z: 2
        implicitWidth: Math.max(14, badgeText.implicitWidth + 6)
        implicitHeight: 14
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        border.width: 1
        border.color: Appearance.colors.colLayer1

        anchors {
            top: parent.top
            right: parent.right
        }

        StyledText {
            id: badgeText

            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnPrimary
            text: root.badgeCount
        }

    }

    Behavior on scale {
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(root)
    }

}
