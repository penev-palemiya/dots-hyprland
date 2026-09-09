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
    property real widthRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;
        const widgetWidth = widgetMonitor.transform & 1 ? widgetMonitor.height : widgetMonitor.width;
        const monitorWidth = monitorData.transform & 1 ? monitorData.height : monitorData.width;
        return (widgetWidth * monitorData.scale) / (monitorWidth * widgetMonitor.scale);
    }
    property real heightRatio: {
        if (!widgetMonitor || !monitorData)
            return 1;
        const widgetHeight = widgetMonitor.transform & 1 ? widgetMonitor.width : widgetMonitor.height;
        const monitorHeight = monitorData.transform & 1 ? monitorData.width : monitorData.height;
        return (widgetHeight * monitorData.scale) / (monitorHeight * widgetMonitor.scale);
    }
    property real initX: {
        return Math.max(((windowData?.at?.[0] ?? 0) - (monitorData?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * widthRatio * root.scale, 0) + xOffset;
    }

    property real initY: {
        return Math.max(((windowData?.at?.[1] ?? 0) - (monitorData?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * heightRatio * root.scale, 0) + yOffset;
    }
    property real xOffset: 0
    property real yOffset: 0
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor?.id ?? -1

    property real targetWindowWidth: (windowData?.size?.[0] ?? 0) * scale * widthRatio
    property real targetWindowHeight: (windowData?.size?.[1] ?? 0) * scale * heightRatio
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
    required property bool captureActive

    function capturePreview() {
        if (root.captureActive && root.toplevel)
            windowPreview.captureFrame();
    }

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: windowData?.monitor == widgetMonitorId ? 1 : 0.4

    property real topLeftRadius
    property real topRightRadius
    property real bottomLeftRadius
    property real bottomRightRadius

    // Each delegate needs this layer for the rounded preview mask. The parent
    // Loader destroys every delegate after the exit animation, releasing its
    // FBOs and shader resources while the overview is closed.
    layer.enabled: true
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
        captureSource: root.captureActive ? root.toplevel : null

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
