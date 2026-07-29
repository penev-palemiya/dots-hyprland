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

    // The actual visible pill — inset from root's top/bottom like every
    // other BarGroup pill's background (topMargin/bottomMargin: 4), instead
    // of filling the full bar-row height edge-to-edge.
    Rectangle {
        id: pillBackground
        radius: Appearance.rounding.small
        color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
        anchors {
            fill: parent
            topMargin: 4
            bottomMargin: 4
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
                Layout.fillWidth: true
                sourceComponent: root.primaryActivity?.primaryContent ?? null
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
                        anchors.centerIn: parent
                        fill: 1
                        iconSize: Appearance.font.pixelSize.normal
                        text: queueChip.modelData.queueIcon
                        color: Appearance.colors.colOnLayer2
                    }
                    onClicked: root.promote(queueChip.modelData)
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
        anchorTarget: pillBackground
        shown: root.pinned && !!root.primaryActivity?.expandedContent
        sourceComponent: root.primaryActivity?.expandedContent ?? null
    }
}
