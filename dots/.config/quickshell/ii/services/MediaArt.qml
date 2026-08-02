pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    readonly property string mprisArtUrl: MprisController.activeTrack?.artUrl ?? ""
    readonly property string trackUrl: MprisController.activePlayer?.trackUrl ?? ""
    property string playerctlTrackUrl: ""
    readonly property string sourceUrl: trackUrl.length > 0 ? trackUrl : playerctlTrackUrl
    readonly property string sourceDomain: StringUtils.getDomain(sourceUrl) ?? ""
    readonly property string faviconUrl: sourceDomain.length > 0 ? `https://www.google.com/s2/favicons?domain=${sourceDomain}&sz=32` : ""
    readonly property string faviconFilePath: sourceDomain.length > 0 ? `${Directories.favicons}/${sourceDomain.replace(/[^A-Za-z0-9._-]/g, "_")}.ico` : ""
    property string sourceFaviconImageUrl: ""
    readonly property string fallbackArtUrl: youtubeThumbnailUrl(trackUrl.length > 0 ? trackUrl : playerctlTrackUrl)
    readonly property string artUrl: mprisArtUrl.length > 0 ? mprisArtUrl : fallbackArtUrl
    readonly property string artFilePath: artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(artUrl)}` : ""
    readonly property bool directFileArt: artUrl.startsWith("file://") || artUrl.startsWith("/")
    readonly property bool shouldDownload: artUrl.length > 0 && !directFileArt
    readonly property string directArtUrl: artUrl.startsWith("/") ? Qt.resolvedUrl(artUrl) : artUrl
    readonly property string displayedArtUrl: directFileArt ? directArtUrl : (downloaded ? Qt.resolvedUrl(artFilePath) : "")
    readonly property bool hasArt: displayedArtUrl.length > 0
    property bool downloaded: false

    onArtFilePathChanged: root.refresh()
    onMprisArtUrlChanged: root.refreshPlayerctlTrackUrl()
    onTrackUrlChanged: root.refreshPlayerctlTrackUrl()
    onPlayerctlTrackUrlChanged: root.refresh()
    onSourceDomainChanged: root.refreshFavicon()
    Component.onCompleted: {
        root.refreshPlayerctlTrackUrl();
        root.refresh();
        root.refreshFavicon();
    }

    function youtubeThumbnailUrl(url) {
        const text = String(url ?? "");
        let match = text.match(/[?&]v=([^&#]+)/);
        if (!match)
            match = text.match(/youtu\.be\/([^?&#]+)/);
        if (!match)
            match = text.match(/youtube\.com\/shorts\/([^?&#]+)/);
        return match ? `https://i.ytimg.com/vi/${match[1]}/hqdefault.jpg` : "";
    }

    function refresh() {
        if (artUrl.length === 0 || artFilePath.length === 0 || !shouldDownload) {
            downloaded = false;
            return;
        }
        artLoader.targetUrl = artUrl;
        artLoader.targetPath = artFilePath;
        downloaded = false;
        artLoader.running = true;
    }

    function refreshPlayerctlTrackUrl() {
        if (trackUrl.length === 0)
            playerctlUrlLoader.running = true;
        else
            playerctlTrackUrl = "";
    }

    function refreshFavicon() {
        if (faviconUrl.length === 0 || faviconFilePath.length === 0) {
            sourceFaviconImageUrl = "";
            return;
        }
        faviconLoader.targetUrl = faviconUrl;
        faviconLoader.targetPath = faviconFilePath;
        faviconLoader.running = true;
    }

    Process {
        id: playerctlUrlLoader

        command: ["playerctl", "metadata", "xesam:url"]
        stdout: StdioCollector {
            onStreamFinished: root.playerctlTrackUrl = text.trim()
        }
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

    Process {
        id: faviconLoader

        property string targetUrl: ""
        property string targetPath: ""

        command: ["bash", "-c", `
            set -e
            url='${StringUtils.shellSingleQuoteEscape(targetUrl)}'
            out='${StringUtils.shellSingleQuoteEscape(targetPath)}'
            mkdir -p "$(dirname "$out")"
            [ -f "$out" ] || curl -sSL "$url" -o "$out" -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(Config.options?.networking.userAgent ?? "")}'
        `]
        onExited: (exitCode, exitStatus) => root.sourceFaviconImageUrl = exitCode === 0 ? Qt.resolvedUrl(targetPath) : ""
    }
}
