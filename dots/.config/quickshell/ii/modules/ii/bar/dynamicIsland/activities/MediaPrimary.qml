import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import Quickshell.Services.Mpris

IslandActivityRow {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")

    icon: activePlayer?.isPlaying ? "pause" : "music_note"

    Timer {
        running: root.activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    // Middle/back/forward/right-click control playback directly. Left-click
    // is intentionally not handled here — it falls through to DynamicIsland's
    // own click-to-expand handling on the primary row.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                root.activePlayer.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                root.activePlayer.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                root.activePlayer.next();
            }
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        elide: Text.ElideRight
        color: Appearance.colors.colOnLayer1
        text: `${root.cleanedTitle}${root.activePlayer?.trackArtist ? ' • ' + root.activePlayer.trackArtist : ''}`
    }
}
