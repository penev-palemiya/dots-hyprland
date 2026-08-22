import qs.modules.common
import qs.modules.common.functions
import QtQuick

/**
 * The island's frosted backdrop — the wallpaper as it appears at this
 * surface's own place on screen, plus the shared tint on top.
 *
 * Both island surfaces (the inline pill and the floating IslandOverlay) use
 * THIS component, which is the whole point: they are separate Wayland
 * surfaces, so the only way their material can be guaranteed to match is for
 * the crop and the tint to come from one piece of code rather than from two
 * copies that merely look alike.
 *
 * The crop is taken with `sourceClipRect` — the exact source-pixel rectangle
 * that lands under this surface — instead of the obvious alternative of a
 * full-screen Image shifted by -screenX/-screenY. That alternative measured
 * as *not rendering at all* inside the pill (a 380x32 layered item): the tint
 * beside it painted fine while the image contributed literally zero variance,
 * leaving the pill a flat colLayer0Base while the overlay showed real
 * wallpaper. Cropping means each surface uploads only the pixels it needs, so
 * there is no oversized child geometry to be dropped, and it is far cheaper
 * than decoding a screen-sized texture per surface.
 *
 * Keep the item's size stable while a parent animates: `sourceClipRect`
 * changes force the image to reload, so an animating height here would
 * re-decode every frame. IslandOverlay therefore sizes this to the panel's
 * FINAL height and lets the panel's own clip reveal it.
 */
Item {
    id: root

    // This surface's top-left in screen coordinates, and the full screen size
    // the wallpaper is displayed at (PreserveAspectCrop, as Background.qml does).
    property real screenX: 0
    property real screenY: 0
    property real screenW: 0
    property real screenH: 0

    // Natural (undecoded) wallpaper dimensions, needed to map screen
    // coordinates back into source pixels. Shares the image cache with every
    // other user of the same wallpaper, so this costs nothing extra.
    Image {
        id: probe
        source: Config.options.background.wallpaperPath
        cache: true
        // Loaded synchronously and read through `sourceSize`, not
        // `implicitWidth`: with an async probe the natural size stayed 0
        // forever here, which left the mapping invalid and every island
        // surface falling back to a flat tint with no wallpaper at all.
        // `sourceSize` is the documented way to ask an Image for the
        // intrinsic dimensions of its source, and the decode is shared
        // through the image cache with everything else showing this wallpaper.
        asynchronous: false
        visible: false
    }

    readonly property real natW: probe.sourceSize.width
    readonly property real natH: probe.sourceSize.height
    // PreserveAspectCrop scales by whichever axis needs the most magnification,
    // then centres the overflow — mirror that to invert the mapping.
    readonly property real coverScale: (natW > 0 && natH > 0 && screenW > 0 && screenH > 0) ? Math.max(screenW / natW, screenH / natH) : 0
    readonly property real overflowX: (natW * coverScale - screenW) / 2
    readonly property real overflowY: (natH * coverScale - screenH) / 2
    readonly property bool mappingReady: coverScale > 0 && root.width > 0 && root.height > 0

    Image {
        anchors.fill: parent
        // A null sourceClipRect means "do not clip" to Qt, i.e. the ENTIRE
        // wallpaper squeezed into this small surface — so stay hidden until
        // the probe has reported a real natural size and the mapping is valid.
        visible: root.mappingReady
        source: Config.options.background.wallpaperPath
        cache: true
        // Synchronous on purpose. The pill is a static layered item: once its
        // layer texture is rendered nothing dirties it again, so an image that
        // arrived asynchronously — after that one render — never made it into
        // the texture, and the pill stayed a flat tint forever. (The overlay
        // got away with it only because its animating height re-rendered the
        // layer every frame.) The crop is small and cache-shared, so this is
        // cheap.
        asynchronous: false
        // The clip rect already has this item's exact aspect ratio, so a
        // straight stretch is a 1:1 mapping — no second crop to disagree about.
        fillMode: Image.Stretch
        sourceClipRect: root.mappingReady ? Qt.rect((root.screenX + root.overflowX) / root.coverScale, (root.screenY + root.overflowY) / root.coverScale, root.width / root.coverScale, root.height / root.coverScale) : Qt.rect(0, 0, 0, 0)
    }

    // The one tint definition for the whole island.
    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.backgroundTransparency / 2)
    }
}
