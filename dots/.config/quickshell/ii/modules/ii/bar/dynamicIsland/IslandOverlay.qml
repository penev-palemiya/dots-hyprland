import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

/**
 * Like StyledPopup, but activated by an explicit boolean instead of a hover
 * check, and sized to match `anchorTarget`'s width exactly so it reads as
 * the same shape growing taller out of `anchorTarget`, not a separate popup.
 */
LazyLoader {
    id: root

    property Item anchorTarget
    property bool shown: false
    property Component sourceComponent

    active: root.shown && !!root.anchorTarget

    component: PanelWindow {
        id: overlayWindow
        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: overlayBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
        implicitHeight: overlayBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

        mask: Region {
            item: overlayBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!Config.options.bar.vertical)
                    return root.QsWindow?.mapFromItem(root.anchorTarget, 0, 0).x;
                return Appearance.sizes.verticalBarWidth;
            }
            top: {
                if (!Config.options.bar.vertical)
                    return Appearance.sizes.barHeight;
                return root.QsWindow?.mapFromItem(root.anchorTarget, 0, 0).y;
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:island-overlay"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: overlayBackground
        }

        Rectangle {
            id: overlayBackground
            readonly property real contentPadding: 12
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin
                rightMargin: Appearance.sizes.elevationMargin
                topMargin: Appearance.sizes.elevationMargin * (!overlayWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin * (!overlayWindow.anchors.bottom)
            }
            implicitWidth: root.anchorTarget ? root.anchorTarget.width : 0
            implicitHeight: contentLoader.implicitHeight + contentPadding * 2
            color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
            radius: Appearance.rounding.small

            Loader {
                id: contentLoader
                anchors.fill: parent
                anchors.margins: overlayBackground.contentPadding
                sourceComponent: root.sourceComponent
            }
        }
    }
}
