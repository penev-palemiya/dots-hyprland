import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.bar.dynamicIsland.activities
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts

/**
 * A fixed-width pill hosting a "primary" activity (full-width row, on the
 * left) plus a background "queue" of other currently-available activities
 * shown as small icon chips on the right. Media is the permanent baseline —
 * always available, no attention-timeout — the island falls back to it
 * whenever nothing else is claiming the spotlight.
 *
 * This pill is drawn inline, as part of the bar's own surface — not a
 * floating window — so its position is always exactly whatever the bar's
 * own layout says, with zero cross-window position math involved. Only the
 * *expanded* detail view (IslandOverlay, click-to-reveal) lives in a
 * separate floating window, since that's the one piece of content that
 * needs to visually grow past the bar's own fixed height. To keep that from
 * reading as a second popup, IslandOverlay fuses its top corners flat
 * against this pill's bottom corners (also flattened while expanded) so the
 * two draw as one continuous shape — see docs/design/motion.md#container-transform.
 *
 * Two kinds of entries, both can become primary the same way, but differ
 * in what happens once they step down:
 * - "activity" (e.g. media): an ongoing thing you can return to — when
 *   demoted it parks as a small icon in the queue, clickable to bring back.
 * - "notification" (e.g. Caps Lock toggled): a one-off announcement of
 *   something that just happened, not an ongoing state worth resuming —
 *   when demoted it's simply gone, never shown in the queue. (There may be
 *   a third kind later for plain system events; not needed yet.)
 *
 * When an entry's state changes it *promotes* itself to primary, bumping
 * whatever was primary into the queue (if it's an "activity" and still
 * available). Entries with a `primaryDuration` auto-demote after that long
 * if nothing newer took over, and media reclaims the spotlight. Clicking a
 * queued icon promotes it back — the previous primary simply reappears in
 * the queue, no special swap bookkeeping needed.
 *
 * Width never changes. Height only changes for the *explicit* click-to-see
 * -detail overlay (independent of promotion, which is a width/position
 * change, not a height one).
 */
Item {
    id: root

    implicitHeight: Appearance.sizes.baseBarHeight
    // implicitWidth is left for the caller to set (BarContent sets it to
    // root.centerSideModuleWidth, same fixed budget the old leftCenterGroup used)

    // How far the content sits from pillBackground's edges — matches
    // BarGroup's own default padding, and leaves room for anything that
    // needs to animate right up to the pill's border without clipping.
    readonly property real contentPadding: 8

    // "Explicit click to see more detail" state — independent of promotion.
    property bool pinned: false

    // Where this pill actually sits on screen, for IslandOverlay (a
    // *different* window) to align itself to. Computed with plain QtQuick
    // `Item.mapToItem(null, ...)` — "map to the scene," i.e. this window's
    // own root — which equals real screen coordinates because the Bar's
    // window spans the full screen edge-to-edge with zero margin. This is
    // deliberately NOT Quickshell's `QsWindow`/`mapFromItem` cross-window
    // mechanism: that repeatedly resolved to the wrong window or refused to
    // work on a window degenerate enough not to be "a member of a window"
    // yet (confirmed via live logging). Passing plain numbers as ordinary
    // properties into IslandOverlay sidesteps all of that.
    readonly property var barScreen: root.QsWindow?.window?.screen ?? null
    property real screenWidth: root.barScreen?.width ?? 0
    property real screenHeight: root.barScreen?.height ?? 0
    property real pillScreenX: 0
    property real pillScreenY: 0
    property real pillScreenWidth: 0
    property real pillScreenHeight: 0

    readonly property color pillSurfaceColor: Appearance.colors.colLayer1
    readonly property color expandedSurfaceColor: root.computeExpandedSurfaceColor()
    readonly property real overlaySeamOverlap: 1
    readonly property real overlayLeftMargin: root.computeOverlayLeftMargin()
    readonly property real overlayRightMargin: 0
    readonly property real overlayTopMargin: root.computeOverlayTopMargin()
    readonly property real overlayBottomMargin: root.computeOverlayBottomMargin()

    function computeExpandedSurfaceColor() {
        if (!Config.options.bar.showBackground)
            return ColorUtils.applyAlpha(root.pillSurfaceColor, 1);
        return ColorUtils.applyAlpha(ColorUtils.compositeOver(root.pillSurfaceColor, Appearance.colors.colLayer0Base), 1);
    }

    function computeOverlayLeftMargin() {
        return root.pillScreenX;
    }

    function computeOverlayTopMargin() {
        return Config.options.bar.bottom ? 0 : Math.max(0, root.pillScreenY + root.pillScreenHeight - root.overlaySeamOverlap);
    }

    function computeOverlayBottomMargin() {
        return Config.options.bar.bottom ? Math.max(0, root.screenHeight - root.pillScreenY - root.overlaySeamOverlap) : 0;
    }

    function refreshScreenPosition() {
        const pillMapped = pillBackground.mapToItem(null, 0, 0);
        root.pillScreenX = pillMapped.x;
        root.pillScreenY = pillMapped.y;
        root.pillScreenWidth = pillBackground.width;
        root.pillScreenHeight = pillBackground.height;
    }

    Component.onCompleted: root.refreshScreenPosition()
    onXChanged: root.refreshScreenPosition()
    onYChanged: root.refreshScreenPosition()
    onWidthChanged: root.refreshScreenPosition()
    onHeightChanged: root.refreshScreenPosition()

    // While expanded, keep correcting for parent layout movement that does
    // not necessarily show up as a direct x/y change on this item.
    Timer {
        interval: 200
        running: root.mergedWithOverlay
        repeat: true
        onTriggered: root.refreshScreenPosition()
    }

    IslandActivityRegistry {
        id: activityRegistry
    }

    property string activePrimaryId: "media"
    readonly property var activities: activityRegistry.activities
    readonly property QtObject primaryActivity: activities.find(a => a.activityId === root.activePrimaryId) ?? activityRegistry.fallbackActivity

    /**
     * `explicit` marks a promotion the user asked for — clicking a queue chip
     * — as opposed to one an entry triggered by itself via `flashKey`.
     * `primaryDuration` exists to time out *automatic* attention-grabs; taking
     * the spotlight away from something the user deliberately selected is just
     * the island overriding them, so explicit promotions never auto-demote.
     */
    function promote(activity, explicit = false) {
        const previous = root.primaryActivity;
        root.activePrimaryId = activity.activityId;
        demoteTimer.stop();
        if (previous && previous !== activity && previous.kind === "notification")
            previous.available = false;
        if (!explicit && activity.primaryDuration > 0)
            demoteTimer.start();
    }

    // Reading the expanded panel must not be interrupted. The countdown is
    // suspended while the overlay is open and resumes once it's closed, so an
    // entry that auto-promoted still steps back eventually — just not out from
    // under the panel you were looking at.
    onOverlayOpenChanged: {
        if (root.overlayOpen)
            demoteTimer.stop();
        else if ((root.primaryActivity?.primaryDuration ?? 0) > 0 && root.activePrimaryId !== "media")
            demoteTimer.restart();
    }

    Timer {
        id: demoteTimer
        interval: root.primaryActivity?.primaryDuration ?? 0
        onTriggered: {
            const demoted = root.primaryActivity;
            root.activePrimaryId = "media";
            if (demoted && demoted.kind === "notification")
                demoted.available = false;
        }
    }

    // Re-promote whenever an activity's flashKey changes while available (a
    // new song, a fresh toggle), and fall back to media if the current
    // primary stops being available out from under itself.
    Repeater {
        model: root.activities
        delegate: Item {
            required property QtObject modelData
            Connections {
                target: modelData
                function onFlashKeyChanged() {
                    if (modelData.available)
                        root.promote(modelData);
                }
                function onAvailableChanged() {
                    if (modelData.available)
                        root.promote(modelData);
                    else if (root.activePrimaryId === modelData.activityId)
                        root.activePrimaryId = "media";
                }
            }
        }
    }

    readonly property bool hasExpandedContent: !!root.primaryActivity?.expandedContent
    readonly property bool overlayOpen: root.pinned && root.hasExpandedContent
    // Whether the pill's bottom edge should flatten flat against the overlay
    // below it. Use IslandOverlay's actual animated height so the pill rounds
    // back only after the panel is visually gone, including interrupted closes.
    readonly property bool mergedWithOverlay: root.hasExpandedContent && (root.overlayOpen || islandOverlay.visibleHeight > 0.5)

    // The actual visible pill — inset from root's top/bottom like every
    // other BarGroup pill's background (topMargin/bottomMargin: 4), instead
    // of filling the full bar-row height edge-to-edge.
    Rectangle {
        id: pillBackground
        topLeftRadius: Appearance.rounding.small
        topRightRadius: Appearance.rounding.small
        bottomLeftRadius: root.mergedWithOverlay ? 0 : Appearance.rounding.small
        bottomRightRadius: root.mergedWithOverlay ? 0 : Appearance.rounding.small
        color: (Config.options.appearance.transparency.enable && root.mergedWithOverlay) ? "transparent" : root.mergedWithOverlay ? root.expandedSurfaceColor : root.pillSurfaceColor
        layer.enabled: Config.options.appearance.transparency.enable && root.mergedWithOverlay
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: pillBackground.width
                height: pillBackground.height
                topLeftRadius: pillBackground.topLeftRadius
                topRightRadius: pillBackground.topRightRadius
                bottomLeftRadius: pillBackground.bottomLeftRadius
                bottomRightRadius: pillBackground.bottomRightRadius
            }
        }
        anchors {
            fill: parent
            topMargin: 4
            bottomMargin: 4
        }

        Behavior on bottomLeftRadius {
            enabled: !root.overlayOpen
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(pillBackground)
        }
        Behavior on bottomRightRadius {
            enabled: !root.overlayOpen
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(pillBackground)
        }

        Loader {
            anchors.fill: parent
            // Kept active whenever transparency is on — NOT gated on
            // mergedWithOverlay — so the screen-sized wallpaper Image is
            // decoded once and stays resident. Gating `active` here tore the
            // Loader down on every close and rebuilt it (asynchronously) on
            // every open, so for the first frames of a reveal the pill was
            // still literally transparent and showed the bar's own lighter
            // colLayer0 background through itself, while the overlay below —
            // whose Loader is permanently active — was already painting the
            // finished wallpaper+tint material. That is the "two different
            // materials" seam. Visibility, not existence, is what toggles.
            active: Config.options.appearance.transparency.enable
            // Not asynchronous: an item that appears after the pill's layer
            // texture has been rendered never gets into it (see the Image's
            // own comment in IslandWallpaper.qml).
            asynchronous: false

            sourceComponent: IslandWallpaper {
                visible: root.mergedWithOverlay
                screenX: root.pillScreenX
                screenY: root.pillScreenY
                screenW: root.screenWidth
                screenH: root.screenHeight
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                root.refreshScreenPosition();
                root.pinned = !root.pinned;
            }
        }

        RowLayout {
            // Horizontal padding only — vertical space is never forced, the
            // loaded content centers at its own natural height (same recipe
            // BarGroup uses), so content is never squeezed shorter than it needs.
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                leftMargin: root.contentPadding
                rightMargin: root.contentPadding
            }
            spacing: 6

            IslandPrimary {
                Layout.fillWidth: true
                Layout.fillHeight: true
                activity: root.primaryActivity
            }

            IslandQueue {
                Layout.alignment: Qt.AlignVCenter
                activities: root.activities
                primaryActivity: root.primaryActivity
                promoteCallback: function(activity) {
                    root.promote(activity, true);
                }
            }
        }
    }

    IslandOverlay {
        id: islandOverlay
        anchorLeftMargin: root.overlayLeftMargin
        anchorTopMargin: root.overlayTopMargin
        anchorRightMargin: root.overlayRightMargin
        anchorBottomMargin: root.overlayBottomMargin
        anchorWidth: root.pillScreenWidth
        targetScreen: root.barScreen
        screenWidth: root.screenWidth
        screenHeight: root.screenHeight
        surfaceColor: root.expandedSurfaceColor
        shown: root.overlayOpen
        sourceComponent: root.primaryActivity?.expandedContent ?? null
        onDismissRequested: root.pinned = false
    }
}
