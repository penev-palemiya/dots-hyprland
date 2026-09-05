import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common as C

NestableObject {
    id: root

    required property HyprlandMonitor monitor
    readonly property var liveMonitorData: HyprlandData.monitors.find(m => m.id === monitor.id)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int activeWorkspace: monitor?.activeWorkspace?.id ?? 1
    readonly property bool currentWorkspaceNotFake: activeWindow?.activated ?? false // Active empty workspace = fake. At least, that's how I like to call it.
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeWorkspace
    readonly property int shownCount: C.Config.options.bar.workspaces.shown
    readonly property int group: Math.floor((activeWorkspace - 1) / shownCount)
    readonly property var specialWorkspace: liveMonitorData?.specialWorkspace
    readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
    readonly property bool specialWorkspaceActive: specialWorkspaceName !== ""

    property list<bool> occupied: []
    // Both bindings below used to read HyprlandData.windowList only inside a
    // function called from .map()'s callback. QML's binding tracker only
    // registers property reads made while the binding expression itself
    // evaluates - not ones made deeper inside a called function's body - so a
    // change to windowList alone (e.g. opening a second app on an
    // already-occupied workspace) was invisible to these bindings and they
    // kept showing the stale window/icon. Reading windowListDependency
    // directly in each expression (the `void` just discards the value) is
    // what actually registers the dependency and forces a re-evaluation.
    readonly property var windowListDependency: HyprlandData.windowList
    property list<var> biggestWindow: {
        void root.windowListDependency;
        return occupied.map((_, index) => {
            const wsId = getWorkspaceIdAt(index);
            var biggestWindow = HyprlandData.biggestWindowForWorkspace(wsId);
            return biggestWindow;
        });
    }
    // Every window on each shown workspace, largest first - the split-icon
    // layout needs to know how many windows there are, not just the biggest
    // one. Capped at 4 (2x2 grid) since that's all the layout can show; a 5th
    // window doesn't change which 4 icons appear, so there's no reason to
    // carry more of the list around or re-sort more of it per update.
    property list<var> windows: {
        void root.windowListDependency;
        return occupied.map((_, index) => {
            const wsId = getWorkspaceIdAt(index);
            return HyprlandData.hyprlandClientsForWorkspace(wsId)
                .slice()
                .sort((a, b) => (b.size[0] * b.size[1]) - (a.size[0] * a.size[1]))
                .slice(0, 4);
        });
    }

    function getWorkspaceId(group, index) {
        return group * root.shownCount + index + 1;
    }
    function getWorkspaceIdAt(index) {
        return root.getWorkspaceId(root.group, index);
    }

    // Function to update workspaceOccupied
    function updateWorkspaceOccupied() {
        root.occupied = Array.from({
            length: root.shownCount
        }, (_, i) => {
            const thisWorkspaceId = getWorkspaceId(root.group, i);
            return Hyprland.workspaces.values.some(ws => ws.id === thisWorkspaceId);
        });
    }

    // Occupied workspace updates
    Component.onCompleted: updateWorkspaceOccupied()
    Connections {
        target: Hyprland.workspaces
        function onValuesChanged() {
            root.updateWorkspaceOccupied();
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.updateWorkspaceOccupied();
        }
    }
    onGroupChanged: {
        updateWorkspaceOccupied();
    }
}
