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
    readonly property string trackKey: `${MprisController.activeTrack?.title ?? ""}:${MprisController.activeTrack?.artist ?? ""}:${Math.round(durationSeconds)}`
    readonly property bool playing: MprisController.activePlayer?.isPlaying ?? false
    readonly property real durationSeconds: normalizeSeconds(MprisController.activePlayer?.length ?? 0)
    readonly property real mprisPositionSeconds: normalizeSeconds(MprisController.activePlayer?.position ?? 0)
    readonly property bool mprisPositionLooksEnded: durationSeconds > 0 && mprisPositionSeconds >= durationSeconds - 2
    readonly property bool mprisPositionTrusted: durationSeconds <= 0 || !mprisPositionLooksEnded
    readonly property bool timelineAvailable: durationSeconds > 0 && ((timelineInitialized && timelineTrackKey === trackKey) || positionIsTrusted(mprisPositionSeconds, durationSeconds))
    readonly property real displayPositionSeconds: boundedPositionSeconds()
    readonly property real progress: timelineAvailable && durationSeconds > 0 ? clamp(displayPositionSeconds / durationSeconds, 0, 1) : 0
    property double timelineNow: Date.now()
    property bool timelineInitialized: false
    property string timelineTrackKey: ""
    property real timelinePosition: 0
    property double timelineUpdatedAt: 0
    property string playerctlTrackUrl: ""
    property string browserMprisArtUrl: ""
    readonly property string sourceUrl: playerctlTrackUrl.length > 0 ? playerctlTrackUrl : trackUrl
    readonly property string sourceDomain: StringUtils.getDomain(sourceUrl) ?? ""
    readonly property string faviconUrl: sourceDomain.length > 0 ? `https://www.google.com/s2/favicons?domain=${sourceDomain}&sz=32` : ""
    readonly property string faviconFilePath: sourceDomain.length > 0 ? `${Directories.favicons}/${sourceDomain.replace(/[^A-Za-z0-9._-]/g, "_")}.png` : ""
    property string sourceFaviconImageUrl: ""
    readonly property string fallbackArtUrl: youtubeThumbnailUrl(sourceUrl)
    readonly property string artUrl: mprisArtUrl.length > 0 ? mprisArtUrl : (fallbackArtUrl.length > 0 ? fallbackArtUrl : browserMprisArtUrl)
    readonly property string artFilePath: artUrl.length > 0 ? `${Directories.coverArt}/${Qt.md5(artUrl)}` : ""
    readonly property bool directFileArt: artUrl.startsWith("file://") || artUrl.startsWith("/")
    readonly property bool shouldDownload: artUrl.length > 0 && !directFileArt
    readonly property string directArtUrl: artUrl.startsWith("/") ? Qt.resolvedUrl(artUrl) : artUrl
    readonly property string displayedArtUrl: directFileArt ? directArtUrl : (downloaded ? Qt.resolvedUrl(artFilePath) : "")
    readonly property bool hasArt: displayedArtUrl.length > 0
    property bool downloaded: false

    onMprisPositionSecondsChanged: root.updateTimelineFromMpris()
    onDurationSecondsChanged: root.updateTimelineFromMpris()
    onPlayingChanged: root.updateTimelineFromMpris()
    onArtFilePathChanged: root.refresh()
    onMprisArtUrlChanged: root.refreshPlayerctlTrackUrl()
    onTrackUrlChanged: root.refreshPlayerctlTrackUrl()
    onTrackKeyChanged: {
        if (timelineTrackKey !== trackKey)
            timelineInitialized = false;
        root.refreshPlayerctlTrackUrl();
        root.refreshBrowserMprisArt();
    }
    onPlayerctlTrackUrlChanged: root.refresh()
    onSourceDomainChanged: root.refreshFavicon()
    Component.onCompleted: {
        root.refreshPlayerctlTrackUrl();
        root.refresh();
        root.refreshFavicon();
        root.refreshBrowserMprisArt();
    }

    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: root.refreshPlayerctlTrackUrl()
    }

    Timer {
        interval: Config.options.resources.updateInterval
        running: root.playing
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.timelineNow = Date.now();
            if (MprisController.activePlayer)
                MprisController.activePlayer.positionChanged();
            root.updateTimelineFromMpris();
        }
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

    function normalizeSeconds(value) {
        const n = Number(value ?? 0);
        if (!isFinite(n) || n <= 0)
            return 0;
        return n > 100000 ? n / 1000000 : n;
    }

    function clamp(value, min, max) {
        return Math.max(min, Math.min(max, value));
    }

    function projectedTimelinePosition(nowMs) {
        if (!timelineInitialized)
            return 0;
        const elapsed = playing ? Math.max(0, (nowMs - timelineUpdatedAt) / 1000) : 0;
        return durationSeconds > 0 ? clamp(timelinePosition + elapsed, 0, durationSeconds) : Math.max(0, timelinePosition + elapsed);
    }

    function positionIsTrusted(position, duration) {
        if (duration <= 0)
            return position >= 0;
        return position > 0 && position < duration - 2;
    }

    function boundedPositionSeconds() {
        if (durationSeconds <= 0)
            return Math.max(0, mprisPositionSeconds);
        if (timelineInitialized && timelineTrackKey === trackKey)
            return projectedTimelinePosition(timelineNow);
        if (positionIsTrusted(mprisPositionSeconds, durationSeconds))
            return clamp(mprisPositionSeconds, 0, durationSeconds);
        return 0;
    }

    function acceptTimelinePosition(position, timestamp) {
        timelineTrackKey = trackKey;
        timelinePosition = durationSeconds > 0 ? clamp(position, 0, durationSeconds) : Math.max(0, position);
        timelineUpdatedAt = timestamp;
        timelineInitialized = true;
    }

    function updateTimelineFromMpris() {
        timelineNow = Date.now();
        const position = mprisPositionSeconds;
        const duration = durationSeconds;
        if (trackKey.length === 0 || duration <= 0 || !positionIsTrusted(position, duration))
            return;
        acceptTimelinePosition(position, timelineNow);
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
        playerctlUrlLoader.running = true;
    }

    function refreshBrowserMprisArt() {
        const dbusName = String(MprisController.activePlayer?.dbusName ?? "").toLowerCase();
        const desktopEntry = String(MprisController.activePlayer?.desktopEntry ?? "").toLowerCase();
        if (mprisArtUrl.length > 0 || fallbackArtUrl.length > 0 || !(dbusName.includes("firefox") || desktopEntry.includes("firefox"))) {
            browserMprisArtUrl = "";
            return;
        }
        browserMprisArtLoader.running = true;
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
        id: browserMprisArtLoader

        command: ["bash", "-c", `
            dir='${StringUtils.shellSingleQuoteEscape(FileUtils.trimFileProtocol(Directories.home))}/.config/mozilla/firefox/firefox-mpris'
            find "$dir" -maxdepth 1 -type f -name '*.png' -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                root.browserMprisArtUrl = path.length > 0 ? Qt.resolvedUrl(path) : "";
            }
        }
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
