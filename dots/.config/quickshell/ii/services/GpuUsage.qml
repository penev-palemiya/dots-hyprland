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
 *
 * NVIDIA specifically gets a power-aware polling state machine rather than a
 * flat timer: measured live on an RTX 3050 Mobile laptop, a single
 * `nvidia-smi` call reliably woke the runtime-suspended dGPU and kept it
 * active for ~25-30s afterward, and polling on a flat timer re-woke it before
 * it ever reached D3cold again - so "poll utilization every N seconds"
 * directly prevents the power state it's trying to report on. See
 * nvidiaState below for the fix. This only applies where Runtime D3 is
 * actually usable (checked once via nvidiaRtd3Usable) - a desktop card or a
 * laptop where the dGPU never runtime-suspends falls back to plain polling,
 * because waiting out a suspend-detection grace window would otherwise throttle
 * a GPU that's legitimately always on down to one update every 30-60s.
 */
Singleton {
    id: root

    property string vendor: "" // "nvidia" | "amd" | "intel" | ""
    property string gpuName: ""
    property bool available: false
    // Whether the currently displayed `usage` (and, when set, `temp`) reflect a
    // real sample - not merely a boolean of "detection succeeded once". A
    // transient read failure clears this; a later successful read sets it back.
    // It intentionally does not gate whether polling *continues* (see the
    // NVIDIA/AMD timers below) - a value meaning "can I trust the current
    // number" must not double as "should I ever try again".
    property bool statsAvailable: false
    // Whether `temp` specifically is current. Separate from statsAvailable
    // because temperature can go stale (AMD hwmon read fails, or the NVIDIA
    // GPU is suspended and wasn't queried) while `usage` is still valid.
    property bool tempAvailable: false

    property real usage: 0 // 0-1
    property real temp: 0 // Celsius

    // "unknown" | "active" | "suspended" - only meaningfully maintained for
    // NVIDIA today (see nvidiaState). AMD/Intel leave this at "unknown".
    property string powerState: "unknown"

    property string amdCardHwmonPath: ""
    property string amdCardDrmPath: ""
    readonly property bool resourcesOverlayOpen: Persistent.states.overlay.open.includes("resources") && (GlobalStates.overlayOpen || Persistent.states.overlay.resources.pinned)
    readonly property bool detailedPollingActive: BarPopups.resourcesOpen || resourcesOverlayOpen
    readonly property int pollingInterval: detailedPollingActive ? (Config.options?.resources?.updateInterval ?? 3000) : Math.max(Config.options?.resources?.updateInterval ?? 3000, 10000)

    // --- NVIDIA power-aware state machine ---
    //
    //   INITIAL --suspended--------------------------------> SUSPENDED
    //   INITIAL --active----------------------------------> SAMPLE_ONCE
    //   SUSPENDED --observed suspended->active-------------> SAMPLE_ONCE
    //   SAMPLE_ONCE --usage>0-------------------------------> MONITORING
    //   SAMPLE_ONCE --usage==0------------------------------> WAIT_FOR_SLEEP
    //   MONITORING --still active---------------------------> SAMPLE_ONCE (resamples)
    //   MONITORING --usage settles to 0---------------------> WAIT_FOR_SLEEP
    //   MONITORING/WAIT_FOR_SLEEP --observed suspended------> SUSPENDED
    //   WAIT_FOR_SLEEP --active past grace deadline---------> SAMPLE_ONCE
    //
    // Critical invariant: `runtime_status == active` by itself never triggers
    // nvidia-smi from WAIT_FOR_SLEEP - only a transition *into* active from a
    // confirmed suspended state, or the bounded grace-window fallback below,
    // does. Anything weaker reproduces the self-wake loop this exists to avoid:
    // nvidia-smi wakes the GPU -> cheap poll sees "active" -> runs nvidia-smi
    // again -> the GPU never reaches suspended.
    property string nvidiaState: "initial" // "initial" | "suspended" | "sample_once" | "monitoring" | "wait_for_sleep" | "conventional"
    property bool nvidiaRtd3Usable: false
    property bool nvidiaRtd3Checked: false
    property real nvidiaGraceDeadline: 0 // Date.now()-scale ms

    // Conservative floor for how long WAIT_FOR_SLEEP waits, past which it
    // assumes continued "active" is real work rather than the tail of our own
    // last probe, and takes one more sample to check. This closes a real gap:
    // without a bounded fallback, a sustained workload that starts during our
    // own probe's active tail (and therefore never lets runtime_status dip
    // back to suspended) would leave the bar stuck at a stale 0% forever,
    // since the "only re-arm on suspended->active" rule would never fire again.
    //
    // 45s is deliberately well above the ~25-30s active tail measured on the
    // one tested device (RTX 3050 Mobile). power/autosuspend_delay_ms, where
    // readable, can only push this further out, never below the floor -
    // autosuspend_delay_ms is a kernel-side idle timer, not a measurement of
    // how long *this* driver's D3 transition actually takes, so it's a hint,
    // not a guarantee, and erring toward "wait a bit longer" is the safe
    // direction (an extra nvidia-smi call once in a while) versus erring
    // toward "wait too little" (reproducing the self-wake loop).
    readonly property int nvidiaGraceFloorMs: 45000
    property int nvidiaGraceMs: nvidiaGraceFloorMs

    function pollNvidiaRuntimeStatus() {
        nvidiaRuntimeStatusFile.reload();
    }

    function handleNvidiaRuntimeStatus(rawStatus) {
        const isSuspended = rawStatus === "suspended";
        const isActive = rawStatus === "active";
        // "suspending"/"resuming" are transient kernel states - treated as
        // neither, so nothing acts on them; the next poll will land on a
        // stable value.

        if (isSuspended)
            root.powerState = "suspended";
        else if (isActive)
            root.powerState = "active";

        switch (root.nvidiaState) {
        case "initial":
            if (isSuspended)
                root.enterNvidiaSuspended();
            else if (isActive)
                root.runNvidiaSample();
            break;
        case "suspended":
            if (isActive)
                root.runNvidiaSample();
            break;
        case "monitoring":
            if (isSuspended)
                root.enterNvidiaSuspended();
            else if (isActive)
                root.runNvidiaSample(); // resample - GPU is still genuinely active
            break;
        case "wait_for_sleep":
            if (isSuspended)
                root.enterNvidiaSuspended();
            else if (isActive && Date.now() >= root.nvidiaGraceDeadline)
                root.runNvidiaSample(); // bounded fallback re-check, not a periodic poll
            break;
        case "sample_once":
            break; // a sample is already in flight - ignore ticks until it resolves
        }
    }

    function enterNvidiaSuspended() {
        root.usage = 0;
        root.tempAvailable = false; // don't show a frozen last-known temperature as current
        root.powerState = "suspended";
        root.nvidiaState = "suspended";
    }

    function runNvidiaSample() {
        if (nvidiaSmiProc.running)
            return; // a sample is already in flight
        root.nvidiaState = "sample_once";
        // VRAM has no consumer anywhere in the UI (checked: bar and popup only
        // ever read usage/temp), so it's never queried. Temperature is only
        // asked for while something is actually showing it, matching the
        // consumer map - the bar only ever needs utilization.
        const fields = root.detailedPollingActive ? "utilization.gpu,temperature.gpu" : "utilization.gpu";
        nvidiaSmiProc.command = ["nvidia-smi", `--query-gpu=${fields}`, "--format=csv,noheader,nounits"];
        nvidiaSmiProc.running = true;
    }

    FileView {
        id: nvidiaRuntimeStatusFile
        onLoaded: root.handleNvidiaRuntimeStatus(nvidiaRuntimeStatusFile.text().trim())
        onLoadFailed: {
            // Lost the sysfs node after having resolved it (device removed?) -
            // fail safe into plain polling rather than getting stuck waiting
            // on a file that's gone.
            root.nvidiaRtd3Usable = false;
            root.nvidiaState = "conventional";
            root.runNvidiaSample();
        }
    }

    // Drives the cheap runtime_status check at the existing bar/detailed
    // cadence for every RTD3 state except "sample_once" (a sample already in
    // flight has nothing for a cheap poll to add). Also drives MONITORING's
    // resampling and WAIT_FOR_SLEEP's grace-window re-check, since both are
    // just different reactions to the same cheap read - see handleNvidiaRuntimeStatus.
    Timer {
        interval: root.pollingInterval
        running: root.vendor === "nvidia" && root.nvidiaRtd3Usable && root.nvidiaState !== "sample_once"
        repeat: true
        onTriggered: root.pollNvidiaRuntimeStatus()
    }

    // Fallback for desktop NVIDIA cards and laptops where Runtime D3 isn't
    // usable: plain polling at the existing cadence, same as before. Not
    // gated on statsAvailable (see the property doc above) - a transient
    // nvidia-smi failure must not permanently stop this from trying again.
    Timer {
        interval: root.pollingInterval
        running: root.vendor === "nvidia" && root.nvidiaRtd3Checked && !root.nvidiaRtd3Usable
        repeat: true
        onTriggered: root.runNvidiaSample()
    }

    Process {
        id: nvidiaSmiProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            id: nvidiaCollector
            onStreamFinished: {
                const parts = nvidiaCollector.text.trim().split(',').map(s => Number(s.trim()));
                if (parts.length >= 1 && !isNaN(parts[0])) {
                    root.usage = parts[0] / 100;
                    root.statsAvailable = true;
                    root.powerState = "active";
                    if (parts.length >= 2 && !isNaN(parts[1])) {
                        root.temp = parts[1];
                        root.tempAvailable = true;
                    }

                    if (root.nvidiaRtd3Usable) {
                        if (root.usage > 0) {
                            root.nvidiaState = "monitoring";
                        } else {
                            root.nvidiaState = "wait_for_sleep";
                            root.nvidiaGraceDeadline = Date.now() + root.nvidiaGraceMs;
                        }
                    }
                    // Conventional path: nvidiaState stays "conventional"; the
                    // plain Timer above keeps sampling on its own regardless
                    // of this result.
                }
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                root.statsAvailable = false;
                if (root.nvidiaRtd3Usable) {
                    // Don't die permanently and don't hammer retries either -
                    // fall back to "initial" so the next cheap-poll tick (already
                    // scheduled, at most one pollingInterval away) re-evaluates
                    // current power state from scratch and retries naturally.
                    root.nvidiaState = "initial";
                }
                // Conventional path just tries again on its own next tick.
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

    // --- Stage 2: NVIDIA - resolve the PCI device and whether Runtime D3 is
    // actually usable, before deciding which polling strategy to use ---
    Process {
        id: findNvidiaCardProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        command: ["bash", "-c", `
            for card in /sys/class/drm/card*/device; do
                [ -f "$card/uevent" ] || continue
                if grep -q '^PCI_ID=10DE:' "$card/uevent" 2>/dev/null; then
                    if [ -f "$card/power/runtime_status" ]; then
                        echo "RTSTATUS_PATH=$card/power/runtime_status"
                    fi
                    if [ -f "$card/power/control" ]; then
                        echo "CONTROL=$(cat "$card/power/control")"
                    fi
                    if [ -f "$card/power/autosuspend_delay_ms" ]; then
                        echo "AUTOSUSPEND_MS=$(cat "$card/power/autosuspend_delay_ms")"
                    fi
                    pci=$(basename "$(readlink -f "$card")")
                    proc="/proc/driver/nvidia/gpus/$pci/power"
                    if [ -f "$proc" ]; then
                        grep -m1 'Runtime D3 status:' "$proc" | sed 's/^/RTD3=/'
                    fi
                    exit 0
                fi
            done
        `]
        stdout: StdioCollector {
            id: nvidiaCardCollector
            onStreamFinished: {
                root.nvidiaRtd3Checked = true;

                const text = nvidiaCardCollector.text;
                const statusPathMatch = text.match(/^RTSTATUS_PATH=(.+)$/m);
                const controlMatch = text.match(/^CONTROL=(.+)$/m);
                const autosuspendMatch = text.match(/^AUTOSUSPEND_MS=(\d+)$/m);
                const rtd3Match = text.match(/^RTD3=Runtime D3 status:\s*(.+)$/m);

                const controlAuto = !!controlMatch && controlMatch[1].trim() === "auto";
                const rtd3Enabled = !!rtd3Match && /^Enabled/i.test(rtd3Match[1].trim());

                if (statusPathMatch && controlAuto && rtd3Enabled) {
                    // Runtime D3 is present, enabled, and the kernel isn't
                    // holding the device permanently powered ("on") - the
                    // power-aware state machine is worth using.
                    const autosuspendMs = autosuspendMatch ? Number(autosuspendMatch[1]) : 0;
                    root.nvidiaGraceMs = Math.max(root.nvidiaGraceFloorMs, autosuspendMs > 0 ? autosuspendMs * 3 : 0);
                    nvidiaRuntimeStatusFile.path = statusPathMatch[1];
                    root.nvidiaRtd3Usable = true;
                    root.pollNvidiaRuntimeStatus(); // resolve INITIAL immediately - don't
                                                     // wait up to pollingInterval to notice
                                                     // a workload already running at startup.
                } else {
                    // No Runtime D3, disabled, kernel-side control isn't
                    // "auto", or couldn't be determined - a GPU that legitimately
                    // stays active shouldn't wait a 30-60s grace window between
                    // updates. Poll it plainly instead, like before.
                    root.nvidiaRtd3Usable = false;
                    root.nvidiaState = "conventional";
                    root.runNvidiaSample();
                }
            }
        }
    }
    Connections {
        target: root
        function onVendorChanged() {
            if (root.vendor === "nvidia")
                findNvidiaCardProc.running = true;
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

    // Not gated on statsAvailable: a transient sysfs read failure (see the
    // FileViews below) must not permanently stop this from trying again,
    // same reasoning as the NVIDIA conventional-path timer above.
    Timer {
        interval: root.pollingInterval
        running: root.vendor === "amd"
        repeat: true
        onTriggered: {
            amdBusyFile.reload();
            if (root.amdCardHwmonPath)
                amdTempFile.reload();
        }
    }

    // reload() is asynchronous (confirmed against the Quickshell FileView
    // source: it only blocks if blockLoading/blockAllReads is set, neither of
    // which is set here) - so values are computed from onLoaded/onLoadFailed,
    // not from the statement right after reload(), which would read
    // whatever was loaded *before* the reload that was just triggered.
    FileView {
        id: amdBusyFile
        onLoaded: {
            const value = Number(amdBusyFile.text());
            if (!isNaN(value)) {
                root.usage = Math.max(0, Math.min(100, value)) / 100;
                root.statsAvailable = true;
            }
        }
        onLoadFailed: {
            // A missing/unreadable file previously misread as a believable
            // 0% (Number("") === 0 in JS). Now explicitly treated as "we
            // don't know", not as "the GPU is idle".
            root.statsAvailable = false;
        }
    }
    FileView {
        id: amdTempFile
        onLoaded: {
            const milliDegrees = Number(amdTempFile.text());
            if (milliDegrees > 0) {
                root.temp = milliDegrees / 1000;
                root.tempAvailable = true;
            }
        }
        onLoadFailed: root.tempAvailable = false
    }
}
