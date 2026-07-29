import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

ColumnLayout {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property real progress: (activePlayer?.length > 0) ? (activePlayer.position / activePlayer.length) : 0

    anchors.fill: parent
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Item {
            implicitWidth: Appearance.font.pixelSize.title * 2
            implicitHeight: Appearance.font.pixelSize.title * 2

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.full
                color: Appearance.colors.colSecondaryContainer
            }

            MaterialSymbol {
                anchors.centerIn: parent
                fill: 1
                text: root.activePlayer?.isPlaying ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.title
                color: Appearance.m3colors.m3onSecondaryContainer
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.weight: Font.Bold
                color: Appearance.colors.colOnLayer1
                text: root.cleanedTitle
            }
            StyledText {
                Layout.fillWidth: true
                visible: text.length > 0
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: root.activePlayer?.trackArtist ?? ""
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
        Layout.alignment: Qt.AlignHCenter
        spacing: 16

        RippleButton {
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
