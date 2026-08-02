import QtQuick
import qs.modules.common

Item {
    id: root

    property bool active: false
    property real value: 0
    property color fillColor: Appearance.colors.colOnSecondaryContainer
    property color trackColor: Appearance.colors.colSecondaryContainer
    readonly property real clampedValue: Math.max(0, Math.min(1, value))

    implicitWidth: active ? 46 : 0
    implicitHeight: 22
    width: implicitWidth
    height: implicitHeight
    visible: active || implicitWidth > 0.5
    opacity: active ? 1 : 0
    clip: false

    Rectangle {
        id: track

        width: 42
        height: 5
        radius: height / 2
        color: root.trackColor

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: Math.max(parent.height, parent.width * root.clampedValue)
            height: parent.height
            radius: parent.radius
            color: root.fillColor

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }

            }

        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }

    }

}
