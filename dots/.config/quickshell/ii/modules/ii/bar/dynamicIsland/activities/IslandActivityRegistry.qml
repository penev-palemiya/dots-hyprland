import QtQuick
import ".."
import qs.modules.common
import qs.modules.common.functions
import qs.services

Item {
    id: root

    // Add new descriptors here and include their ids in this array. Keep
    // entry-specific service logic in the descriptor; keep surface/layout
    // behavior in DynamicIsland/IslandPrimary/IslandQueue.
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

    IslandActivityDescriptor {
        id: mediaActivity

        activityId: "media"
        available: true
        leadingKind: MediaArt.hasArt ? "avatar" : "icon"
        leadingIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        leadingImage: MediaArt.displayedArtUrl
        metadataText: MprisController.activePlayer?.trackArtist ?? ""
        primaryText: StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")
        queueIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        queuePriority: 10
        hasSecondaryPressAction: true
        expandedContent: mediaExpandedContent
        flashKey: MprisController.activePlayer?.trackTitle ?? ""
        secondaryPressAction: function(event) {
            if (!MprisController.activePlayer)
                return;
            if (event.button === Qt.MiddleButton)
                MprisController.activePlayer.togglePlaying();
            else if (event.button === Qt.BackButton)
                MprisController.activePlayer.previous();
            else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton)
                MprisController.activePlayer.next();
        }
    }

    IslandActivityDescriptor {
        id: capsLockNotification

        readonly property bool isOn: HyprlandXkb.capsLockOn

        activityId: "capsLock"
        kind: "notification"
        leadingIcon: isOn ? "keyboard_capslock" : "keyboard"
        leadingIconColor: isOn ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colSubtext
        metadataText: Translation.tr("Keyboard")
        primaryText: isOn ? Translation.tr("Caps Lock activated") : Translation.tr("Caps Lock deactivated")
        queueIcon: "keyboard_capslock"
        primaryDuration: 3000
        flashKey: HyprlandXkb.capsLockOn

        onFlashKeyChanged: capsLockNotification.available = true
    }

    IslandActivityDescriptor {
        id: micActivity

        readonly property bool muted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false

        activityId: "mic"
        available: muted
        leadingIcon: muted ? "mic_off" : "mic"
        leadingIconColor: muted ? Appearance.colors.colError : Appearance.m3colors.m3onSecondaryContainer
        metadataText: Translation.tr("Microphone")
        primaryText: muted ? Translation.tr("Microphone muted") : Translation.tr("Microphone unmuted")
        actionIcon: muted ? "mic" : "mic_off"
        queueIcon: "mic_off"
        queuePriority: 90
        hasQueueAction: true
        primaryDuration: 2000
        flashKey: muted
        primaryAction: function() {
            Audio.toggleMicMute();
        }
        queueAction: function() {
            Audio.toggleMicMute();
        }
    }

    IslandActivityDescriptor {
        id: notificationActivity

        readonly property var pending: Notifications.list
        readonly property var newest: pending.length > 0 ? pending[pending.length - 1] : null

        activityId: "notifications"
        available: pending.length > 0
        leadingKind: "avatar"
        leadingIcon: "person"
        leadingImage: newest?.image ?? ""
        leadingImageNotificationId: newest?.notificationId ?? -1
        appIcon: newest?.appIcon ?? ""
        metadataText: (newest?.body ?? "").length > 0 ? (newest?.summary || newest?.appName || Translation.tr("Notification")) : (newest?.appName || Translation.tr("Notification"))
        primaryText: newest?.body || newest?.summary || ""
        primaryMarquee: true
        actionIcon: (newest?.actions.length ?? 0) > 0 ? "open_in_new" : ""
        queueIcon: "notifications"
        queuePriority: 80
        queueBadgeCount: pending.length
        expandedContent: notificationExpandedContent
        flashKey: newest?.notificationId ?? -1
        primaryAction: function() {
            if ((newest?.actions.length ?? 0) > 0)
                Notifications.attemptInvokeAction(newest.notificationId, newest.actions[0].identifier);
        }
    }
}
