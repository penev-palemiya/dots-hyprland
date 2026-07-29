import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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
    property real screenWidth: root.QsWindow.window?.screen?.width ?? 0
    property real screenHeight: root.QsWindow.window?.screen?.height ?? 0
    property real pillScreenX: 0
    property real pillScreenY: 0
    property real pillScreenWidth: 0
    property real pillScreenHeight: 0

    readonly property color pillSurfaceColor: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
    readonly property color expandedSurfaceColor: root.computeExpandedSurfaceColor()
    readonly property real overlayLeftMargin: root.computeOverlayLeftMargin()
    readonly property real overlayRightMargin: root.computeOverlayRightMargin()
    readonly property real overlayTopMargin: root.computeOverlayTopMargin()
    readonly property real overlayBottomMargin: root.computeOverlayBottomMargin()

    function computeExpandedSurfaceColor() {
        if (Config.options?.bar.borderless)
            return "transparent";
        if (!Config.options.bar.showBackground)
            return root.pillSurfaceColor;
        return ColorUtils.compositeOver(root.pillSurfaceColor, Appearance.colors.colLayer0);
    }

    function computeOverlayLeftMargin() {
        if (!Config.options.bar.vertical)
            return root.pillScreenX;
        return Config.options.bar.bottom ? 0 : root.pillScreenX + root.pillScreenWidth;
    }

    function computeOverlayRightMargin() {
        if (!Config.options.bar.vertical || !Config.options.bar.bottom)
            return 0;
        return Math.max(0, root.screenWidth - root.pillScreenX);
    }

    function computeOverlayTopMargin() {
        if (!Config.options.bar.vertical)
            return Config.options.bar.bottom ? 0 : root.pillScreenY + root.pillScreenHeight;
        return root.pillScreenY;
    }

    function computeOverlayBottomMargin() {
        if (Config.options.bar.vertical || !Config.options.bar.bottom)
            return 0;
        return Math.max(0, root.screenHeight - root.pillScreenY);
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
        color: root.pillSurfaceColor
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

            Item {
                id: primaryTransitionSlot
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Math.max(incomingLoader.implicitHeight, outgoingLoader.implicitHeight)
                clip: true

                property Component sourceComponent: root.primaryActivity?.primaryContent ?? null
                property Component displayedSourceComponent
                property Component outgoingSourceComponent
                property bool initialized: false
                property bool transitionRunning: false
                property real incomingOpacity: 1
                property real outgoingOpacity: 0
                property real incomingOffset: 0
                property real outgoingOffset: 0
                property real incomingScale: 1
                property real outgoingScale: 1
                readonly property real transitionDistance: 8

                function setCurrentSource(nextSource) {
                    if (displayedSourceComponent === nextSource)
                        return;

                    if (!initialized || !displayedSourceComponent || !nextSource) {
                        transitionAnimation.stop();
                        outgoingSourceComponent = null;
                        displayedSourceComponent = nextSource;
                        transitionRunning = false;
                        incomingOpacity = 1;
                        outgoingOpacity = 0;
                        incomingOffset = 0;
                        outgoingOffset = 0;
                        incomingScale = 1;
                        outgoingScale = 1;
                        return;
                    }

                    transitionAnimation.stop();
                    outgoingSourceComponent = displayedSourceComponent;
                    displayedSourceComponent = nextSource;
                    transitionRunning = true;
                    incomingOpacity = 0;
                    outgoingOpacity = 1;
                    incomingOffset = transitionDistance;
                    outgoingOffset = 0;
                    incomingScale = 0.96;
                    outgoingScale = 1;
                    transitionAnimation.restart();
                }

                Component.onCompleted: {
                    initialized = true;
                    setCurrentSource(sourceComponent);
                }

                onSourceComponentChanged: setCurrentSource(sourceComponent)

                Loader {
                    id: outgoingLoader
                    width: parent.width
                    height: implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    visible: primaryTransitionSlot.transitionRunning
                    opacity: primaryTransitionSlot.outgoingOpacity
                    scale: primaryTransitionSlot.outgoingScale
                    sourceComponent: primaryTransitionSlot.outgoingSourceComponent
                    transform: Translate {
                        y: primaryTransitionSlot.outgoingOffset
                    }
                }

                Loader {
                    id: incomingLoader
                    width: parent.width
                    height: implicitHeight
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: primaryTransitionSlot.incomingOpacity
                    scale: primaryTransitionSlot.incomingScale
                    sourceComponent: primaryTransitionSlot.displayedSourceComponent
                    transform: Translate {
                        y: primaryTransitionSlot.incomingOffset
                    }
                }

                ParallelAnimation {
                    id: transitionAnimation

                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "incomingOpacity"
                        to: 1
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "outgoingOpacity"
                        to: 0
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "incomingOffset"
                        to: 0
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }
                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "outgoingOffset"
                        to: -primaryTransitionSlot.transitionDistance
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }
                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "incomingScale"
                        to: 1
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }
                    NumberAnimation {
                        target: primaryTransitionSlot
                        property: "outgoingScale"
                        to: 0.98
                        duration: Appearance.animation.elementMoveSmall.duration
                        easing.type: Appearance.animation.elementMoveSmall.type
                        easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
                    }

                    onStopped: {
                        primaryTransitionSlot.transitionRunning = false;
                        primaryTransitionSlot.outgoingSourceComponent = null;
                        primaryTransitionSlot.incomingOpacity = 1;
                        primaryTransitionSlot.outgoingOpacity = 0;
                        primaryTransitionSlot.incomingOffset = 0;
                        primaryTransitionSlot.outgoingOffset = 0;
                        primaryTransitionSlot.incomingScale = 1;
                        primaryTransitionSlot.outgoingScale = 1;
                    }
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
        id: islandOverlay
        anchorLeftMargin: root.overlayLeftMargin
        anchorTopMargin: root.overlayTopMargin
        anchorRightMargin: root.overlayRightMargin
        anchorBottomMargin: root.overlayBottomMargin
        anchorWidth: root.pillScreenWidth
        surfaceColor: root.expandedSurfaceColor
        shown: root.overlayOpen
        sourceComponent: root.primaryActivity?.expandedContent ?? null
    }
}
