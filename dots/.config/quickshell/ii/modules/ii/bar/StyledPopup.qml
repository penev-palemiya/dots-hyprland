import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland

/**
 * Shared chrome for every bar popup: positioning against the bar edge,
 * outside-click dismissal, the shadow, the rounded surface — and the motion.
 *
 * The motion is a container transform, same as the dynamic island's overlay
 * (see IslandOverlay.qml and docs/design/motion.md):
 *
 * 1. The surface itself grows. `popupBackground` is a real Rectangle whose
 *    height animates from 0 — it is NOT a full-size rectangle revealed by a
 *    moving clip edge, which is what this
 *    used to do. Two things were wrong with the clip: the rounded corners on
 *    the growing edge only appeared at the very end (until then the popup had
 *    a hard straight edge), and a spatial spring's overshoot was invisible,
 *    because past 1.0 the clip was simply taller than the thing it revealed.
 *    Now the shape genuinely overshoots and settles, so it reads as something
 *    that physically opened.
 * 2. Enter and exit are asymmetric: `elementMove` (500ms, the bouncier
 *    "hero moment" curve) opening, `elementMoveSmall` (350ms) closing.
 * 3. Content trails the shape rather than racing it, and popups that opt into
 *    `staggerContent` reveal their sections one after another instead of as a
 *    single block — see `sectionOpacity`/`sectionOffset` below.
 *
 * Closing is animated too. The window stays mapped for the length of the exit
 * animation, but its input region collapses to nothing the instant `shown`
 * goes false, so it cannot eat the click that dismissed it — which is what
 * the previous "unmap immediately, no exit animation" approach was avoiding.
 */
LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0
    property bool shown: false

    readonly property bool useCompositorBlur: Config.options.appearance.transparency.compositorBlur

    // Opt-in staggered content reveal. When false (the default) the content
    // fades in as one block, which is all a small popup needs.
    property bool staggerContent: false
    // How many steps the cascade is divided into. Set it to the number of
    // sections actually used so the whole cascade always spans the same
    // window no matter how many there are — otherwise a popup with a lot of
    // sections runs past the end and the tail all lands at once.
    property int sectionCount: 6

    signal dismissRequested()

    property SurfaceLifecycle lifecycle: SurfaceLifecycle {
        id: lifecycle
        enterDuration: Appearance.animation.elementMove.duration
        exitDuration: Appearance.animation.elementMoveSmall.duration
        enterCurve: Appearance.animation.elementMove.bezierCurve
        exitCurve: Appearance.animation.elementMoveSmall.bezierCurve
    }

    active: root.lifecycle.mounted
    onShownChanged: root.lifecycle.setOpen(root.shown)
    Component.onCompleted: root.lifecycle.setOpen(root.shown)

    readonly property real revealPhase: {
        if (root.lifecycle.phase === SurfaceLifecycle.Phase.Closing)
            return Math.max(0, Math.min(1, (root.lifecycle.progress - 0.6) / 0.4));
        return Math.max(0, Math.min(1, (root.lifecycle.progress - 0.2) / 0.8));
    }

    // Each section gets its own slice of the reveal: the last one starts at
    // sectionMaxStart and every earlier one is spaced evenly before it, each
    // taking sectionSpan to complete. So later sections are still arriving
    // while earlier ones have settled, and the cascade always ends at the
    // same moment whether there are three sections or ten.
    readonly property real sectionMaxStart: 0.5
    readonly property real sectionSpan: 0.5

    function sectionProgress(index) {
        const steps = Math.max(1, root.sectionCount - 1);
        const start = Math.min(root.sectionMaxStart, (index / steps) * root.sectionMaxStart);
        return Math.max(0, Math.min(1, (root.revealPhase - start) / root.sectionSpan));
    }

    function sectionOpacity(index) {
        return root.sectionProgress(index);
    }

    // A short slide toward the bar edge the popup grew out of.
    function sectionOffset(index) {
        return (1 - root.sectionProgress(index)) * 8;
    }

    component: PanelWindow {
        id: popupWindow

        color: "transparent"

        anchors.left: true
        anchors.right: false
        anchors.top: !Config.options.bar.bottom
        anchors.bottom: Config.options.bar.bottom

        implicitWidth: popupSurface.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupSurface.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        // Input region. While open it's just the visible surface, so the
        // elevation margin around the popup stays click-through; while closing
        // it collapses to nothing so the window can remain mapped for the exit
        // animation without swallowing clicks meant for whatever is underneath.
        Region {
            id: openMask

            item: popupSurface
        }

        Region {
            id: closedMask

            width: 0
            height: 0
        }

        visible: root.lifecycle.surfaceVisible
        mask: root.lifecycle.acceptsInput ? openMask : closedMask

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!root.QsWindow || !root.hoverTarget)
                    return 0;
                return root.QsWindow.mapFromItem(root.hoverTarget, (root.hoverTarget.width - popupSurface.implicitWidth) / 2, 0).x;
            }
            top: Appearance.sizes.barHeight
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        Component.onCompleted: {
            if (root.lifecycle.acceptsInput)
                GlobalFocusGrab.addDismissable(popupWindow);
        }

        Component.onDestruction: GlobalFocusGrab.removeDismissable(popupWindow)

        Connections {
            target: root.lifecycle

            function onOpeningStarted() {
                Qt.callLater(() => {
                    if (root.lifecycle.acceptsInput)
                        GlobalFocusGrab.addDismissable(popupWindow);
                });
            }

            function onClosingStarted() {
                GlobalFocusGrab.removeDismissable(popupWindow);
            }

            function onFullyClosed() {
                GlobalFocusGrab.removeDismissable(popupWindow);
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
            // 0 = collapsed against the bar edge, 1 = fully open. Overshoots
            // past 1 on the way in — the shape is real, so that reads as a
            // settle rather than being clipped away.
            property real motionProgress: root.lifecycle.progress

            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2

            StyledRectangularShadow {
                target: popupBackground
                opacity: popupSurface.motionProgress
                visible: opacity > 0
            }

            Rectangle {
                id: popupBackground

                // The growing edge is the one away from the bar, so the popup
                // unfolds out of it instead of sliding as a whole.
                width: popupSurface.implicitWidth
                height: popupSurface.implicitHeight * popupSurface.motionProgress

                anchors.top: popupWindow.anchors.top ? parent.top : undefined
                anchors.bottom: popupWindow.anchors.bottom ? parent.bottom : undefined

                // In transparent mode the masked backdrop below is the one
                // surface. Keeping a second opaque Rectangle underneath it
                // makes two anti-aliased radii blend at the edge.
                color: !Config.options.appearance.transparency.enable
                    ? Appearance.m3colors.m3surfaceContainer
                    : (root.useCompositorBlur ? Appearance.colors.colGlassTint : "transparent")
                radius: Appearance.rounding.small
                // The content is full-size from the start; the surface growing
                // over it is what reveals it. Rounded corners stay correct
                // throughout because this is the real shape, not a clip mask.
                clip: true
                layer.enabled: Config.options.appearance.transparency.enable
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: popupBackground.width
                        height: popupBackground.height
                        radius: Math.min(popupBackground.radius, width / 2, height / 2)
                    }
                }

                // Match the wallpaper itself instead of making the layer
                // surface truly transparent: a popup must not reveal an app
                // that happens to be underneath it. Shared with the dynamic
                // island through WallpaperBackdrop so every translucent
                // surface in the shell draws the same material — this used to
                // be a private ShaderEffectSource copy that could drift from
                // the island's own version of the same idea.
                Loader {
                    anchors.fill: parent
                    active: Config.options.appearance.transparency.enable && !root.useCompositorBlur
                    asynchronous: true

                    // Keep final dimensions while popupBackground grows; its
                    // clip reveals this fixed crop without rescaling it.
                    sourceComponent: WallpaperBackdrop {
                        width: popupSurface.implicitWidth
                        height: popupSurface.implicitHeight
                        anchors.top: popupWindow.anchors.top ? parent.top : undefined
                        anchors.bottom: popupWindow.anchors.bottom ? parent.bottom : undefined

                        screen: popupWindow.screen
                        screenX: popupWindow.margins.left + Appearance.sizes.elevationMargin
                        screenY: popupWindow.anchors.top ? popupWindow.margins.top + Appearance.sizes.elevationMargin : popupWindow.screen.height - popupWindow.margins.bottom - Appearance.sizes.elevationMargin - popupSurface.implicitHeight
                    }
                }

                Item {
                    id: contentHost

                    width: popupSurface.implicitWidth - popupSurface.margin * 2
                    height: popupSurface.implicitHeight - popupSurface.margin * 2

                    // Pinned to whichever edge the surface grows out of, so the
                    // content doesn't drift while the shape expands.
                    anchors.top: popupWindow.anchors.top ? parent.top : undefined
                    anchors.bottom: popupWindow.anchors.bottom ? parent.bottom : undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.margins: popupSurface.margin

                    children: [root.contentItem]
                    // Popups that stagger drive their own sections' opacity.
                    opacity: root.staggerContent ? 1 : root.revealPhase
                }
            }
        }
    }
}
