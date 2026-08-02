import QtQuick
import qs.modules.common
import qs.modules.common.functions
import qs.services

Item {
    id: root

    readonly property var activities: [mediaActivity, capsLockNotification, micActivity, notificationActivity]
    readonly property var fallbackActivity: mediaActivity

    Component {
        id: mediaExpandedContent

        MediaExpanded {}
    }
    Component {
        id: notificationExpandedContent

        NotificationExpanded {}
    }

    QtObject {
        id: mediaActivity

        readonly property string activityId: "media"
        readonly property string kind: "activity"
        readonly property bool available: true
        readonly property string leadingKind: "icon"
        readonly property string leadingIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        readonly property color leadingIconColor: Appearance.m3colors.m3onSecondaryContainer
        readonly property string metadataText: MprisController.activePlayer?.trackArtist ?? ""
        readonly property string primaryText: StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")
        readonly property bool primaryMarquee: false
        readonly property string actionIcon: ""
        readonly property var primaryAction: null
        function secondaryPressAction(event) {
            if (!MprisController.activePlayer)
                return;
            if (event.button === Qt.MiddleButton)
                MprisController.activePlayer.togglePlaying();
            else if (event.button === Qt.BackButton)
                MprisController.activePlayer.previous();
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton)
                MprisController.activePlayer.next();
        }
        readonly property string queueIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        readonly property int queuePriority: 10
        readonly property var expandedContent: mediaExpandedContent
        readonly property int primaryDuration: 0
        readonly property var flashKey: MprisController.activePlayer?.trackTitle ?? ""
    }

    QtObject {
        id: capsLockNotification

        readonly property string activityId: "capsLock"
        readonly property string kind: "notification"
        property bool available: false
        readonly property bool isOn: HyprlandXkb.capsLockOn
        readonly property string leadingKind: "icon"
        readonly property string leadingIcon: isOn ? "keyboard_capslock" : "keyboard"
        readonly property color leadingIconColor: isOn ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
        readonly property string metadataText: Translation.tr("Keyboard")
        readonly property string primaryText: isOn ? Translation.tr("Caps Lock activated") : Translation.tr("Caps Lock deactivated")
        readonly property bool primaryMarquee: false
        readonly property string actionIcon: ""
        readonly property var primaryAction: null
        readonly property var secondaryPressAction: null
        readonly property string queueIcon: "keyboard_capslock"
        readonly property int queuePriority: 0
        readonly property var expandedContent: null
        readonly property int primaryDuration: 3000
        readonly property var flashKey: HyprlandXkb.capsLockOn

        onFlashKeyChanged: capsLockNotification.available = true
    }

    QtObject {
        id: micActivity

        readonly property string activityId: "mic"
        readonly property string kind: "activity"
        readonly property bool muted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false
        readonly property bool available: muted
        readonly property string leadingKind: "icon"
        readonly property string leadingIcon: muted ? "mic_off" : "mic"
        readonly property color leadingIconColor: muted ? Appearance.colors.colError : Appearance.m3colors.m3onSecondaryContainer
        readonly property string metadataText: Translation.tr("Microphone")
        readonly property string primaryText: muted ? Translation.tr("Microphone muted") : Translation.tr("Microphone unmuted")
        readonly property bool primaryMarquee: false
        readonly property string actionIcon: muted ? "mic" : "mic_off"
        readonly property var secondaryPressAction: null
        readonly property string queueIcon: "mic_off"
        readonly property int queuePriority: 90
        readonly property var expandedContent: null
        readonly property int primaryDuration: 2000
        readonly property var flashKey: muted

        function primaryAction() {
            Audio.toggleMicMute();
        }

        function queueAction() {
            Audio.toggleMicMute();
        }
    }

    QtObject {
        id: notificationActivity

        readonly property string activityId: "notifications"
        readonly property string kind: "activity"
        readonly property var pending: Notifications.list
        readonly property bool available: pending.length > 0
        readonly property var newest: pending.length > 0 ? pending[pending.length - 1] : null
        readonly property string leadingKind: "avatar"
        readonly property string leadingIcon: "person"
        readonly property color leadingIconColor: Appearance.m3colors.m3onSecondaryContainer
        readonly property string leadingImage: newest?.image ?? ""
        readonly property string appIcon: newest?.appIcon ?? ""
        readonly property string metadataText: (newest?.body ?? "").length > 0 ? (newest?.summary || newest?.appName || Translation.tr("Notification")) : (newest?.appName || Translation.tr("Notification"))
        readonly property string primaryText: newest?.body || newest?.summary || ""
        readonly property bool primaryMarquee: true
        readonly property string actionIcon: (newest?.actions.length ?? 0) > 0 ? "open_in_new" : ""

        function primaryAction() {
            if ((newest?.actions.length ?? 0) > 0)
                Notifications.attemptInvokeAction(newest.notificationId, newest.actions[0].identifier);
        }

        readonly property var secondaryPressAction: null
        readonly property string queueIcon: "notifications"
        readonly property int queuePriority: 80
        readonly property int queueBadgeCount: pending.length
        readonly property var expandedContent: notificationExpandedContent
        readonly property int primaryDuration: 0
        readonly property var flashKey: newest?.notificationId ?? -1
    }
}
