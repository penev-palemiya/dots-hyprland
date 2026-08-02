import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell.Io
import Quickshell.Widgets

IconImage {
    id: root
    property string url
    property string displayText

    property real size: 32
    property string downloadUserAgent: Config.options?.networking.userAgent ?? ""
    property string faviconDownloadPath: Directories.favicons
    property string domainName: url.includes("vertexaisearch") ? displayText : (StringUtils.getDomain(url) ?? "")
    property string faviconUrl: domainName ? `https://www.google.com/s2/favicons?domain=${domainName}&sz=32` : ""
    property string fileName: domainName ? `${domainName.replace(/[^A-Za-z0-9._-]/g, "_")}.png` : ""
    property string faviconFilePath: fileName ? `${faviconDownloadPath}/${fileName}` : ""
    property string urlToLoad

    Process {
        id: faviconDownloadProcess
        running: false
        command: ["bash", "-c", `
            set -e
            mkdir -p '${StringUtils.shellSingleQuoteEscape(root.faviconDownloadPath)}'
            [ -f '${StringUtils.shellSingleQuoteEscape(root.faviconFilePath)}' ] || curl -sSL '${StringUtils.shellSingleQuoteEscape(root.faviconUrl)}' -o '${StringUtils.shellSingleQuoteEscape(root.faviconFilePath)}' -H 'User-Agent: ${StringUtils.shellSingleQuoteEscape(root.downloadUserAgent)}'
        `]
        onExited: (exitCode, exitStatus) => {
            root.urlToLoad = exitCode === 0 ? root.faviconFilePath : ""
        }
    }

    function refresh() {
        if (!root.domainName)
            return;
        root.urlToLoad = "";
        faviconDownloadProcess.running = true
    }

    Component.onCompleted: refresh()
    onFaviconFilePathChanged: refresh()

    source: Qt.resolvedUrl(root.urlToLoad)
    implicitSize: root.size

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.implicitSize
            height: root.implicitSize
            radius: Appearance.rounding.full
        }
    }
}
