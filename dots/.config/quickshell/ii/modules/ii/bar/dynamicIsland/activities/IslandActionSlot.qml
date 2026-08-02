import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string iconName: ""
    property var action
    readonly property bool active: iconName.length > 0 && !!action

    implicitWidth: active ? 22 : 0
    implicitHeight: 22
    visible: active || implicitWidth > 0.5
    clip: false

    RippleButton {
        id: button

        implicitWidth: implicitHeight
        implicitHeight: 22
        opacity: root.active ? 1 : 0
        scale: root.active ? 1 : 0
        buttonRadius: Appearance.rounding.full
        colBackground: Appearance.colors.colSecondaryContainer
        colBackgroundHover: Appearance.colors.colSecondaryContainerHover
        onClicked: {
            if (root.action)
                root.action();

        }

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            fill: 0
            iconSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSecondaryContainer
            text: root.iconName
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

        }

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
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

}
