pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string artUrl: MprisController.activeTrack?.artUrl ?? ""
    readonly property string artFilePath: artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(artUrl)}` : ""
    readonly property string displayedArtUrl: downloaded ? Qt.resolvedUrl(artFilePath) : ""
    readonly property bool hasArt: displayedArtUrl.length > 0
    property bool downloaded: false

    onArtFilePathChanged: root.refresh()
    Component.onCompleted: root.refresh()

    function refresh() {
        if (artUrl.length === 0 || artFilePath.length === 0) {
            downloaded = false;
            return;
        }
        artLoader.targetUrl = artUrl;
        artLoader.targetPath = artFilePath;
        downloaded = false;
        artLoader.running = true;
    }

    Process {
        id: artLoader

        property string targetUrl: ""
        property string targetPath: ""

        command: ["bash", "-c", `
            set -e
            url='${StringUtils.shellSingleQuoteEscape(targetUrl)}'
            out='${StringUtils.shellSingleQuoteEscape(targetPath)}'
            mkdir -p "$(dirname "$out")"
            if [ -f "$out" ]; then
                exit 0
            fi
            case "$url" in
                file://*) cp "\${url#file://}" "$out" ;;
                /*) cp "$url" "$out" ;;
                *) curl -4 -sSL "$url" -o "$out" ;;
            esac
        `]
        onExited: (exitCode, exitStatus) => root.downloaded = exitCode === 0
    }
}
