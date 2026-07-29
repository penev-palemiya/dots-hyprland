import qs.modules.common
import qs.services
import QtQuick

/**
 * A fixed-width pill that hosts one "activity" at a time, picked from an
 * ordered list by priority (first available wins). Media is the permanent
 * fallback activity — it always reports available and has its own "No
 * media" empty state, so the island never shows nothing. Future activities
 * (a running timer, a call-style alert, ...) get prepended to `activities`
 * with their own `available` condition and will transparently take over
 * the island while active, falling back to media once they're not.
 *
 * Width never changes. Height can: clicking the pill toggles a persistent
 * expanded state (`pinned`), and the island also briefly auto-expands on
 * its own (`flashing`) whenever the active activity's `flashKey` changes
 * (new song, a different activity taking over, ...). Either state shows
 * the active activity's `expandedContent` (if it declares one) in an
 * IslandOverlay attached directly below/above the pill.
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

    property bool pinned: false
    property bool flashing: false
    readonly property bool expanded: pinned || flashing
    property bool _ready: false // guards against flashing once on initial load

    QtObject {
        id: mediaActivity
        readonly property bool available: true
        readonly property Component compactContent: mediaCompactComponent
        readonly property Component expandedContent: mediaExpandedComponent
        readonly property var flashKey: MprisController.activePlayer?.trackTitle ?? ""
    }

    // Future activities get prepended here, e.g.:
    // QtObject { id: timerActivity; readonly property bool available: SomeService.running; readonly property Component compactContent: ...; readonly property Component expandedContent: ...; readonly property var flashKey: SomeService.running }
    readonly property list<QtObject> activities: [mediaActivity]
    readonly property QtObject activeActivity: activities.find(a => a.available) ?? null

    function flash() {
        if (!root._ready)
            return;
        root.flashing = true;
        flashTimer.restart();
    }

    Timer {
        id: flashTimer
        interval: 3000
        onTriggered: root.flashing = false
    }

    Component.onCompleted: Qt.callLater(() => root._ready = true)

    onActiveActivityChanged: root.flash()
    Connections {
        target: root.activeActivity
        function onFlashKeyChanged() {
            root.flash();
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

        Loader {
            // Horizontal padding only — vertical space is never forced, the
            // loaded item centers at its own natural height (same recipe
            // BarGroup uses), so content is never squeezed shorter than it needs.
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                right: parent.right
                leftMargin: root.contentPadding
                rightMargin: root.contentPadding
            }
            sourceComponent: root.activeActivity?.compactContent ?? null
        }
    }

    Component {
        id: mediaCompactComponent
        MediaCompact {}
    }
    Component {
        id: mediaExpandedComponent
        MediaExpanded {}
    }

    IslandOverlay {
        anchorTarget: pillBackground
        shown: root.expanded && !!root.activeActivity?.expandedContent
        sourceComponent: root.activeActivity?.expandedContent ?? null
    }
}
