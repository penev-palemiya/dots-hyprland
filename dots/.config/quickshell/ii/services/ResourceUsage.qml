pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Polled resource usage service with RAM, Swap, and CPU usage.
 *
 * RAM/Swap and CPU are parsed from each FileView's onLoaded, not from
 * reload() followed by an immediate text() read. FileView.reload() is
 * asynchronous: text() called right after reload() returns whatever was
 * cached *before* that reload - the previous cycle's content, not the one
 * just requested. That made every sample exactly one poll interval stale,
 * and meant the very first (preloaded) sample at startup was skipped
 * entirely in favor of empty/placeholder text. Parsing in onLoaded fixes
 * both: values update exactly when their data actually arrives, including
 * the initial preload.
 */
Singleton {
    id: root
    property real memoryTotal: 0
    property real memoryAvailable: 0
    property real memoryUsed: memoryTotal - memoryAvailable
    property real memoryUsedPercentage: memoryTotal > 0 ? memoryUsed / memoryTotal : 0
    // True once a real /proc/meminfo sample has been parsed. Before that,
    // the properties above are 0/0%, not a placeholder that looks like a
    // real (and alarming) 100%-used reading.
    property bool memoryValid: false
    property real swapTotal: 0
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    // True once two consecutive /proc/stat samples have produced a real
    // delta. Before that, cpuUsage is 0 but that 0 is not a measurement.
    property bool cpuUsageValid: false
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

    // Committed once per real CPU sample (see fileStat.onLoaded), which keeps
    // all three series aligned on one shared index without a separate
    // rendezvous between the meminfo and stat reads.
    function updateHistories() {
        cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
        if (cpuUsageHistory.length > historyLength) cpuUsageHistory.shift()

        memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
        if (memoryUsageHistory.length > historyLength) memoryUsageHistory.shift()

        swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
        if (swapUsageHistory.length > historyLength) swapUsageHistory.shift()
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

    // A vanished/unreadable hwmon path must not keep showing the last
    // reading as if it were current, and should be retried without a tight
    // loop: next time detailed polling starts (e.g. the popup is reopened),
    // discovery runs again in case hwmon numbering actually changed.
    function handleCpuTempUnavailable() {
        cpuTempAvailable = false;
        cpuTempProbeStarted = false;
    }

    Timer {
        id: resourceTimer
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()
            // Keep trying the resolved path at the normal cadence whenever
            // detailed polling is active, regardless of last known
            // availability - this is what lets a transient read failure on
            // the *same* path recover without waiting for the popup to be
            // closed and reopened.
            if (detailedPollingActive && fileCpuTemp.path) {
                fileCpuTemp.reload()
            }
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

    FileView {
        id: fileMeminfo
        path: "/proc/meminfo"
        onLoaded: {
            const text = fileMeminfo.text()
            root.memoryTotal = Number(text.match(/MemTotal: *(\d+)/)?.[1] ?? 0)
            // MemAvailable, not MemFree: it's the kernel's own estimate of
            // memory available for new applications without swapping, which
            // is what "RAM used" should mean for a memory-pressure readout.
            root.memoryAvailable = Number(text.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            root.swapTotal = Number(text.match(/SwapTotal: *(\d+)/)?.[1] ?? 0)
            root.swapFree = Number(text.match(/SwapFree: *(\d+)/)?.[1] ?? 0)
            root.memoryValid = true
        }
        // /proc/meminfo is a kernel-generated file that is always present
        // and always readable, so a real failure here isn't a case worth
        // building recovery logic for - on a transient failure, onLoaded
        // just won't fire and the last known-good values remain.
    }

    FileView {
        id: fileStat
        path: "/proc/stat"
        onLoaded: {
            const text = fileStat.text()
            const cpuLine = text.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                // idle + iowait is the conventional "not busy" baseline
                // (matches top/htop/mpstat); iowait alone is still CPU time
                // by kernel accounting, but the CPU isn't doing work during
                // it, so counting it as "busy" overstates usage under I/O.
                const idle = stats[3] + stats[4]

                if (root.previousCpuStats) {
                    const totalDiff = total - root.previousCpuStats.total
                    const idleDiff = idle - root.previousCpuStats.idle
                    if (totalDiff > 0) {
                        root.cpuUsage = 1 - idleDiff / totalDiff
                        root.cpuUsageValid = true
                    }
                }
                root.previousCpuStats = { total, idle }
            }
            root.updateHistories()
        }
    }

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
                    // Assigning the same string path is a no-op in FileView
                    // (setPath() short-circuits on an unchanged path), so if
                    // discovery resolves to the same sensor as before, the
                    // periodic reload above - not this assignment - is what
                    // picks recovery back up.
                    fileCpuTemp.path = path;
                } else {
                    root.cpuTempAvailable = false;
                }
            }
        }
    }

    FileView {
        id: fileCpuTemp
        onLoaded: {
            const milliDegrees = Number(fileCpuTemp.text())
            if (milliDegrees > 0) {
                root.cpuTemp = milliDegrees / 1000
                root.cpuTempAvailable = true
            } else {
                root.handleCpuTempUnavailable()
            }
        }
        onLoadFailed: root.handleCpuTempUnavailable()
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
