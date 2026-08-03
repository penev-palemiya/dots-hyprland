pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    id: root
	property real memoryTotal: 1
	property real memoryFree: 0
	property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
	property real swapFree: 0
	property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats
    property bool cpuTempAvailable: false
    property real cpuTemp: 0 // Celsius

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"
    property bool cpuTempProbeStarted: false
    property bool cpuMaxFreqProbeStarted: false

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    readonly property bool resourcesOverlayOpen: Persistent.states.overlay.open.includes("resources") && (GlobalStates.overlayOpen || Persistent.states.overlay.resources.pinned)
    readonly property bool detailedPollingActive: BarPopups.resourcesOpen || resourcesOverlayOpen
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function updateMemoryUsageHistory() {
        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) {
            memoryUsageHistory.shift()
        }
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) {
            swapUsageHistory.shift()
        }
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) {
            cpuUsageHistory.shift()
        }
    }
    function updateHistories() {
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
    }
    function startDetailedProbes() {
        if (!cpuTempProbeStarted) {
            cpuTempProbeStarted = true;
            findCpuTempProc.running = true;
        }
        if (!cpuMaxFreqProbeStarted) {
            cpuMaxFreqProbeStarted = true;
            findCpuMaxFreqProc.running = true;
        }
    }

	Timer {
        id: resourceTimer
		interval: 1
        running: true 
        repeat: true
		onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
            }

            // CPU temperature, once the hwmon path has been resolved
            if (detailedPollingActive && cpuTempAvailable) {
                fileCpuTemp.reload()
                const milliDegrees = Number(fileCpuTemp.text())
                if (milliDegrees > 0)
                    cpuTemp = milliDegrees / 1000
            }

            // Histories are kept unconditionally, not gated behind
            // detailedPollingActive. This timer already ticks every
            // updateInterval regardless, so appending to three bounded arrays
            // costs no extra wakeup and no extra IO — the values were just
            // parsed above either way. Gating it meant the graph in
            // ResourcesPopup started empty on every open and needed
            // historyLength * updateInterval (3 minutes by default) of the
            // popup being held open before it showed a full window of data.
            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
	}

    onDetailedPollingActiveChanged: {
        if (detailedPollingActive) {
            startDetailedProbes();
            resourceTimer.interval = 1;
            resourceTimer.restart();
        }
    }
    Component.onCompleted: {
        if (detailedPollingActive)
            startDetailedProbes();
    }

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat; path: "/proc/stat" }
    FileView { id: fileCpuTemp }

    // Resolve which hwmon temp*_input file corresponds to the CPU package/die
    // sensor. hwmon numbering isn't stable across machines, so this has to be
    // discovered at runtime rather than hardcoded.
    Process {
        id: findCpuTempProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", `
            for hwmon in /sys/class/hwmon/hwmon*; do
                name=$(cat "$hwmon/name" 2>/dev/null)
                case "$name" in
                    coretemp|k10temp|zenpower|zenpower3|cpu_thermal)
                        for label in "$hwmon"/temp*_label; do
                            [ -f "$label" ] || continue
                            case "$(cat "$label")" in
                                "Package id "*|Tctl|Tdie)
                                    echo "\${label%_label}_input"
                                    exit 0
                                    ;;
                            esac
                        done
                        if [ -f "$hwmon/temp1_input" ]; then
                            echo "$hwmon/temp1_input"
                            exit 0
                        fi
                        ;;
                esac
            done
        `]
        running: false
        stdout: StdioCollector {
            id: cpuTempPathCollector
            onStreamFinished: {
                const path = cpuTempPathCollector.text.trim();
                if (path) {
                    fileCpuTemp.path = path;
                    root.cpuTempAvailable = true;
                }
            }
        }
    }

    Process {
        id: findCpuMaxFreqProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: false
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
