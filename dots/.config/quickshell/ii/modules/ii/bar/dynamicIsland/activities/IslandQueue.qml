import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * The pill's right-hand chip row. Chips that only perform a direct action
 * (mic mute) stay visible; everything promotable collapses behind a single
 * dot and expands inline when the dot is clicked.
 *
 * Why collapse at all: the pill's width is fixed, so every chip here is width
 * taken away from IslandTextStack — the track title or notification body. A
 * collapsed queue gives that text back most of the time, and the chips are
 * one click away when they're actually wanted.
 *
 * This replaces the old `more_horiz` overflow chip, which cycled through
 * hidden activities one at a time on repeated clicks — you could not see what
 * was hidden, only step through it blind.
 *
 * The dot sits last so it never moves: the queue is right-aligned against the
 * pill's edge, so the revealed chips grow leftward out of it while the dot
 * itself stays put.
 */
RowLayout {
    id: root

    property var activities: []
    property var primaryActivity
    property var promoteCallback

    // How many promotable chips stay inline before the rest collapse. 0 keeps
    // the queue at its tidiest; raise it to keep the first chip(s) always on
    // screen at the cost of some text width.
    property int maxVisibleChips: 0
    // Sticky, like the system tray's collapse — hover-expanding would make the
    // pill's text reflow every time the cursor crossed the bar.
    property bool expanded: false

    readonly property var queuedActivities: activities.filter(function (activity) {
        return activity.available && activity.kind === "activity" && activity !== root.primaryActivity;
    })
    // Direct-action chips are the queue's equivalent of a pinned tray icon:
    // they exist to be tapped, so burying them behind a toggle would turn a
    // one-tap mute into two.
    readonly property var actionActivities: queuedActivities.filter(function (activity) {
        return activity.hasQueueAction;
    }).sort(root.sortByPriorityThenRegistry)
    readonly property var openableActivities: queuedActivities.filter(function (activity) {
        return !activity.hasQueueAction;
    }).sort(root.sortByPriorityThenRegistry)

    // Collapsing swaps N chips for one dot, so it only buys width when N >= 2.
    // Hiding a single chip costs exactly as much room as showing it, and you
    // lose the one thing the chip was telling you — *which* activity is
    // waiting. So below that threshold everything simply stays inline.
    readonly property int inlineLimit: Math.max(0, root.maxVisibleChips)
    readonly property bool collapseWorthIt: openableActivities.length - inlineLimit >= 2
    readonly property var inlineActivities: collapseWorthIt ? openableActivities.slice(0, inlineLimit) : openableActivities
    readonly property var hiddenActivities: collapseWorthIt ? openableActivities.slice(inlineLimit) : []
    readonly property bool hasHidden: hiddenActivities.length > 0

    onHasHiddenChanged: if (!root.hasHidden) root.expanded = false

    // 0 collapsed, 1 fully expanded. Enter on the slower/bouncier token, exit
    // on the faster one — docs/design/motion.md §"Enter vs exit is asymmetric".
    // Not `readonly`: a Behavior has to write to the property it animates.
    property real revealPhase: root.expanded ? 1 : 0

    Behavior on revealPhase {
        NumberAnimation {
            duration: root.expanded ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
        }
    }

    // Chip `index` starts at its own point in the phase and takes half of it to
    // arrive, so the last one always lands at the same moment however many
    // there are. Same helper shape as StyledPopup's section stagger.
    function chipProgress(index) {
        const steps = Math.max(1, root.hiddenActivities.length - 1);
        const start = Math.min(0.5, (index / steps) * 0.5);
        return Math.max(0, Math.min(1, (root.revealPhase - start) / 0.5));
    }

    function sortByPriorityThenRegistry(a, b) {
        const priorityDelta = (b.queuePriority || 0) - (a.queuePriority || 0);
        if (priorityDelta !== 0)
            return priorityDelta;

        return root.registryIndex(a) - root.registryIndex(b);
    }

    function registryIndex(activity) {
        const index = root.activities.indexOf(activity);
        return index >= 0 ? index : 9999;
    }

    // How many slots are unconditionally present. This has to drive `visible`
    // on its own: a Layout that isn't visible doesn't lay its children out, so
    // deriving visibility purely from implicitWidth latches the row at zero
    // forever once it has been empty even once. (Only reproducible when this
    // row is nested inside another Layout, which is exactly how the pill uses
    // it.) The implicitWidth term is still there so a collapse animation can
    // finish before the row disappears.
    readonly property int chipCount: actionActivities.length + inlineActivities.length + (hasHidden ? 1 : 0)

    // The width itself is left to the layout: the chips animate their own
    // widths and drop out of the layout once collapsed, so the row's implicit
    // width follows them without a formula or a second Behavior fighting it.
    visible: chipCount > 0 || implicitWidth > 0.5
    spacing: 6
    clip: true

    Repeater {
        model: root.actionActivities

        delegate: IslandQueueChip {
            required property QtObject modelData

            activity: modelData
            onClicked: {
                if (modelData.hasQueueAction)
                    modelData.queueAction();
                else if (root.promoteCallback)
                    root.promoteCallback(modelData);
            }
        }
    }

    Repeater {
        model: root.inlineActivities

        delegate: IslandQueueChip {
            required property QtObject modelData

            activity: modelData
            onClicked: if (root.promoteCallback)
                root.promoteCallback(modelData)
        }
    }

    Repeater {
        model: root.hiddenActivities

        delegate: Item {
            id: hiddenSlot

            required property QtObject modelData
            required property int index
            readonly property real progress: root.chipProgress(hiddenSlot.index)

            // Collapsing to zero width *and* going invisible is what makes the
            // row's spacing collapse with it instead of leaving a gap.
            implicitWidth: 30 * hiddenSlot.progress
            implicitHeight: 30
            visible: hiddenSlot.progress > 0.001
            opacity: hiddenSlot.progress
            scale: hiddenSlot.progress
            Layout.alignment: Qt.AlignVCenter

            IslandQueueChip {
                anchors.centerIn: parent
                activity: hiddenSlot.modelData
                onClicked: if (root.promoteCallback)
                    root.promoteCallback(hiddenSlot.modelData)
            }
        }
    }

    IslandQueueChip {
        shown: root.hasHidden
        dot: true
        activity: null
        // The count is only news while collapsed; once the chips are on screen
        // it just restates what you can already see.
        badgeCount: root.expanded ? 0 : root.hiddenActivities.length
        onClicked: root.expanded = !root.expanded
    }
}
