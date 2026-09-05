pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * Provides access to some Hyprland data not available in Quickshell.Hyprland.
 */
Singleton {
    id: root
    property var windowList: []
    property var addresses: []
    property var windowByAddress: ({})
    property var workspaces: []
    property var workspaceIds: []
    property var workspaceById: ({})
    property var activeWorkspace: null
    property var monitors: []
    property var layers: ({})

    // Convenient stuff

    function toplevelsForWorkspace(workspace) {
        return ToplevelManager.toplevels.values.filter(toplevel => {
            const address = `0x${toplevel.HyprlandToplevel?.address}`;
            var win = HyprlandData.windowByAddress[address];
            return win?.workspace?.id === workspace;
        })
    }

    function hyprlandClientsForWorkspace(workspace) {
        return root.windowList.filter(win => win.workspace.id === workspace);
    }

    function clientForToplevel(toplevel) {
        if (!toplevel || !toplevel.HyprlandToplevel) {
            return null;
        }
        const address = `0x${toplevel?.HyprlandToplevel?.address}`;
        return root.windowByAddress[address];
    }

    // Internals

    function updateWindowList() {
        getClients.running = true;
    }

    function updateLayers() {
        getLayers.running = true;
    }

    function updateMonitors() {
        getMonitors.running = true;
    }

    function updateWorkspaces() {
        getWorkspaces.running = true;
        getActiveWorkspace.running = true;
    }

    function updateAll() {
        updateWindowList();
        updateMonitors();
        updateLayers();
        updateWorkspaces();
    }

    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = HyprlandData.windowList.filter(w => w.workspace.id == workspaceId);
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0);
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0);
            return winArea > maxArea ? win : maxWin;
        }, null);
    }

    Component.onCompleted: {
        updateAll();
    }

    // Hyprland fires a burst of events for one user action - opening one
    // terminal produced 18 raw events in testing (windowtitle fired 3 times
    // as the shell inside it settled its title), and each used to trigger a
    // full updateAll(): 5 separate `hyprctl` processes and a re-parse of every
    // JSON source, whether or not that source actually changed. That is what
    // made opening/closing an app visibly stall the bar.
    //
    // Two independent fixes, both required - neither alone is enough:
    //
    // 1. Coalesce a burst into one update. pendingSources accumulates which
    //    sources are dirty; the timer fires once after the burst goes quiet
    //    and processes all of them together, so 8 activewindow events in
    //    166ms cost one flush instead of 8.
    // 2. Only refresh the source(s) an event can actually affect. A
    //    windowtitle change cannot move a monitor or create a workspace -
    //    refreshing monitors/layers/workspaces for it was pure waste.
    //
    // debounceInterval trades latency for coalescing: raise it if bursts are
    // still visible, lower it if UI updates feel delayed after a real change.
    property int debounceInterval: 50
    property var pendingSources: ({})

    function markDirty(sources) {
        for (var i = 0; i < sources.length; ++i)
            root.pendingSources[sources[i]] = true;
        debounceTimer.restart();
    }

    // Maps each Hyprland event to the source(s) it can actually change.
    // "all" covers configreloaded, where the safe assumption is that anything
    // could be different. Events absent here (openlayer/closelayer/screencast,
    // as before, plus purely informational ones like activelayout/submap/bind)
    // are not layer-shell/config concerns of this service and are ignored.
    readonly property var eventSources: ({
        // Window-level changes: only the window list can be affected.
        openwindow: ["windows"], closewindow: ["windows"],
        movewindow: ["windows"], movewindowv2: ["windows"],
        windowtitle: ["windows"], windowtitlev2: ["windows"],
        activewindow: ["windows"], activewindowv2: ["windows"],
        changefloatingmode: ["windows"], fullscreen: ["windows"],
        pin: ["windows"], minimize: ["windows"], urgent: ["windows"],
        togglegroup: ["windows"], moveintogroup: ["windows"],
        moveintogroupv2: ["windows"], moveoutofgroup: ["windows"],
        ignoregrouplock: ["windows"], lockgroups: ["windows"],
        // Workspace-level changes: windows can move with a workspace switch
        // (a window's own `workspace` field changes), so both refresh together.
        workspace: ["workspaces", "windows"], workspacev2: ["workspaces", "windows"],
        createworkspace: ["workspaces"], createworkspacev2: ["workspaces"],
        destroyworkspace: ["workspaces"], destroyworkspacev2: ["workspaces"],
        moveworkspace: ["workspaces", "windows"], moveworkspacev2: ["workspaces", "windows"],
        renameworkspace: ["workspaces"], activespecial: ["workspaces"],
        focusedmon: ["workspaces"],
        // Monitor topology changes: workspaces are reassigned across monitors
        // when one appears or disappears, so refresh both.
        monitoradded: ["monitors", "workspaces"], monitoraddedv2: ["monitors", "workspaces"],
        monitorremoved: ["monitors", "workspaces"], monitorremovedv2: ["monitors", "workspaces"],
        // Config can change anything about how any of this is reported.
        configreloaded: ["all"]
    })

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            // console.log("Hyprland raw event:", event.name);
            const sources = root.eventSources[event.name];
            if (sources === undefined) return;
            root.markDirty(sources);
        }
    }

    Timer {
        id: debounceTimer
        interval: root.debounceInterval
        repeat: false
        onTriggered: {
            const sources = root.pendingSources;
            root.pendingSources = ({});
            if (sources.all || sources.windows) root.updateWindowList();
            if (sources.all || sources.monitors) root.updateMonitors();
            if (sources.all || sources.layers) root.updateLayers();
            if (sources.all || sources.workspaces) root.updateWorkspaces();
        }
    }

    Process {
        id: getClients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            id: clientsCollector
            onStreamFinished: {
                root.windowList = JSON.parse(clientsCollector.text)
                let tempWinByAddress = {};
                for (var i = 0; i < root.windowList.length; ++i) {
                    var win = root.windowList[i];
                    tempWinByAddress[win.address] = win;
                }
                root.windowByAddress = tempWinByAddress;
                root.addresses = root.windowList.map(win => win.address);
            }
        }
    }

    Process {
        id: getMonitors
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            id: monitorsCollector
            onStreamFinished: {
                root.monitors = JSON.parse(monitorsCollector.text);
            }
        }
    }

    Process {
        id: getLayers
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            id: layersCollector
            onStreamFinished: {
                root.layers = JSON.parse(layersCollector.text);
            }
        }
    }

    Process {
        id: getWorkspaces
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            id: workspacesCollector
            onStreamFinished: {
                var rawWorkspaces = JSON.parse(workspacesCollector.text);
                // Filter out invalid workspace ids (e.g. lock-screen temp workspace 2147483647 - N)
                root.workspaces = rawWorkspaces.filter(ws => ws.id >= 1 && ws.id <= 100);
                let tempWorkspaceById = {};
                for (var i = 0; i < root.workspaces.length; ++i) {
                    var ws = root.workspaces[i];
                    tempWorkspaceById[ws.id] = ws;
                }
                root.workspaceById = tempWorkspaceById;
                root.workspaceIds = root.workspaces.map(ws => ws.id);
            }
        }
    }

    Process {
        id: getActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            id: activeWorkspaceCollector
            onStreamFinished: {
                root.activeWorkspace = JSON.parse(activeWorkspaceCollector.text);
            }
        }
    }
}
