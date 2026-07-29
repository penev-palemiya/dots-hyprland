import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * The dynamic island's click-to-reveal detail panel. Sized to match
 * `anchorTarget`'s (the bar-drawn pill's) width exactly and mounted as soon
 * as there's something to anchor to (not lazily on `shown`), so the window
 * itself never "appears" — only the visible panel's height animates between
 * 0 (nothing shown) and its content's natural size.
 *
 * Its top corners are always flat, fusing against the pill's bottom corners
 * (which flatten to match while `shown`, see DynamicIsland.qml's
 * `mergedWithOverlay`) — that fusion, plus the pill and this panel sharing
 * one color and never both being independently rounded at the seam, is what
 * makes this read as the *same shape* growing taller rather than a second
 * card popping out below it. See docs/design/motion.md#container-transform.
 */
LazyLoader {
    id: root

    property Item anchorTarget
    property bool shown: false
    property Component sourceComponent

    active: !!root.anchorTarget

    // This window mounts immediately (active is true as soon as anchorTarget
    // exists, well before `shown` ever flips), so its `margins` bindings
    // below evaluate `mapFromItem` at that early moment too — and since
    // `mapFromItem` is a function call, not a property, the binding doesn't
    // re-run just because the anchor's actual on-screen position settles a
    // moment later. Cache the mapped position explicitly and refresh it on
    // a cheap repeating timer instead of relying on that one early read
    // staying correct forever (it doesn't — this is what made the overlay
    // open from the screen's left edge instead of under the pill).
    property real anchorX: 0
    property real anchorY: 0

    function refreshAnchorPosition() {
        if (!root.anchorTarget || !root.QsWindow)
            return;
        const mapped = root.QsWindow.mapFromItem(root.anchorTarget, 0, 0);
        root.anchorX = mapped.x;
        root.anchorY = mapped.y;
    }

    Component.onCompleted: root.refreshAnchorPosition()
    onAnchorTargetChanged: root.refreshAnchorPosition()

    Timer {
        interval: 200
        running: root.active
        repeat: true
        onTriggered: root.refreshAnchorPosition()
    }

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
            left: !Config.options.bar.vertical ? root.anchorX : Appearance.sizes.verticalBarWidth
            top: !Config.options.bar.vertical ? Appearance.sizes.barHeight : root.anchorY
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
            implicitHeight: root.shown ? contentLoader.implicitHeight + contentPadding * 2 : 0
            color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
            // Flat against the pill above (see class comment) — only the
            // bottom corners round, matching the pill's own shape while merged.
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Appearance.rounding.small
            bottomRightRadius: Appearance.rounding.small
            clip: true

            // Height is a spatial property (MD3 Expressive: size/position use
            // a bouncy spatial spring, not the flat "effects" curve used for
            // opacity/color) — asymmetric on purpose: expanding is the slower,
            // bouncier "default spatial" (500ms, this is the hero moment),
            // collapsing is the snappier "fast spatial" (350ms, exits need
            // less attention than the next thing the user's about to do).
            Behavior on implicitHeight {
                animation: root.shown ? Appearance.animation.elementMove.numberAnimation.createObject(overlayBackground) : Appearance.animation.elementMoveSmall.numberAnimation.createObject(overlayBackground)
            }

            Loader {
                id: contentLoader
                anchors.fill: parent
                anchors.margins: overlayBackground.contentPadding
                opacity: root.shown ? 1 : 0
                sourceComponent: root.shown ? root.sourceComponent : null

                // Opacity is an effects property — no overshoot. Container-
                // transform choreography: the shape grows first, content
                // fades in slightly after (small delay) so it doesn't just
                // pop while the pill is still small; on the way out, content
                // fades away immediately (no delay) so the shrink isn't
                // waiting on it.
                Behavior on opacity {
                    animation: root.shown ? fadeInComponent.createObject(contentLoader) : Appearance.animation.elementMoveFast.numberAnimation.createObject(contentLoader)
                }
            }

            Component {
                id: fadeInComponent
                SequentialAnimation {
                    PauseAnimation {
                        duration: 120
                    }
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }
            }
        }
    }
}
