import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.bar.dynamicIsland.activities
import QtQuick
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
    property real screenX: 0
    property real screenY: 0

    function refreshScreenPosition() {
        const mapped = root.mapToItem(null, 0, 0);
        root.screenX = mapped.x;
        root.screenY = mapped.y;
    }

    Component.onCompleted: root.refreshScreenPosition()
    onXChanged: root.refreshScreenPosition()
    onYChanged: root.refreshScreenPosition()
    onWidthChanged: root.refreshScreenPosition()

    // The Bar's own layout (siblings resizing, workspace count changing,
    // etc.) can move this pill without touching root.x directly through a
    // single step — a cheap repeating refresh is what makes this reliably
    // self-correct regardless of exactly which binding chain moved it.
    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: root.refreshScreenPosition()
    }

    QtObject {
        id: mediaActivity
        readonly property string activityId: "media"
        readonly property string kind: "activity"
        readonly property bool available: true
        readonly property Component primaryContent: mediaPrimaryComponent
        readonly property string queueIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        readonly property Component expandedContent: mediaExpandedComponent
        readonly property int primaryDuration: 0 // never auto-demotes
        readonly property var flashKey: MprisController.activePlayer?.trackTitle ?? ""
    }

    // Caps Lock is a *notification*, not an activity: it announces "this just
    // toggled," not an ongoing state worth resuming — so `available` only
    // pulses true for the duration of the announcement, then resets itself,
    // and it's excluded from the queue entirely (see `kind` below).
    QtObject {
        id: capsLockNotification
        readonly property string activityId: "capsLock"
        readonly property string kind: "notification"
        property bool available: false
        readonly property bool isOn: HyprlandXkb.capsLockOn
        readonly property Component primaryContent: capsLockPrimaryComponent
        readonly property string queueIcon: "keyboard_capslock" // unused — notifications never queue
        readonly property Component expandedContent: null
        readonly property int primaryDuration: 3000
        readonly property var flashKey: HyprlandXkb.capsLockOn

        onFlashKeyChanged: capsLockNotification.available = true
    }

    // Future entries get added here, e.g.:
    // QtObject { id: timerActivity; readonly property string activityId: "timer"; readonly property string kind: "activity"; readonly property bool available: SomeService.running; readonly property Component primaryContent: ...; readonly property string queueIcon: "timer"; readonly property Component expandedContent: ...; readonly property int primaryDuration: 0; readonly property var flashKey: SomeService.secondsLeft }
    readonly property list<QtObject> activities: [mediaActivity, capsLockNotification]

    property string activePrimaryId: "media"
    readonly property QtObject primaryActivity: activities.find(a => a.activityId === root.activePrimaryId) ?? mediaActivity
    // Notifications never sit in the queue — once they're not primary, they're just gone.
    readonly property list<QtObject> queuedActivities: activities.filter(a => a.available && a.kind === "activity" && a !== root.primaryActivity)

    function promote(activity) {
        const previous = root.primaryActivity;
        root.activePrimaryId = activity.activityId;
        demoteTimer.stop();
        if (previous && previous !== activity && previous.kind === "notification")
            previous.available = false;
        if (activity.primaryDuration > 0)
            demoteTimer.start();
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

    // Whether the pill's bottom edge should flatten flat against the
    // overlay below it (see IslandOverlay.qml for the matching top-flatten).
    readonly property bool mergedWithOverlay: root.pinned && !!root.primaryActivity?.expandedContent

    // The actual visible pill — inset from root's top/bottom like every
    // other BarGroup pill's background (topMargin/bottomMargin: 4), instead
    // of filling the full bar-row height edge-to-edge.
    Rectangle {
        id: pillBackground
        topLeftRadius: Appearance.rounding.small
        topRightRadius: Appearance.rounding.small
        bottomLeftRadius: root.mergedWithOverlay ? 0 : Appearance.rounding.small
        bottomRightRadius: root.mergedWithOverlay ? 0 : Appearance.rounding.small
        color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
        anchors {
            fill: parent
            topMargin: 4
            bottomMargin: 4
        }

        Behavior on bottomLeftRadius {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(pillBackground)
        }
        Behavior on bottomRightRadius {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(pillBackground)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.pinned = !root.pinned
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

            Loader {
                id: primaryLoader
                Layout.fillWidth: true
                sourceComponent: root.primaryActivity?.primaryContent ?? null

                // Content swap in a fixed slot: crossfade only, no position
                // change — see docs/design/motion.md#recipes.
                opacity: 1
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(primaryLoader)
                }
                onSourceComponentChanged: {
                    opacity = 0;
                    fadeBackTimer.restart();
                }
                Timer {
                    id: fadeBackTimer
                    interval: 1
                    onTriggered: primaryLoader.opacity = 1
                }
            }

            Repeater {
                model: root.queuedActivities
                delegate: RippleButton {
                    id: queueChip
                    required property QtObject modelData
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colLayer2
                    colBackgroundHover: Appearance.colors.colLayer2Hover
                    contentItem: MaterialSymbol {
                        // `anchors.centerIn: parent` fights Control's own
                        // imperative content-box resizing here — center via
                        // text alignment instead (matches PlayerControl.qml's
                        // TrackChangeButton, the established icon-only pattern).
                        horizontalAlignment: Text.AlignHCenter
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        text: queueChip.modelData.queueIcon
                        color: Appearance.colors.colOnLayer2
                    }
                    onClicked: root.promote(queueChip.modelData)

                    // List item enter/exit: local spatial pop, not a fade —
                    // see docs/design/motion.md#recipes.
                    scale: 0
                    Behavior on scale {
                        animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(queueChip)
                    }
                    Component.onCompleted: scale = 1
                }
            }
        }
    }

    Component {
        id: mediaPrimaryComponent
        MediaPrimary {}
    }
    Component {
        id: mediaExpandedComponent
        MediaExpanded {}
    }
    Component {
        id: capsLockPrimaryComponent
        CapsLockPrimary {}
    }

    IslandOverlay {
        anchorScreenX: root.screenX
        anchorScreenY: root.screenY
        anchorWidth: pillBackground.width
        shown: root.mergedWithOverlay
        sourceComponent: root.primaryActivity?.expandedContent ?? null
    }
}
