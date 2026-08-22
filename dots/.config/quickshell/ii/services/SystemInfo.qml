pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/**
 * Provides some system info: distro, username.
 */
Singleton {
    id: root
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "linux-symbolic"
    property string username: "user"
    property string homeUrl: ""
    property string documentationUrl: ""
    property string supportUrl: ""
    property string bugReportUrl: ""
    property string privacyPolicyUrl: ""
    property string logo: ""
    property string desktopEnvironment: ""
    property string windowingSystem: ""

    // Static/read-mostly information used by System → System Info.
    property string hostname: ""
    property string deviceModel: ""
    property string deviceVendor: ""
    property string distroVersion: ""
    property string kernel: ""
    property string architecture: ""
    property string cpuModel: ""
    property real memoryTotalBytes: ResourceUsage.memoryTotal * 1024
    property list<string> gpuNames: GpuUsage.gpuNames
    property real uptimeSeconds: 0
    property string hyprlandVersion: ""
    property string quickshellVersion: ""

    function formatUptime() {
        const totalMinutes = Math.max(0, Math.floor(root.uptimeSeconds / 60));
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        const parts = [];
        if (days > 0) parts.push(`${days} ${days === 1 ? Translation.tr("day") : Translation.tr("days")}`);
        if (hours > 0) parts.push(`${hours} ${hours === 1 ? Translation.tr("hour") : Translation.tr("hours")}`);
        if (minutes > 0 || parts.length === 0) parts.push(`${minutes} ${minutes === 1 ? Translation.tr("minute") : Translation.tr("minutes")}`);
        return parts.join(" ");
    }

    Timer {
        triggeredOnStart: true
        interval: 1
        running: true
        repeat: false
        onTriggered: {
            getUsername.running = true
            fileOsRelease.reload()
            const textOsRelease = fileOsRelease.text()

            // Extract the friendly name (PRETTY_NAME field, fallback to NAME)
            const prettyNameMatch = textOsRelease.match(/^PRETTY_NAME="(.+?)"/m)
            const nameMatch = textOsRelease.match(/^NAME="(.+?)"/m)
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown")

            const versionMatch = textOsRelease.match(/^(?:VERSION_ID|BUILD_ID)="?([^"\n]+)"?/m)
            distroVersion = versionMatch ? versionMatch[1] : ""

            // Extract the ID
            const idMatch = textOsRelease.match(/^ID="?(.+?)"?$/m)
            distroId = idMatch ? idMatch[1] : "unknown"

            // Extract additional URLs and logo
            const homeUrlMatch = textOsRelease.match(/^HOME_URL="(.+?)"/m)
            homeUrl = homeUrlMatch ? homeUrlMatch[1] : ""
            const documentationUrlMatch = textOsRelease.match(/^DOCUMENTATION_URL="(.+?)"/m)
            documentationUrl = documentationUrlMatch ? documentationUrlMatch[1] : ""
            const supportUrlMatch = textOsRelease.match(/^SUPPORT_URL="(.+?)"/m)
            supportUrl = supportUrlMatch ? supportUrlMatch[1] : ""
            const bugReportUrlMatch = textOsRelease.match(/^BUG_REPORT_URL="(.+?)"/m)
            bugReportUrl = bugReportUrlMatch ? bugReportUrlMatch[1] : ""
            const privacyPolicyUrlMatch = textOsRelease.match(/^PRIVACY_POLICY_URL="(.+?)"/m)
            privacyPolicyUrl = privacyPolicyUrlMatch ? privacyPolicyUrlMatch[1] : ""
            const logoFieldMatch = textOsRelease.match(/^LOGO="?(.+?)"?$/m)
            logo = logoFieldMatch ? logoFieldMatch[1] : ""

            // Update the distroIcon property based on distroId
            switch (distroId) {
                case "artix":
                case "arch": distroIcon = "arch-symbolic"; break;
                case "manjaro": distroIcon = "manjaro-symbolic"; break;
                case "endeavouros": distroIcon = "endeavouros-symbolic"; break;
                case "cachyos": distroIcon = "cachyos-symbolic"; break;
                case "nixos": distroIcon = "nixos-symbolic"; break;
                case "fedora": distroIcon = "fedora-symbolic"; break;
                case "linuxmint":
                case "ubuntu":
                case "zorin":
                case "popos": distroIcon = "ubuntu-symbolic"; break;
                case "debian":
                case "raspbian":
                case "kali": distroIcon = "debian-symbolic"; break;
                case "funtoo":
                case "gentoo": distroIcon = "gentoo-symbolic"; break;
                default: distroIcon = "linux-symbolic"; break;
            }
            if (textOsRelease.toLowerCase().includes("nyarch")) {
                distroIcon = "nyarch-symbolic"
            }

            if (logo.trim().length === 0) {
                logo = distroIcon
            }

        }
    }

    Process {
        id: getUsername
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => {
                root.username = data.trim()
            }
        }
    }

    Process {
        id: getDesktopEnvironment
        running: true
        command: ["bash", "-c", "echo $XDG_CURRENT_DESKTOP,$WAYLAND_DISPLAY"]
        stdout: StdioCollector {
            id: deCollector
            onStreamFinished: {
                const [desktop, wayland] = deCollector.text.split(",")
                root.desktopEnvironment = desktop.trim()
                root.windowingSystem = wayland.trim().length > 0 ? "Wayland" : "X11" // Are there others? 🤔
            }
        }
    }

    Process {
        id: getHostname
        command: ["hostname"]
        running: true
        stdout: SplitParser { onRead: data => root.hostname = data.trim() }
    }

    Process {
        id: getKernel
        command: ["uname", "-srmo"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const fields = data.trim().split(/\s+/);
                root.kernel = fields.slice(0, 2).join(" ");
                root.architecture = fields[2] || "";
            }
        }
    }

    Process {
        id: getHyprlandVersion
        command: ["hyprctl", "version"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^Hyprland\s+(\S+)/);
                if (match) root.hyprlandVersion = match[1];
            }
        }
    }

    Process {
        id: getQuickshellVersion
        command: ["qs", "--version"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/Quickshell\s+([^\s(]+)/i);
                if (match) root.quickshellVersion = match[1];
            }
        }
    }

    FileView {
        id: cpuInfo
        path: "/proc/cpuinfo"
        onLoaded: {
            const match = cpuInfo.text().match(/^model name\s*:\s*(.+)$/m);
            if (match) root.cpuModel = match[1].trim();
        }
    }

    FileView {
        id: uptimeInfo
        path: "/proc/uptime"
        onLoaded: root.uptimeSeconds = Number(uptimeInfo.text().trim().split(/\s+/)[0] || 0)
    }

    FileView {
        id: productName
        path: "/sys/devices/virtual/dmi/id/product_name"
        onLoaded: root.deviceModel = productName.text().trim()
    }

    FileView {
        id: productVendor
        path: "/sys/devices/virtual/dmi/id/sys_vendor"
        onLoaded: root.deviceVendor = productVendor.text().trim()
    }

    FileView {
        id: fileOsRelease
        path: "/etc/os-release"
    }
}
