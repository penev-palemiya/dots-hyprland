import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root

    property var activities: []
    property var primaryActivity
    property int maxVisibleChips: 3
    property var promoteCallback
    property int overflowCursor: 0
    readonly property var queuedActivities: activities.filter(function(activity) {
        return activity.available && activity.kind === "activity" && activity !== root.primaryActivity;
    })
    readonly property var actionActivities: queuedActivities.filter(function(activity) {
        return activity.hasQueueAction;
    }).sort(root.sortByPriorityThenRegistry)
    readonly property var openableActivities: queuedActivities.filter(function(activity) {
        return !activity.hasQueueAction;
    }).sort(root.sortByPriorityThenRegistry)
    readonly property int openableVisibleLimit: Math.max(0, maxVisibleChips - actionActivities.length)
    readonly property var visibleOpenableActivities: openableActivities.slice(0, openableVisibleLimit)
    readonly property var visibleActivities: actionActivities.concat(visibleOpenableActivities)
    readonly property var overflowActivities: openableActivities.slice(openableVisibleLimit)
    readonly property int visibleChipCount: visibleActivities.length + (overflowActivities.length > 0 ? 1 : 0)
    readonly property var overflowTarget: overflowActivities.length > 0 ? overflowActivities[Math.min(overflowCursor, overflowActivities.length - 1)] : null

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

    implicitWidth: visibleChipCount > 0 ? visibleChipCount * 30 + (visibleChipCount - 1) * spacing : 0
    visible: visibleChipCount > 0 || implicitWidth > 0.5
    spacing: 6
    clip: true
    onOverflowActivitiesChanged: {
        if (overflowCursor >= overflowActivities.length)
            overflowCursor = 0;

    }

    Repeater {
        model: root.visibleActivities

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

    IslandQueueChip {
        shown: root.overflowActivities.length > 0
        activity: null
        iconName: "more_horiz"
        badgeCount: root.overflowActivities.length
        onClicked: {
            if (root.overflowTarget && root.promoteCallback) {
                root.promoteCallback(root.overflowTarget);
                root.overflowCursor = root.overflowActivities.length > 0 ? (root.overflowCursor + 1) % root.overflowActivities.length : 0;
            }
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Appearance.animation.elementMoveSmall.type
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

    }

}
