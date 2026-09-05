pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var scale
    property bool restrictToWorkspace: true
    property real widthRatio: {
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale);
    }
    property real heightRatio: {
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale);
    }
    property real initX: {
        return Math.max((windowData?.at[0] - (monitorData?.x ?? 0) - monitorData?.reserved[0]) * widthRatio * root.scale, 0) + xOffset;
    }

    property real initY: {
        return Math.max((windowData?.at[1] - (monitorData?.y ?? 0) - monitorData?.reserved[1]) * heightRatio * root.scale, 0) + yOffset;
    }
    property real xOffset: 0
    property real yOffset: 0
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor.id

    property var targetWindowWidth: windowData?.size[0] * scale * widthRatio
    property var targetWindowHeight: windowData?.size[1] * scale * heightRatio
    property bool hovered: false
    property bool pressed: false

    property bool centerIcons: Config.options.overview.centerIcons
    property real iconGapRatio: 0.06
    property real iconToWindowRatio: centerIcons ? 0.35 : 0.15
    property real xwaylandIndicatorToIconRatio: 0.35
    property real iconToWindowRatioCompact: 0.6
    property string iconPath: Quickshell.iconPath(AppSearch.guessIcon(windowData?.class), "image-missing")
    property bool compactMode: Appearance.font.pixelSize.smaller * 4 > targetWindowHeight || Appearance.font.pixelSize.smaller * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false

    // Position in the repeater, used only to stagger this window's snapshot
    // capture away from its siblings' - see captureTimer.
    property int captureIndex: 0

    // Keeps capture sessions alive for a short while after the overview closes,
    // so a reopen finds them already running instead of paying setup cost in
    // its own animation frames. Deliberately NOT permanent: staying warm
    // forever would reintroduce exactly the always-on capture load this is
    // meant to avoid. The window is only ever closed-and-reopened quickly by a
    // user toggling Super; after that the sessions are torn down normally.
    property bool warm: false

    Timer {
        id: warmDownTimer
        interval: 5000
        onTriggered: root.warm = false
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                root.warm = true;
                warmDownTimer.stop();
            } else {
                warmDownTimer.restart();
            }
        }
    }

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: windowData.monitor == widgetMonitorId ? 1 : 0.4

    property real topLeftRadius
    property real topRightRadius
    property real bottomLeftRadius
    property real bottomRightRadius

    // Gated rather than unconditional, matching IslandOverlay/StyledPopup which
    // both only enable their layer when it's actually doing something. Each
    // enabled layer here costs two FBOs (the content, plus the mask Rectangle
    // rendered separately) and a shader pass to combine them, per window, per
    // frame - worth paying for rounded preview corners while the overview is on
    // screen, pure waste while it's closed and nothing is visible.
    layer.enabled: GlobalStates.overviewOpen || root.warm
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
        }
    }

    // These Behaviors exist for genuine geometry changes - a window being
    // dragged to another workspace, or the grid re-laying out. They must NOT
    // run on the first resolve of windowData.
    //
    // windowData arrives asynchronously from HyprlandData, so x/y/width/height
    // all start at 0 (or NaN) and then jump to their real values once it lands.
    // With an unguarded Behavior, that jump is not a data update - it's an
    // animation, and the Behavior dutifully plays it. Instrumenting one preview
    // showed it starting at x=572, width=0 and flying to x=1390, width=340 over
    // ~300ms, entirely independently of the overlay's own open animation. Four
    // windows each doing that, on a different curve to the container, is
    // precisely the "everything jumps around inconsistently" effect.
    //
    // `geometryReady` gates them: false until the first real geometry has been
    // applied (so it lands instantly, in place), true afterwards.
    property bool geometryReady: false
    readonly property bool hasGeometry: windowData !== undefined
        && !isNaN(root.targetWindowWidth) && root.targetWindowWidth > 0

    onHasGeometryChanged: if (hasGeometry && !geometryReady) Qt.callLater(() => root.geometryReady = true)

    Behavior on x {
        enabled: root.geometryReady
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        enabled: root.geometryReady
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        enabled: root.geometryReady
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        enabled: root.geometryReady
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        // Sessions are kept alive slightly past close (see root.warm) so a
        // quick reopen doesn't pay setup cost again.
        captureSource: (GlobalStates.overviewOpen || root.warm) ? root.toplevel : null

        // Snapshots, not video. `live: true` re-captured every window every
        // frame for as long as the overview was open - measured at 25% GPU on
        // integrated Vega with only four windows, which is what kept the open
        // animation from holding 60fps. A window's contents don't meaningfully
        // change during the second you're looking at the grid, so the frame is
        // taken once per open (see the captureFrame call below) instead.
        //
        // NOTE: constraintSize was tried here first, to keep previews live but
        // capture them at the ~0.18 scale they're actually drawn at rather than
        // full window resolution. It made no measurable difference (25% -> 26%
        // GPU, within noise), so it appears to constrain the output rather than
        // the capture itself in this Quickshell version. Removed rather than
        // left in place looking like it does something.
        live: false

        // One capture per open, staggered.
        //
        // Firing every window's captureFrame() together via Qt.callLater put
        // all of them in a single event-loop tick, and screencopy is
        // synchronous enough that this stalled the main thread outright:
        // instrumenting motionProgress showed a 418ms gap between two
        // consecutive animation frames (vs a steady 16-35ms otherwise), which
        // is precisely the visible "glitch". Spreading them over separate
        // ticks, each offset by index, keeps any single frame cheap.
        //
        // The delay also puts the captures *before* the animation gets going
        // rather than inside it - warm() has already attached captureSource by
        // then, so by the time the overlay is actually visible the images are
        // there.
        // The frame lands in one go, with no transition of its own: before it
        // arrives the preview paints nothing, after it the window's full
        // contents are simply there. Captured frame-by-frame at slowMo 20,
        // that showed up as isolated RMSE spikes of 3043 and 3190 against
        // neighbours of 500-900 - each one a preview popping into existence
        // part-way through the entry animation, on no curve at all. Staggering
        // the captures (below) is what keeps any single frame cheap, but it
        // also spreads those pops across the whole entry.
        //
        // Fading each preview in over its own short ramp turns the pop into a
        // transition. It is an effects property, so it gets the flat curve
        // (motion.md), and it is deliberately short - the point is to take the
        // hard edge off the arrival, not to add another slow motion competing
        // with the container's.
        Timer {
            id: captureTimer
            interval: 8 * (root.captureIndex + 1)
            repeat: false
            onTriggered: windowPreview.captureFrame()
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (GlobalStates.overviewOpen)
                    captureTimer.restart();
            }
        }

        Component.onCompleted: if (GlobalStates.overviewOpen) captureTimer.restart()

        // Color overlay for interactions
        Rectangle {
            anchors.fill: parent
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
            color: pressed ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.5) : 
                hovered ? ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.7) : 
                ColorUtils.transparentize(Appearance.colors.colLayer2)
            border.color : ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.88)
            border.width : 1
        }

        StyledImage {
            id: windowIcon
            property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
            anchors {
                top: root.centerIcons ? undefined : parent.top
                left: root.centerIcons ? undefined : parent.left
                centerIn: root.centerIcons ? parent : undefined
                margins: baseSize * root.iconGapRatio
            }
            property var iconSize: {
                // console.log("-=-=-", root.toplevel.title, "-=-=-")
                // console.log("Target window size:", targetWindowWidth, targetWindowHeight)
                // console.log("Icon ratio:", root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio)
                // console.log("Scale:", root.monitorData.scale)
                // console.log("Final:", Math.min(targetWindowWidth, targetWindowHeight) * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio) / root.monitorData.scale)
                return baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio);
            }
            mipmap: true
            Layout.alignment: Qt.AlignHCenter
            source: root.iconPath
            width: iconSize
            height: iconSize

            // Same first-resolve guard as the preview's own geometry above -
            // iconSize derives from targetWindowWidth, so it has the identical
            // "0 -> real value" jump when windowData lands.
            Behavior on width {
                enabled: root.geometryReady
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
            Behavior on height {
                enabled: root.geometryReady
                animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
            }
        }
    }
}
