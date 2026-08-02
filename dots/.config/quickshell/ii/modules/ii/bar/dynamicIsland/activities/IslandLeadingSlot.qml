import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property string leadingKind: "icon"
    property string leadingIcon: ""
    property color leadingIconColor: Appearance.m3colors.m3onSecondaryContainer
    property string leadingImage: ""
    property int notificationId: -1
    property string appIcon: ""
    readonly property string visualKey: `${leadingKind}:${leadingIcon}:${leadingImage}:${appIcon}`
    property bool initialized: false

    implicitWidth: 26
    implicitHeight: 26
    radius: Appearance.rounding.full
    color: Appearance.colors.colSecondaryContainer
    clip: true
    Component.onCompleted: initialized = true
    onVisualKeyChanged: {
        if (initialized)
            swapAnimation.restart();

    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: root.leadingKind !== "avatar"
        fill: 1
        iconSize: Appearance.font.pixelSize.normal
        color: root.leadingIconColor
        text: root.leadingIcon

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

    }

    Item {
        anchors.fill: parent
        visible: root.leadingKind === "avatar"

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            clip: true

            Image {
                id: avatarImage

                anchors.fill: parent
                visible: root.leadingImage.length > 0 && status !== Image.Error
                source: root.leadingImage
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                antialiasing: true
                layer.enabled: visible
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: avatarImage.width
                        height: avatarImage.height
                        radius: width / 2
                    }
                }
                onStatusChanged: {
                    if (status === Image.Ready && root.notificationId >= 0)
                        Notifications.cacheNotificationImage(root.notificationId, avatarImage);

                }
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: root.leadingImage.length === 0 || avatarImage.status === Image.Error
                fill: 1
                text: root.leadingIcon || "person"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.m3colors.m3onSecondaryContainer
            }

        }

        Rectangle {
            width: 12
            height: 12
            radius: width / 2
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colLayer1
            clip: true
            visible: root.appIcon.length > 0

            anchors {
                right: parent.right
                bottom: parent.bottom
            }

            IconImage {
                anchors.fill: parent
                anchors.margins: 1
                source: Quickshell.iconPath(root.appIcon, "image-missing")
            }

        }

    }

    SequentialAnimation {
        id: swapAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0.4
                duration: Appearance.animation.elementMoveFast.duration / 2
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "scale"
                to: 0.86
                duration: Appearance.animation.elementMoveFast.duration / 2
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }

        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 1
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }

            NumberAnimation {
                target: root
                property: "scale"
                to: 1
                duration: Appearance.animation.elementMoveSmall.duration
                easing.type: Appearance.animation.elementMoveSmall.type
                easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
            }

        }

    }

}
