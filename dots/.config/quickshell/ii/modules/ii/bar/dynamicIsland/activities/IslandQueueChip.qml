import qs.modules.common
import qs.modules.common.widgets
import QtQuick

RippleButton {
    id: root

    property var activity
    property string iconName: activity ? (activity.queueIcon || "") : ""
    property int badgeCount: activity ? (activity.queueBadgeCount || 0) : 0

    implicitWidth: 26
    implicitHeight: 26
    buttonRadius: Appearance.rounding.full
    colBackground: Appearance.colors.colLayer2
    colBackgroundHover: Appearance.colors.colLayer2Hover

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        fill: 1
        iconSize: Appearance.font.pixelSize.normal
        text: root.iconName
        color: Appearance.colors.colOnLayer2
    }

    Rectangle {
        visible: root.badgeCount > 0
        anchors {
            top: parent.top
            right: parent.right
            topMargin: -4
            rightMargin: -4
        }
        implicitWidth: Math.max(14, badgeText.implicitWidth + 6)
        implicitHeight: 14
        radius: Appearance.rounding.full
        color: Appearance.colors.colPrimary
        border.width: 1
        border.color: Appearance.colors.colLayer1

        StyledText {
            id: badgeText
            anchors.centerIn: parent
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colOnPrimary
            text: root.badgeCount
        }
    }

    scale: 0
    Behavior on scale {
        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(root)
    }
    Component.onCompleted: scale = 1
}
