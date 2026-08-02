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
    readonly property var queuedActivities: activities.filter(function(activity) {
        return activity.available && activity.kind === "activity" && activity !== root.primaryActivity;
    })
    readonly property var sortedActivities: queuedActivities.slice().sort(function(a, b) {
        return (b.queuePriority || 0) - (a.queuePriority || 0);
    })
    readonly property var visibleActivities: sortedActivities.slice(0, maxVisibleChips)
    readonly property var overflowActivities: sortedActivities.slice(maxVisibleChips)
    readonly property int visibleChipCount: visibleActivities.length + (overflowActivities.length > 0 ? 1 : 0)

    implicitWidth: visibleChipCount > 0 ? visibleChipCount * 30 + (visibleChipCount - 1) * spacing : 0
    visible: visibleChipCount > 0 || implicitWidth > 0.5
    spacing: 6
    clip: true

    Repeater {
        model: root.activities

        delegate: IslandQueueChip {
            required property QtObject modelData

            activity: modelData
            shown: root.visibleActivities.includes(modelData)
            onClicked: {
                if (modelData.queueAction)
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
            if (root.overflowActivities.length > 0 && root.promoteCallback)
                root.promoteCallback(root.overflowActivities[0]);

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
