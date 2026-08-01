import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell.Services.Mpris

ColumnLayout {
    id: root

    readonly property MprisPlayer activePlayer: MprisController.activePlayer

    // `trackArtUrl` is whatever the player put in the MPRIS metadata map,
    // completely unvalidated — plenty of real players hand back a bare
    // scheme-less path instead of a proper `file://`/`http(s)://` URI. QML's
    // `Image` resolves a scheme-less string as relative to *this component's
    // own file*, not as an absolute filesystem path, and fails silently. So,
    // same as PlayerControl.qml: treat `artUrl` only as a `curl` target,
    // cache the download locally, and only ever point the image at that
    // local, definitely-resolvable file.
    readonly property string artUrl: MprisController.activeTrack?.artUrl ?? ""
    property string artFilePath: root.artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(root.artUrl)}` : ""
    property bool downloaded: false
    readonly property string displayedArtUrl: root.downloaded ? Qt.resolvedUrl(root.artFilePath) : ""
    readonly property bool hasArt: root.displayedArtUrl.length > 0

    readonly property bool playing: activePlayer?.isPlaying ?? false
    readonly property real progress: (activePlayer?.length > 0) ? (activePlayer.position / activePlayer.length) : 0

    anchors.fill: parent
    spacing: 12

    onArtFilePathChanged: {
        if (root.artUrl.length === 0) {
            root.downloaded = false;
            return;
        }
        // Binding does not work in Process (see PlayerControl.qml)
        artDownloader.targetFile = root.artUrl;
        artDownloader.artFilePath = root.artFilePath;
        root.downloaded = false;
        artDownloader.running = true;
    }

    Process {
        id: artDownloader
        property string targetFile: ""
        property string artFilePath: ""
        command: ["bash", "-c", `[ -f '${artFilePath}' ] || curl -4 -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: root.downloaded = true
    }

    Timer {
        running: root.activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Item {
            id: preview
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 76
            implicitHeight: 76

            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colors.colSecondaryContainer
                visible: !root.hasArt
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !root.hasArt
                fill: 1
                text: root.playing ? "pause" : "music_note"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnSecondaryContainer
            }

            StyledImage {
                id: artImage
                anchors.fill: parent
                visible: root.hasArt
                source: root.displayedArtUrl
                fillMode: Image.PreserveAspectCrop
                cache: false
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Item {
                        width: artImage.width
                        height: artImage.height
                        Rectangle {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: playStateRow.implicitWidth + 14
                    implicitHeight: 28
                    radius: Appearance.rounding.full
                    color: root.playing ? Appearance.colors.colPrimary : Appearance.colors.colLayer2

                    RowLayout {
                        id: playStateRow
                        anchors.centerIn: parent
                        spacing: 5

                        MaterialSymbol {
                            text: root.playing ? "graphic_eq" : "pause"
                            fill: 1
                            iconSize: Appearance.font.pixelSize.small
                            color: root.playing ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }

                        StyledText {
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: root.playing ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                            text: root.playing ? Translation.tr("Playing") : Translation.tr("Paused")
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                id: progressTrack
                Layout.fillWidth: true
                implicitHeight: 8
                radius: height / 2
                color: Appearance.colors.colLayer2

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
                spacing: 8

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    text: StringUtils.friendlyTimeForSeconds(root.activePlayer?.position ?? 0)
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colSubtext
                    text: StringUtils.friendlyTimeForSeconds(root.activePlayer?.length ?? 0)
                }
            }
        }
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 18

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: !!root.activePlayer
            buttonRadius: Appearance.rounding.full
            implicitWidth: 36
            implicitHeight: 36
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
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
            implicitWidth: 52
            implicitHeight: 52
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.playing ? "pause" : "play_arrow"
                fill: 1
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnPrimary
            }
            onClicked: root.activePlayer.togglePlaying()
        }

        RippleButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: !!root.activePlayer
            buttonRadius: Appearance.rounding.full
            implicitWidth: 36
            implicitHeight: 36
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "skip_next"
                fill: 1
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            onClicked: root.activePlayer.next()
        }
    }
}
