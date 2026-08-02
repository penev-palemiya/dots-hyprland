import QtQuick
import Quickshell
import Quickshell.Hyprland
import ".."
import qs.modules.common
import qs.modules.common.functions
import qs.services

Item {
    id: root

    // Add new descriptors here and include their ids in this array. Keep
    // entry-specific service logic in the descriptor; keep surface/layout
    // behavior in DynamicIsland/IslandPrimary/IslandQueue.
    readonly property var activities: [mediaActivity, capsLockNotification, brightnessNotification, keyboardBacklightNotification, micActivity, notificationActivity]
    readonly property var fallbackActivity: mediaActivity

    Component {
        id: mediaExpandedContent

        MediaExpanded {}
    }
    Component {
        id: notificationExpandedContent

        NotificationExpanded {}
    }

    function mediaFallbackIcon(player) {
        const dbusName = String(player?.dbusName ?? "").toLowerCase();
        if (dbusName.includes("firefox"))
            return "firefox";
        if (dbusName.includes("chromium"))
            return "chromium";
        if (dbusName.includes("chrome"))
            return "google-chrome";
        if (dbusName.includes("spotify"))
            return "spotify";
        if (dbusName.includes("vlc"))
            return "vlc";
        if (dbusName.includes("mpv"))
            return "mpv";
        return "";
    }

    function mediaIsBrowser(player) {
        const dbusName = String(player?.dbusName ?? "").toLowerCase();
        const desktopEntry = String(player?.desktopEntry ?? "").toLowerCase();
        return dbusName.includes("firefox") || dbusName.includes("chromium") || dbusName.includes("chrome") || desktopEntry.includes("firefox") || desktopEntry.includes("chromium") || desktopEntry.includes("chrome");
    }

    IslandActivityDescriptor {
        id: mediaActivity

        readonly property var desktopEntry: DesktopEntries.byId(MprisController.activePlayer?.desktopEntry ?? "")

        activityId: "media"
        available: true
        leadingKind: MediaArt.hasArt ? "avatar" : "icon"
        leadingIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        leadingImage: MediaArt.displayedArtUrl
        appIcon: desktopEntry?.icon || root.mediaFallbackIcon(MprisController.activePlayer)
        appIconImage: root.mediaIsBrowser(MprisController.activePlayer) ? MediaArt.sourceFaviconImageUrl : ""
        appIconUrl: root.mediaIsBrowser(MprisController.activePlayer) ? MediaArt.sourceUrl : ""
        metadataText: MprisController.activePlayer?.trackArtist ?? ""
        primaryText: StringUtils.cleanMusicTitle(MprisController.activePlayer?.trackTitle) || Translation.tr("No media")
        queueIcon: MprisController.activePlayer?.isPlaying ? "pause" : "music_note"
        queueImage: MediaArt.displayedArtUrl
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
        id: brightnessNotification

        readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        readonly property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)
        readonly property bool gammaActive: Hyprsunset.gamma < 100
        readonly property real displayValue: gammaActive ? (Hyprsunset.gamma / 100) : (brightnessMonitor?.brightness ?? 0)
        readonly property int percent: Math.round(displayValue * 100)
        property int eventSerial: 0

        activityId: "brightness"
        kind: "notification"
        leadingIcon: gammaActive ? "routine" : "light_mode"
        metadataText: gammaActive ? Translation.tr("Gamma") : Translation.tr("Brightness")
        primaryText: `${percent}%`
        valueIndicatorVisible: true
        valueIndicatorValue: displayValue
        queueIcon: "light_mode"
        primaryDuration: 2000
        flashKey: eventSerial
    }

    Connections {
        target: Brightness

        function onBrightnessChanged() {
            brightnessNotification.available = true;
            brightnessNotification.eventSerial += 1;
        }
    }

    Connections {
        target: Hyprsunset

        function onGammaChangeAttempt() {
            brightnessNotification.available = true;
            brightnessNotification.eventSerial += 1;
        }
    }

    IslandActivityDescriptor {
        id: keyboardBacklightNotification

        readonly property int percent: Math.round(KeyboardBacklight.value * 100)
        property int eventSerial: 0

        activityId: "keyboardBacklight"
        kind: "notification"
        leadingIcon: "keyboard"
        metadataText: Translation.tr("Keyboard brightness")
        primaryText: `${percent}%`
        valueIndicatorVisible: true
        valueIndicatorValue: KeyboardBacklight.value
        queueIcon: "keyboard"
        primaryDuration: 2000
        flashKey: eventSerial
    }

    Connections {
        target: KeyboardBacklight

        function onBacklightChanged() {
            if (!KeyboardBacklight.available)
                return;
            keyboardBacklightNotification.available = true;
            keyboardBacklightNotification.eventSerial += 1;
        }
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
        secondaryActionIcon: newest ? "check" : ""
        queueIcon: "notifications"
        queuePriority: 80
        queueBadgeCount: pending.length
        expandedContent: notificationExpandedContent
        flashKey: newest?.notificationId ?? -1
        primaryAction: function() {
            if ((newest?.actions.length ?? 0) > 0)
                Notifications.attemptInvokeAction(newest.notificationId, newest.actions[0].identifier);
        }
        secondaryAction: function() {
            if (newest)
                Notifications.discardNotification(newest.notificationId);
        }
    }
}
