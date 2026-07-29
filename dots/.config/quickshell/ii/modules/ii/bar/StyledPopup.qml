import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property bool shown: false
    readonly property int popupEnterDuration: Appearance.animation.elementMoveSmall.duration
    readonly property int contentEnterDelay: 90

    signal dismissRequested()

    // Layer-shell windows keep an input region even when visually transparent.
    // Keep the popup mounted only while open; close must unmap immediately.
    active: root.shown

    component: PanelWindow {
        id: popupWindow

        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupSurface.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupSurface.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    if (!root.QsWindow || !root.hoverTarget)
                        return 0;
                    return root.QsWindow.mapFromItem(
                        root.hoverTarget,
                        (root.hoverTarget.width - popupSurface.implicitWidth) / 2, 0
                    ).x;
                }
                return Appearance.sizes.verticalBarWidth;
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                if (!root.QsWindow || !root.hoverTarget)
                    return 0;
                return root.QsWindow.mapFromItem(
                    root.hoverTarget,
                    (root.hoverTarget.height - popupSurface.implicitHeight) / 2, 0
                ).y;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        Component.onCompleted: {
            if (root.shown)
                GlobalFocusGrab.addDismissable(popupWindow);
        }

        Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)

        Connections {
            target: root

            function onShownChanged() {
                if (root.shown)
                    GlobalFocusGrab.addDismissable(popupWindow);
            }
        }

        Connections {
            target: GlobalFocusGrab

            function onDismissed() {
                if (root.shown)
                    root.dismissRequested();
            }
        }

        Item {
            id: popupSurface

            readonly property real margin: 10
            property bool mounted: false
            readonly property real closedOffset: 8
            property real motionProgress: root.shown && mounted ? 1 : 0
            property real contentOpacity: root.shown && mounted ? 1 : 0
            readonly property real shiftX: {
                if (!Config.options.bar.vertical)
                    return 0;
                return (popupWindow.anchors.left ? -closedOffset : closedOffset) * (1 - motionProgress);
            }
            readonly property real shiftY: {
                if (Config.options.bar.vertical)
                    return 0;
                return (popupWindow.anchors.top ? -closedOffset : closedOffset) * (1 - motionProgress);
            }

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2

            transform: Translate {
                x: popupSurface.shiftX
                y: popupSurface.shiftY
            }

            Component.onCompleted: mounted = true

            Behavior on motionProgress {
                NumberAnimation {
                    duration: root.popupEnterDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }
            }

            Behavior on contentOpacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: root.shown ? root.contentEnterDelay : 0
                    }
                    NumberAnimation {
                        duration: 130
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                    }
                }
            }

            StyledRectangularShadow {
                target: popupBackground
                opacity: Math.max(0, (popupSurface.motionProgress - 0.7) / 0.3)
                visible: opacity > 0
            }

            Item {
                id: revealClip

                property real radius: Appearance.rounding.small
                clip: true
                width: Config.options.bar.vertical ? popupSurface.implicitWidth * popupSurface.motionProgress : popupSurface.implicitWidth
                height: Config.options.bar.vertical ? popupSurface.implicitHeight : popupSurface.implicitHeight * popupSurface.motionProgress
                anchors.left: Config.options.bar.vertical && popupWindow.anchors.left ? parent.left : undefined
                anchors.right: Config.options.bar.vertical && popupWindow.anchors.right ? parent.right : undefined
                anchors.top: !Config.options.bar.vertical && popupWindow.anchors.top ? parent.top : undefined
                anchors.bottom: !Config.options.bar.vertical && popupWindow.anchors.bottom ? parent.bottom : undefined

                Rectangle {
                    id: popupBackground

                    width: popupSurface.implicitWidth
                    height: popupSurface.implicitHeight
                    anchors.left: Config.options.bar.vertical && popupWindow.anchors.left ? parent.left : undefined
                    anchors.right: Config.options.bar.vertical && popupWindow.anchors.right ? parent.right : undefined
                    anchors.top: !Config.options.bar.vertical && popupWindow.anchors.top ? parent.top : undefined
                    anchors.bottom: !Config.options.bar.vertical && popupWindow.anchors.bottom ? parent.bottom : undefined
                    color: Appearance.m3colors.m3surfaceContainer
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: Appearance.colors.colLayer0Border
                }

                Item {
                    id: contentHost

                    x: popupBackground.x + popupSurface.margin
                    y: popupBackground.y + popupSurface.margin
                    width: popupSurface.implicitWidth - popupSurface.margin * 2
                    height: popupSurface.implicitHeight - popupSurface.margin * 2
                    children: [root.contentItem]
                    opacity: popupSurface.contentOpacity
                }
            }
        }
    }
}
