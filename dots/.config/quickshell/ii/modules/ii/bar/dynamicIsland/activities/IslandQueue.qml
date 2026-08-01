import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var activities: []
    property int maxVisibleChips: 3
    property var promoteCallback

    readonly property var sortedActivities: activities.slice().sort(function(a, b) {
        return (b.queuePriority || 0) - (a.queuePriority || 0);
    })
    readonly property var visibleActivities: sortedActivities.slice(0, maxVisibleChips)
    readonly property var overflowActivities: sortedActivities.slice(maxVisibleChips)

    spacing: 6

    Repeater {
        model: root.visibleActivities
        delegate: IslandQueueChip {
            required property QtObject modelData
            activity: modelData
            onClicked: {
                if (modelData.queueAction)
                    modelData.queueAction();
                else if (root.promoteCallback)
                    root.promoteCallback(modelData);
            }
        }
    }

    IslandQueueChip {
        visible: root.overflowActivities.length > 0
        activity: null
        iconName: "more_horiz"
        badgeCount: root.overflowActivities.length
        onClicked: {
            if (root.overflowActivities.length > 0 && root.promoteCallback)
                root.promoteCallback(root.overflowActivities[0]);
        }
    }
}
