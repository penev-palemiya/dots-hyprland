pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/**
 * Read-only, event-driven snapshot of every Hyprland output.
 *
 * `hyprctl -j monitors all` is the source of truth. It reports the current
 * mode in physical pixels (`width` / `height`), while `x` / `y` are positions
 * in Hyprland's scaled-and-transformed logical layout coordinate space.
 */
Singleton {
    id: root

    readonly property int refreshDebounceMs: 120

    property var monitors: []
    readonly property var activeMonitors: monitors.filter(monitor => monitor.enabled)
    readonly property var disabledMonitors: monitors.filter(monitor => !monitor.enabled)
    readonly property int activeCount: activeMonitors.length
    readonly property bool hasMultipleDisplays: activeCount > 1
    // Connected-output identity only; focus and configuration refreshes do not
    // change it. Preview uses this to detect physical hotplug/removal.
    readonly property string topologySignature: monitors.map(monitor => monitor.name).sort().join("\u001f")

    property bool loading: false
    property string lastError: ""
    property double lastRefreshTime: 0
    property int revision: 0
    // Counts actual hyprctl process launches, not coalesced refresh requests.
    property int refreshLaunchCount: 0

    property bool refreshQueuedWhileRunning: false

    function monitorByName(name: string): var {
        return monitors.find(monitor => monitor.name === name) ?? null;
    }

    function refresh(): void {
        if (getMonitors.running) {
            refreshQueuedWhileRunning = true;
            return;
        }
        refreshDebounce.restart();
    }

    function updateFocusedMonitor(name: string): void {
        if (name.length === 0 || !monitors.some(monitor => monitor.name === name))
            return;

        monitors = monitors.map(monitor => {
            const next = {};
            for (const key in monitor)
                next[key] = monitor[key];
            next.focused = monitor.name === name;
            return next;
        });
        revision += 1;
    }

    function numberOr(value, fallback) {
        const number = Number(value);
        return Number.isFinite(number) ? number : fallback;
    }

    function isQuarterTurn(transform: int): bool {
        return [1, 3, 5, 7].includes(transform);
    }

    function parseMode(rawMode, monitor): var {
        const raw = String(rawMode ?? "");
        const match = raw.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
        const width = match ? Number(match[1]) : null;
        const height = match ? Number(match[2]) : null;
        const refreshRate = match ? Number(match[3]) : null;
        const current = width !== null
            && width === monitor.width
            && height === monitor.height
            && Math.abs(refreshRate - monitor.refreshRate) < 0.1;

        // Hyprland does not expose a preferred-mode marker in this response.
        return { width, height, refreshRate, raw, current };
    }

    function normalizeMonitor(rawMonitor): var {
        const width = numberOr(rawMonitor.width, 0);
        const height = numberOr(rawMonitor.height, 0);
        const scale = numberOr(rawMonitor.scale, 1);
        const transform = numberOr(rawMonitor.transform, 0);
        const transformedWidth = isQuarterTurn(transform) ? height : width;
        const transformedHeight = isQuarterTurn(transform) ? width : height;

        const monitor = {
            id: numberOr(rawMonitor.id, -1),
            name: String(rawMonitor.name ?? ""),
            description: String(rawMonitor.description ?? ""),
            make: String(rawMonitor.make ?? ""),
            model: String(rawMonitor.model ?? ""),
            serial: String(rawMonitor.serial ?? ""),
            physicalWidth: numberOr(rawMonitor.physicalWidth, 0),
            physicalHeight: numberOr(rawMonitor.physicalHeight, 0),

            enabled: !Boolean(rawMonitor.disabled),
            focused: Boolean(rawMonitor.focused),
            dpms: Boolean(rawMonitor.dpmsStatus),

            // Current output mode in physical pixels, as returned by Hyprland.
            width,
            height,
            refreshRate: numberOr(rawMonitor.refreshRate, 0),
            scale,
            transform,

            // Layout geometry: x/y are already scaled/transformed by Hyprland.
            x: numberOr(rawMonitor.x, 0),
            y: numberOr(rawMonitor.y, 0),
            logicalWidth: scale > 0 ? transformedWidth / scale : 0,
            logicalHeight: scale > 0 ? transformedHeight / scale : 0,

            mirrorOf: String(rawMonitor.mirrorOf ?? "none"),
            vrr: Boolean(rawMonitor.vrr),
            currentFormat: String(rawMonitor.currentFormat ?? ""),
            colorManagement: String(rawMonitor.colorManagementPreset ?? ""),
        };

        monitor.modes = Array.isArray(rawMonitor.availableModes)
            ? rawMonitor.availableModes.map(mode => parseMode(mode, monitor))
            : [];
        return monitor;
    }

    function failRefresh(message: string): void {
        const changed = lastError !== message;
        lastError = message;
        if (changed)
            console.error(`[DisplaysService] ${message}`);
    }

    function commitMonitorJson(text: string): void {
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (error) {
            failRefresh(`hyprctl returned invalid monitor JSON: ${error}`);
            return;
        }

        if (!Array.isArray(parsed)) {
            failRefresh("hyprctl returned monitor JSON that is not an array");
            return;
        }

        monitors = parsed.map(rawMonitor => normalizeMonitor(rawMonitor));
        lastError = "";
        lastRefreshTime = Date.now();
        revision += 1;
    }

    Timer {
        id: refreshDebounce
        interval: root.refreshDebounceMs
        repeat: false
        onTriggered: {
            if (getMonitors.running) {
                root.refreshQueuedWhileRunning = true;
                return;
            }
            root.loading = true;
            root.refreshLaunchCount += 1;
            getMonitors.running = true;
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "-j", "monitors", "all"]

        property string output: ""

        stdout: StdioCollector {
            id: monitorCollector
            onStreamFinished: getMonitors.output = monitorCollector.text
        }

        onExited: (exitCode, exitStatus) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.failRefresh(`hyprctl monitors all failed with exit code ${exitCode}`);
            } else {
                root.commitMonitorJson(getMonitors.output);
            }

            if (root.refreshQueuedWhileRunning) {
                root.refreshQueuedWhileRunning = false;
                root.refresh();
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // Socket2 event names supported by Hyprland 0.56.2 that can alter
            // this service's output list or its configuration-derived fields.
            if ([
                "monitoradded", "monitoraddedv2",
                "monitorremoved", "monitorremovedv2",
                "configreloaded",
            ].includes(event.name)) {
                root.refresh();
            } else if (["focusedmon", "focusedmonv2"].includes(event.name)) {
                // Both events document the newly focused monitor as argument 0.
                // This changes only `focused`, so avoid a full monitors query.
                root.updateFocusedMonitor(event.parse(2)[0] ?? "");
            }
        }
    }

    Component.onCompleted: refresh()
}
