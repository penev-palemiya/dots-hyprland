pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Best-effort auto-detected GPU usage service. Detects the GPU vendor via
 * lspci, then polls vendor-specific tooling/sysfs for live stats. Detection
 * and polling both fail gracefully (available/statsAvailable stay false)
 * since hwmon layout, GPU tooling, and even the presence of a discrete GPU
 * vary a lot across machines.
 */
Singleton {
    id: root

    property string vendor: "" // "nvidia" | "amd" | "intel" | ""
    property string gpuName: ""
    property bool available: false
    property bool statsAvailable: false

    property real usage: 0 // 0-1
    property real vramUsedMb: 0
    property real vramTotalMb: 0
    property real temp: 0 // Celsius

    property string amdCardHwmonPath: ""
    property string amdCardDrmPath: ""
    readonly property bool resourcesOverlayOpen: Persistent.states.overlay.open.includes("resources") && (GlobalStates.overlayOpen || Persistent.states.overlay.resources.pinned)
    readonly property bool detailedPollingActive: BarPopups.resourcesOpen || resourcesOverlayOpen
    readonly property int pollingInterval: detailedPollingActive ? (Config.options?.resources?.updateInterval ?? 3000) : Math.max(Config.options?.resources?.updateInterval ?? 3000, 10000)

    Timer {
        interval: root.pollingInterval
        running: root.statsAvailable && root.vendor === "nvidia"
        repeat: true
        onTriggered: nvidiaSmiProc.running = true
    }

    Timer {
        interval: root.pollingInterval
        running: root.statsAvailable && root.vendor === "amd"
        repeat: true
        onTriggered: {
            amdBusyFile.reload()
            amdVramUsedFile.reload()
            amdVramTotalFile.reload()
            root.usage = Math.max(0, Math.min(100, Number(amdBusyFile.text()))) / 100
            root.vramUsedMb = Number(amdVramUsedFile.text()) / (1024 * 1024)
            root.vramTotalMb = Number(amdVramTotalFile.text()) / (1024 * 1024)
            if (root.amdCardHwmonPath) {
                amdTempFile.reload()
                const milliDegrees = Number(amdTempFile.text())
                if (milliDegrees > 0)
                    root.temp = milliDegrees / 1000
            }
        }
    }

    // --- Stage 1: vendor + name detection ---
    Process {
        id: detectVendorProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", "lspci -mm | grep -Ei 'VGA compatible controller|3D controller'"]
        running: true
        stdout: StdioCollector {
            id: vendorCollector
            onStreamFinished: {
                const lines = vendorCollector.text.split('\n').filter(l => l.length > 0);
                if (lines.length === 0)
                    return;

                const discrete = lines.find(l => /nvidia/i.test(l)) ?? lines.find(l => /amd|advanced micro devices|ati/i.test(l));
                const chosen = discrete ?? lines[0];

                if (/nvidia/i.test(chosen))
                    root.vendor = "nvidia";
                else if (/amd|advanced micro devices|ati/i.test(chosen))
                    root.vendor = "amd";
                else if (/intel/i.test(chosen))
                    root.vendor = "intel";
                else
                    return;

                // lspci -mm quotes each field; the device name is typically the 4th field
                const fields = chosen.match(/"[^"]*"|\S+/g) ?? [];
                root.gpuName = (fields[3] ?? "").replace(/^"|"$/g, "");
                root.available = true;
            }
        }
    }

    // --- Stage 2: NVIDIA stats via nvidia-smi ---
    Process {
        id: nvidiaSmiProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            id: nvidiaCollector
            onStreamFinished: {
                const parts = nvidiaCollector.text.trim().split(',').map(s => Number(s.trim()));
                if (parts.length === 4 && parts.every(n => !isNaN(n))) {
                    root.usage = parts[0] / 100;
                    root.vramUsedMb = parts[1];
                    root.vramTotalMb = parts[2];
                    root.temp = parts[3];
                    root.statsAvailable = true;
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.statsAvailable = false;
        }
    }
    Connections {
        target: root
        function onVendorChanged() {
            if (root.vendor === "nvidia")
                nvidiaSmiProc.running = true;
        }
    }

    // --- Stage 2: AMD stats via sysfs (amdgpu) ---
    Process {
        id: findAmdCardProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", `
            for card in /sys/class/drm/card*/device; do
                [ -f "$card/uevent" ] || continue
                if grep -q '^PCI_ID=1002:' "$card/uevent" 2>/dev/null; then
                    echo "$card"
                    for hwmon in "$card"/hwmon/hwmon*; do
                        [ "$(cat "$hwmon/name" 2>/dev/null)" = "amdgpu" ] && echo "$hwmon/temp1_input"
                    done
                    exit 0
                fi
            done
        `]
        stdout: StdioCollector {
            id: amdCardCollector
            onStreamFinished: {
                const lines = amdCardCollector.text.trim().split('\n').filter(l => l.length > 0);
                if (lines.length === 0)
                    return;
                root.amdCardDrmPath = lines[0];
                amdBusyFile.path = `${lines[0]}/gpu_busy_percent`;
                amdVramUsedFile.path = `${lines[0]}/mem_info_vram_used`;
                amdVramTotalFile.path = `${lines[0]}/mem_info_vram_total`;
                if (lines[1]) {
                    root.amdCardHwmonPath = lines[1];
                    amdTempFile.path = lines[1];
                }
                root.statsAvailable = true;
            }
        }
    }
    Connections {
        target: root
        function onVendorChanged() {
            if (root.vendor === "amd")
                findAmdCardProc.running = true;
        }
    }

    FileView { id: amdBusyFile }
    FileView { id: amdVramUsedFile }
    FileView { id: amdVramTotalFile }
    FileView { id: amdTempFile }
}
