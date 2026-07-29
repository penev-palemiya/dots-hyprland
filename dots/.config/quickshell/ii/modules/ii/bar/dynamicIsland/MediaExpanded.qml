import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Mpris

ColumnLayout {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string artUrl: MprisController.activeTrack?.artUrl ?? ""
    readonly property real progress: (activePlayer?.length > 0) ? (activePlayer.position / activePlayer.length) : 0

    anchors.fill: parent
    spacing: 10

    // `position` doesn't update on its own — nudge it while playing so the
    // progress bar and time text stay live (same pattern as MediaPrimary.qml).
    Timer {
        running: root.activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        // Real album art instead of a generic play/pause icon — the pill
        // above already shows that same icon, so repeating it here was
        // pure duplication. Falls back to the icon only when there's no
        // art to show (no player, or a player that doesn't report any).
        Item {
            implicitWidth: Appearance.font.pixelSize.title * 2
            implicitHeight: Appearance.font.pixelSize.title * 2

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colors.colSecondaryContainer
                visible: root.artUrl.length === 0
            }
            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                visible: root.artUrl.length === 0
                text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.title
                color: Appearance.m3colors.m3onSecondaryContainer
            }
            StyledImage {
                id: artImage
                anchors.fill: parent
                visible: root.artUrl.length > 0
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: artImage.width
                        height: artImage.height
                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                        }
                    }
                }
            }
        }

        // Artist as a small grey "eyebrow" above the (bolder, bigger)
        // title — swapped from the previous title-then-artist order.
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.activePlayer?.trackArtist ?? ""
            }
            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                text: root.cleanedTitle
            }
        }
    }

    Rectangle {
        id: progressTrack
        Layout.fillWidth: true
        implicitHeight: 6
        radius: height / 2
        color: Appearance.colors.colSecondaryContainer

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.progress))
            height: parent.height
            radius: height / 2
            color: Appearance.colors.colPrimary

            Behavior on width {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: StringUtils.friendlyTimeForSeconds(root.activePlayer?.position ?? 0)
        }
        Item {
            Layout.fillWidth: true
        }
        StyledText {
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: StringUtils.friendlyTimeForSeconds(root.activePlayer?.length ?? 0)
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 16

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: !!root.activePlayer
            buttonRadius: Appearance.rounding.full
            implicitWidth: 32
            implicitHeight: 32
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_previous"
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            onClicked: root.activePlayer.previous()
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: !!root.activePlayer
            buttonRadius: Appearance.rounding.full
            implicitWidth: 40
            implicitHeight: 40
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: root.activePlayer?.isPlaying ? "pause" : "play_arrow"
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnPrimary
            }
            onClicked: root.activePlayer.togglePlaying()
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: !!root.activePlayer
            buttonRadius: Appearance.rounding.full
            implicitWidth: 32
            implicitHeight: 32
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "skip_next"
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            onClicked: root.activePlayer.next()
        }
    }
}
