import QtQuick
import qs.modules.common

QtObject {
    id: root

    // Override only what the entry actually needs. Primary/queue/overlay
    // components read this contract directly, so new activities should start
    // from this descriptor instead of defining custom primary UI.
    property string activityId: ""
    property string kind: "activity"
    property bool available: false
    property string leadingKind: "icon"
    property string leadingIcon: ""
    property color leadingIconColor: Appearance.m3colors.m3onSecondaryContainer
    property string leadingImage: ""
    property int leadingImageNotificationId: -1
    property string appIcon: ""
    property string metadataText: ""
    property string primaryText: ""
    property bool primaryMarquee: false
    property string actionIcon: ""
    property string queueIcon: leadingIcon
    property int queuePriority: 0
    property int queueBadgeCount: 0
    property bool hasSecondaryPressAction: false
    // True means the queue chip performs a direct action instead of opening
    // the activity. Action chips are sorted to the left of openable chips.
    property bool hasQueueAction: false
    property var expandedContent: null
    property int primaryDuration: 0
    property var flashKey: null
    property var primaryAction: null
    property var secondaryPressAction: null
    property var queueAction: null
}
