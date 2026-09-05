import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick

/**
 * The frosted "glass" material: the wallpaper as it appears at this surface's
 * own place on screen, plus the shared tint over it.
 *
 * This is the ONE definition of that material. Every translucent surface that
 * is not the desktop itself — bar popups, the dynamic island's pill and its
 * expanded panel — must use this rather than rolling its own, because those
 * surfaces are separate Wayland windows: the only way their colour can be
 * guaranteed to match where they meet is for the crop and the tint to come
 * from a single piece of code. When they did not, the island's pill and its
 * panel drew visibly different greys along the seam between them.
 *
 * Give it the screen it lives on and its own top-left in that screen's
 * coordinates. Where the wallpaper actually sits — zoomed and panned by the
 * workspace parallax — comes from WallpaperGeometry, the same service the
 * desktop itself uses, so the glass keeps showing exactly the piece of picture
 * that is behind it instead of drifting away on every workspace switch.
 *
 * `screen` must be a real ShellScreen. Resolving one via `QsWindow.window
 * .screen` from inside a bar widget measured as null at runtime, which
 * silently produced a surface with no wallpaper in it at all — hard to spot,
 * since the tint alone still looks like a dark panel. Pass it down explicitly
 * from whoever owns the window.
 */
Item {
    id: root

    property var screen: null
    // This surface's top-left in screen coordinates.
    property real screenX: 0
    property real screenY: 0

    // Block until the wallpaper is decoded instead of letting it appear a
    // frame or two later. Only worth it for a surface whose layer texture is
    // rendered once and never dirtied again (the island's pill), where a late
    // image would never make it into the texture at all. Everywhere else this
    // is a stall on the UI thread at exactly the wrong moment — while a popup
    // is trying to animate open — so it stays off.
    property bool synchronous: false

    // The frost itself. Without this the material is a tinted wallpaper crop,
    // which reads as a flat photo behind the content rather than as glass.
    //
    // Blurred through a downscaled layer texture on purpose: the wallpaper rect
    // is the whole monitor, and several of these surfaces can be on screen at
    // once, so a full-resolution FBO each costs far more than it buys. The
    // result is blurred anyway, so nothing visible survives the downscale.
    // Raise blurDownscale if a large monitor stutters; lower it if edges of
    // high-contrast wallpapers look stepped.
    property bool blurEnabled: true
    property real blurDownscale: 4

    readonly property rect wallpaperRect: {
        // See Background.qml: the parallax inputs are read inside
        // drawRectFor(), so they must be touched here to be tracked.
        void WallpaperGeometry.parallaxDependency;
        return WallpaperGeometry.drawRectFor(root.screen);
    }
    // Only the wallpaper's own workspace parallax should glide. A surface can
    // move independently (notably a normal ApplicationWindow being dragged),
    // and its crop must follow that movement in the same frame.
    property real animatedWallpaperX: root.wallpaperRect.x
    property real animatedWallpaperY: root.wallpaperRect.y

    Behavior on animatedWallpaperX {
        NumberAnimation {
            duration: WallpaperGeometry.panDuration
            easing.type: WallpaperGeometry.panEasing
        }
    }
    Behavior on animatedWallpaperY {
        NumberAnimation {
            duration: WallpaperGeometry.panDuration
            easing.type: WallpaperGeometry.panEasing
        }
    }

    clip: true

    Image {
        id: wallpaperImage
        // Positioned so the wallpaper lands where the desktop draws it, then
        // shifted into this surface's local space.
        x: root.animatedWallpaperX - root.screenX
        y: root.animatedWallpaperY - root.screenY
        width: root.wallpaperRect.width
        height: root.wallpaperRect.height
        // Pre-blurred copy when it exists, otherwise the picture itself with a
        // live blur over it - see blurEnabled below.
        source: WallpaperGeometry.blurredReady ? WallpaperGeometry.blurredPath : WallpaperGeometry.renderPath
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: !root.synchronous

        // Only while the pre-blurred copy is still being built. Doing this per
        // surface, every frame, is exactly what the cache exists to avoid.
        layer.enabled: root.blurEnabled && !WallpaperGeometry.blurredReady
        layer.smooth: true
        layer.textureSize: Qt.size(
            Math.max(1, Math.round(wallpaperImage.width / root.blurDownscale)),
            Math.max(1, Math.round(wallpaperImage.height / root.blurDownscale)))
        layer.effect: StyledBlurEffect {
            source: wallpaperImage
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.backgroundTransparency / 2)
    }
}
