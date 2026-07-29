import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * The dynamic island's click-to-reveal detail panel — a separate floating
 * window (Wayland/layer-shell has no way to let one surface draw outside
 * its own bounds, so growing past the bar's fixed height genuinely needs a
 * second surface), positioned using plain numbers (`anchorScreenX`/
 * `anchorScreenY`/`anchorWidth`) computed by `DynamicIsland.qml` itself and
 * passed in as ordinary properties — deliberately NOT Quickshell's
 * `QsWindow`/`mapFromItem` cross-window attached-property mechanism, which
 * repeatedly proved unreliable here (resolves via an unrelated QObject
 * parent chain, and refuses to run at all on a window too small to count
 * as "a member of a window" — see DynamicIsland.qml's comment for the full
 * story). Mounted immediately (not lazily on `shown`), so the window itself
 * never "appears" — only the visible panel's height animates.
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

    property real anchorScreenX: 0
    property real anchorScreenY: 0
    property real anchorWidth: 0
    property bool shown: false
    property Component sourceComponent

    active: true

    component: PanelWindow {
        id: overlayWindow
        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

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
        // further surface reconfiguration involved.
        implicitWidth: root.anchorWidth
        implicitHeight: root.shown ? contentLoader.implicitHeight + overlayBackground.contentPadding * 2 : 0

        mask: Region {
            item: overlayBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: !Config.options.bar.vertical ? root.anchorScreenX : Appearance.sizes.verticalBarWidth
            top: !Config.options.bar.vertical ? Appearance.sizes.barHeight : root.anchorScreenY
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:island-overlay"
        WlrLayershell.layer: WlrLayer.Overlay

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
            // A real standalone surface color, not `colLayer1` (which is a
            // "solved overlay" blend pre-baked assuming it's painted over
            // the bar's own background — correct in the bar, but looks
            // washed out/semi-transparent floating over the wallpaper with
            // nothing behind it). `m3surfaceContainer` is the token
            // StyledPopup.qml already uses for exactly this situation.
            color: Config.options?.bar.borderless ? "transparent" : Appearance.m3colors.m3surfaceContainer
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
