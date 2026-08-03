import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    property string activeWindowAddress: `0x${activeWindow?.HyprlandToplevel?.address}`
    property bool focusingThisMonitor: HyprlandData.activeWorkspace?.monitor == monitor?.name
    property var biggestWindow: HyprlandData.biggestWindowForWorkspace(HyprlandData.monitors[root.monitor?.id]?.activeWorkspace.id)
    readonly property var shownWindow: (root.focusingThisMonitor && root.activeWindow?.activated && root.biggestWindow) ? root.activeWindow : root.biggestWindow
    readonly property var shownDesktopEntry: DesktopEntries.heuristicLookup(root.shownWindow?.appId ?? root.shownWindow?.class ?? "")
    readonly property string shownAppName: root.displayAppName(root.shownDesktopEntry?.name || root.shownWindow?.appId || root.shownWindow?.class || Translation.tr("Desktop"), root.shownWindow?.appId ?? "", root.shownWindow?.class ?? "")
    readonly property var shownAppAliases: root.appAliases(root.shownAppName, root.shownWindow?.appId ?? "", root.shownWindow?.class ?? "")
    readonly property string shownTitle: root.cleanWindowTitle(root.shownWindow?.title ?? `${Translation.tr("Workspace")} ${monitor?.activeWorkspace?.id ?? 1}`, root.shownAppAliases)

    implicitWidth: colLayout.implicitWidth

    function displayAppName(appName, appId, appClass) {
        const name = String(appName ?? "").trim();
        const lowered = [name, appId, appClass].join(" ").toLowerCase();
        if (lowered.includes("firefox"))
            return "Mozilla Firefox";
        return name;
    }

    function appAliases(appName, appId, appClass) {
        const aliases = [appName, appId, appClass].map(value => String(value ?? "").trim()).filter(value => value.length > 0);
        const lowered = aliases.join(" ").toLowerCase();
        if (lowered.includes("firefox"))
            aliases.push("Mozilla Firefox");
        if (lowered.includes("code") || lowered.includes("visual studio code"))
            aliases.push("Visual Studio Code");
        return [...new Set(aliases)];
    }

    function cleanWindowTitle(title, appAliases) {
        const text = String(title ?? "").trim();
        const aliases = appAliases ?? [];
        if (aliases.length === 0)
            return text;
        const separators = [" - ", " — ", " – "];
        for (const separator of separators) {
            for (const alias of aliases) {
                const suffix = `${separator}${alias}`;
                if (text.endsWith(suffix))
                    return text.slice(0, -suffix.length).trim();
            }
        }
        return text;
    }

    ColumnLayout {
        id: colLayout

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: -4

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smallest
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: root.shownAppName

        }

        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer0
            elide: Text.ElideRight
            text: root.shownTitle
        }

    }

}
