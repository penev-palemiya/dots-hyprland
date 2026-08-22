import qs.modules.common
import qs.modules.common.functions
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
 * Give it the surface's top-left in screen coordinates and the full screen
 * size; it draws the wallpaper exactly as Background.qml does (screen-sized,
 * PreserveAspectCrop), shifted so this surface's rectangle lands over it, and
 * clips the rest.
 *
 * `screenW`/`screenH` must be real screen dimensions. Resolving them via
 * `QsWindow.window.screen` from inside a bar widget measured as null at
 * runtime, which silently left them 0, sized the Image to 0x0 and produced a
 * surface with no wallpaper in it at all — indistinguishable at a glance from
 * a correct one, since the tint alone still looks like a dark panel. Pass the
 * screen down explicitly from whoever owns the window.
 */
Item {
    id: root

    // This surface's top-left in screen coordinates.
    property real screenX: 0
    property real screenY: 0
    // The full screen size the wallpaper is displayed at.
    property real screenW: 0
    property real screenH: 0

    clip: true

    Image {
        x: -root.screenX
        y: -root.screenY
        width: root.screenW
        height: root.screenH
        source: Config.options.background.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        cache: true
        // Synchronous on purpose: a static layered surface (the island's pill)
        // renders its layer texture once and nothing dirties it again, so an
        // image that arrived later would never make it into that texture.
        asynchronous: false
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.backgroundTransparency / 2)
    }
}
