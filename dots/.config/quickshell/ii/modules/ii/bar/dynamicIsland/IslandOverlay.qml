import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

/**
 * The dynamic island's click-to-reveal detail panel — a separate floating
 * window (Wayland/layer-shell has no way to let one surface draw outside
 * its own bounds, so growing past the bar's fixed height genuinely needs a
 * second surface), positioned using plain margins computed from
 * `pillBackground`'s real screen rect by `DynamicIsland.qml` itself and
 * passed in as ordinary properties — deliberately NOT Quickshell's
 * `QsWindow`/`mapFromItem` cross-window attached-property mechanism, which
 * repeatedly proved unreliable here (resolves via an unrelated QObject
 * parent chain, and refuses to run at all on a window too small to count
 * as "a member of a window" — see DynamicIsland.qml's comment for the full
 * story). The PanelWindow and expanded content stay mounted even while hidden,
 * so a quick re-open reverses the existing animation instead of tearing down
 * and recreating the expanded view or resizing the layer-shell surface.
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

    property real anchorLeftMargin: 0
    property real anchorTopMargin: 0
    property real anchorRightMargin: 0
    property real anchorBottomMargin: 0
    property real anchorWidth: 0
    // The screen the pill this panel belongs to actually lives on. Without
    // it the PanelWindow lands on whatever Quickshell picks as default,
    // which only coincidentally matches while exactly one monitor exists —
    // add a second (or a transient virtual/headless one) and the panel can
    // open on the wrong output, or on one that then goes away, while every
    // margin below is still computed in the *bar's* screen coordinates.
    property var targetScreen: null
    property real screenWidth: 0
    property real screenHeight: 0
    property color surfaceColor: "transparent"
    property bool shown: false
    property Component sourceComponent
    property real visibleHeight: 0
    signal dismissRequested()

    active: true

    component: PanelWindow {
        id: overlayWindow
        color: "transparent"

        screen: root.targetScreen

        anchors.left: true
        anchors.right: false
        anchors.top: !Config.options.bar.bottom
        anchors.bottom: Config.options.bar.bottom

        // No elevation margin, no shadow: this panel isn't a floating card
        // in its own right, it's the pill's own shape continuing downward —
        // any gap or shadow around it would read as a seam between two
        // separate things instead of one. Window bounds match the visible
        // rectangle exactly, flush against the pill above with zero gap.
        //
        // Deliberately NOT bound to overlayBackground's own (Behavior-
        // animated) height: that made every single animation frame trigger
        // a real Wayland layer-shell surface reconfigure (an expensive
        // compositor round-trip), which is what made the reveal run at
        // ~10fps. The window jumps directly to its final target size (a
        // one-time resize, whichever direction `shown` just changed to);
        // the Rectangle inside still animates smoothly *within* that
        // already-correctly-sized window — pure client-side rendering, no
        // further surface reconfiguration involved. Keep this at the expanded
        // size even while hidden so rapid close/open never tears down the
        // layer-shell surface or expanded content mid-animation.
        implicitWidth: root.anchorWidth
        implicitHeight: contentLoader.implicitHeight + overlayBackground.contentPadding * 2

        mask: Region {
            item: overlayBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: root.anchorLeftMargin
            top: root.anchorTopMargin
            right: root.anchorRightMargin
            bottom: root.anchorBottomMargin
        }
        WlrLayershell.namespace: "quickshell:island-overlay"
        WlrLayershell.layer: WlrLayer.Overlay

        Component.onCompleted: {
            if (root.shown)
                GlobalFocusGrab.addDismissable(overlayWindow);
        }
        Component.onDestruction: {
            GlobalFocusGrab.removeDismissable(overlayWindow);
        }
        Connections {
            target: root
            function onShownChanged() {
                if (root.shown)
                    GlobalFocusGrab.addDismissable(overlayWindow);
                else
                    GlobalFocusGrab.removeDismissable(overlayWindow);
            }
        }
        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                if (root.shown)
                    root.dismissRequested();
            }
        }

        Rectangle {
            id: overlayBackground
            readonly property real contentPadding: 12
            // Top-anchored with an explicit `height` (not `anchors.fill`) so
            // this can animate independently of the window's own (now
            // fixed-per-toggle) size — see the window's implicitHeight
            // comment above for why that decoupling matters for performance.
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: root.shown ? contentLoader.implicitHeight + contentPadding * 2 : 0
            onHeightChanged: root.visibleHeight = height
            // Flattened in DynamicIsland from "pill over bar background" into
            // the single color this separate surface must paint to match the
            // inline pill visually.
            color: Config.options.appearance.transparency.enable ? "transparent" : root.surfaceColor
            // Flat against the pill above (see class comment) — only the
            // bottom corners round, matching the pill's own shape while merged.
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Appearance.rounding.small
            bottomRightRadius: Appearance.rounding.small
            clip: true
            // `clip` only clips children to this Rectangle's bounding box,
            // not to its rounded shape — the wallpaper Image below is a
            // plain rectangle, so without this mask it paints square right
            // over the rounded bottom corners, and (since it's then the only
            // one of the two surfaces rendering through a layered texture)
            // reads as a visibly different material from the pill above.
            // Same fix pillBackground already uses, mirrored here so both
            // surfaces go through the same OpacityMask pipeline.
            // Guarded on a non-zero height: this window stays mounted even
            // while closed, so without the guard the layer would be created
            // at height 0 and never come back to life once the panel grows.
            layer.enabled: Config.options.appearance.transparency.enable && overlayBackground.height > 0
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: overlayBackground.width
                    height: overlayBackground.height
                    topLeftRadius: overlayBackground.topLeftRadius
                    topRightRadius: overlayBackground.topRightRadius
                    bottomLeftRadius: overlayBackground.bottomLeftRadius
                    bottomRightRadius: overlayBackground.bottomRightRadius
                }
            }

            // Height is a spatial property (MD3 Expressive: size/position use
            // a bouncy spatial spring, not the flat "effects" curve used for
            // opacity/color) — asymmetric on purpose: expanding is the slower,
            // bouncier "default spatial" (500ms, this is the hero moment),
            // collapsing is the snappier "fast spatial" (350ms, exits need
            // less attention than the next thing the user's about to do).
            // A Behavior's `animation` can only be assigned once — swapping
            // in a whole new Animation object per direction (as this used to
            // do via `.createObject(...)` in a ternary) triggers "Cannot
            // change the animation assigned to a Behavior" and silently
            // keeps whichever one was assigned first. Keep one static
            // NumberAnimation and vary its own duration/curve instead.
            Behavior on height {
                NumberAnimation {
                    duration: root.shown ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration
                    easing.type: Appearance.animation.elementMove.type
                    easing.bezierCurve: root.shown ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
                }
            }

            Loader {
                // Pinned to the panel's FINAL height rather than its animating
                // one: this backdrop crops the wallpaper via sourceClipRect,
                // and a rect that changed every animation frame would re-decode
                // the image every frame. The panel's own clip does the reveal.
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: contentLoader.implicitHeight + overlayBackground.contentPadding * 2
                active: Config.options.appearance.transparency.enable
                asynchronous: true

                sourceComponent: WallpaperBackdrop {
                    screen: root.targetScreen
                    screenX: root.anchorLeftMargin
                    screenY: root.anchorTopMargin
                }
            }

            Loader {
                id: contentLoader
                anchors.fill: parent
                anchors.margins: overlayBackground.contentPadding
                opacity: root.shown ? 1 : 0
                sourceComponent: root.sourceComponent

                // Opacity is an effects property — no overshoot. Container-
                // transform choreography: the shape grows first, content
                // fades in slightly after (small delay) so it doesn't just
                // pop while the pill is still small; on the way out, content
                // fades away immediately (no delay) so the shrink isn't
                // waiting on it. Same "assign once" constraint as above —
                // one static SequentialAnimation, only the PauseAnimation's
                // duration varies.
                Behavior on opacity {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.shown ? 120 : 0
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
}
