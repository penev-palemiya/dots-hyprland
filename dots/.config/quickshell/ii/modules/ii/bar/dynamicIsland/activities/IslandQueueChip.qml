import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property var activity
    property string iconName: activity ? (activity.queueIcon || "") : ""
    property int badgeCount: activity ? (activity.queueBadgeCount || 0) : 0
    property bool shown: true

    signal clicked()

    implicitWidth: shown ? 30 : 0
    implicitHeight: 30
    visible: shown || implicitWidth > 0.5
    scale: shown ? 1 : 0
    opacity: shown ? 1 : 0

    RippleButton {
        id: button

        implicitWidth: 26
        implicitHeight: 26
        enabled: root.shown
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
        visible: root.shown && root.badgeCount > 0
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

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

    }

}
