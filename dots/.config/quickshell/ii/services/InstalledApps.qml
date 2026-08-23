pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

/** Page-lazy, read-only installed GUI application inventory. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/installed_apps.py`)
    property list<var> apps: []
    property bool loading: false
    property bool ready: false
    property string error: ""
    property var enrichment: ({})
    signal refreshed(bool success)

    function refresh() {
        if (root.loading)
            return;
        root.loading = true;
        root.ready = false;
        root.error = "";
        inventoryProc.running = true;
    }

    function desktopFileId(entry) {
        const id = String(entry?.id || "");
        return id.endsWith(".desktop") ? id : `${id}.desktop`;
    }

    function isInternal(entry) {
        const id = String(entry?.id || "").toLowerCase();
        return id === "org.quickshell" || id === "org.quickshell.desktop";
    }

    function sourceType(entry) {
        const id = String(entry?.id || "").toLowerCase();
        const command = String(entry?.execString || entry?.command || "").toLowerCase();
        if (command.includes("steam://rungameid") || command.includes("steam steam://"))
            return "steam";
        if (id.startsWith("net.lutris.") || command.includes("lutris"))
            return "lutris";
        if (command.includes("winetricks") || command.includes("protontricks") || command.includes(" wine ") || id.startsWith("wine"))
            return "wine";
        if (id.startsWith("chrome-") || command.includes("--app-id") || command.includes("--app="))
            return "web";
        return "local";
    }

    function sourceLabel(app) {
        switch (app.sourceType) {
        case "pacman": return app.foreign ? Translation.tr("Foreign package") : Translation.tr("System package");
        case "flatpak": return Translation.tr("Flatpak");
        case "steam": return Translation.tr("Steam");
        case "lutris": return Translation.tr("Lutris");
        case "wine": return Translation.tr("Wine");
        case "web": return Translation.tr("Web app");
        case "local": return Translation.tr("Local application");
        default: return Translation.tr("Unknown");
        }
    }

    function buildInventory() {
        const packageInfo = root.enrichment.pacman || {};
        const ownership = root.enrichment.ownership || {};
        const flatpakInfo = root.enrichment.flatpak || {};
        const grouped = new Map();
        const entries = Array.from(DesktopEntries.applications.values || [])
            .filter(entry => entry && !entry.noDisplay && !entry.hidden && !root.isInternal(entry));

        for (let i = 0; i < entries.length; i++) {
            const entry = entries[i];
            const desktopId = root.desktopFileId(entry);
            const flatpak = flatpakInfo[desktopId];
            const packageId = ownership[desktopId] || "";
            const packageData = packageInfo[packageId] || null;
            let type = root.sourceType(entry);
            let key = `desktop:${String(entry.id)}`;
            if (flatpak) {
                type = "flatpak";
                key = `flatpak:${flatpak.id}`;
            } else if (packageData) {
                type = "pacman";
                key = `pacman:${packageId}`;
            }

            const launcher = {
                id: String(entry.id || ""),
                name: String(entry.name || entry.id || ""),
                icon: String(entry.icon || "application-x-executable"),
                genericName: String(entry.genericName || ""),
                comment: String(entry.comment || ""),
                execString: String(entry.execString || ""),
                categories: entry.categories || [],
            };
            let app = grouped.get(key);
            if (!app) {
                app = {
                    stableId: key,
                    displayName: launcher.name,
                    icon: launcher.icon,
                    description: launcher.genericName || launcher.comment || "",
                    sourceType: type,
                    sourceLabel: "",
                    packageId: packageId,
                    appId: flatpak?.id || "",
                    version: packageData?.version || flatpak?.version || "",
                    installedSize: packageData?.installedSize || flatpak?.installedSize || "",
                    installDate: packageData?.installDate || "",
                    installReason: packageData?.installReason || "",
                    repository: packageData?.repository || "",
                    foreign: Boolean(packageData?.foreign),
                    desktopEntries: [],
                    removable: false,
                };
                grouped.set(key, app);
            }
            app.desktopEntries.push(launcher);
        }

        const result = Array.from(grouped.values());
        for (let i = 0; i < result.length; i++) {
            const app = result[i];
            app.desktopEntries.sort((a, b) => `${a.name}\n${a.id}`.localeCompare(`${b.name}\n${b.id}`));
            const primary = app.desktopEntries[0];
            app.displayName = primary.name;
            app.icon = primary.icon;
            if (!app.description)
                app.description = primary.genericName || primary.comment || "";
            app.sourceLabel = root.sourceLabel(app);
            app.searchText = [app.displayName, app.description, app.packageId, app.appId, app.sourceLabel,
                ...app.desktopEntries.map(entry => `${entry.name} ${entry.id}`)].join(" ").toLowerCase();
        }
        result.sort((a, b) => String(a.displayName).localeCompare(String(b.displayName)));
        root.apps = result;
        root.ready = true;
    }

    function parseInventory(text) {
        try {
            root.enrichment = JSON.parse(text || "{}");
            root.buildInventory();
            root.refreshed(true);
        } catch (exception) {
            root.apps = [];
            root.error = Translation.tr("Installed application metadata is unavailable.");
            root.refreshed(false);
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            if (root.ready && !root.loading)
                root.buildInventory();
        }
    }

    Process {
        id: inventoryProc
        command: ["python3", root.helperPath]
        stdout: StdioCollector { onStreamFinished: root.parseInventory(text) }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length > 0 && root.error.length === 0) root.error = text.trim()
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0 && !root.ready) {
                root.error = root.error || Translation.tr("Could not read installed applications.");
                root.refreshed(false);
            }
        }
    }
}
