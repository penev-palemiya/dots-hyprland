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

    readonly property rect wallpaperRect: WallpaperGeometry.drawRectFor(root.screen)

    clip: true

    Image {
        // Positioned so the wallpaper lands where the desktop draws it, then
        // shifted into this surface's local space.
        x: root.wallpaperRect.x - root.screenX
        y: root.wallpaperRect.y - root.screenY
        width: root.wallpaperRect.width
        height: root.wallpaperRect.height
        source: WallpaperGeometry.path
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: !root.synchronous

        // Matches the desktop's own glide, so the glass pans in lockstep with
        // the wallpaper behind it rather than snapping ahead of it.
        Behavior on x {
            NumberAnimation {
                duration: WallpaperGeometry.panDuration
                easing.type: WallpaperGeometry.panEasing
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: WallpaperGeometry.panDuration
                easing.type: WallpaperGeometry.panEasing
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.backgroundTransparency / 2)
    }
}
