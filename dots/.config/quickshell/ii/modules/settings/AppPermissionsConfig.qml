import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property var selectedApp: null

    Component.onCompleted: AppPermissions.refresh()

    function desktopEntry(appId) {
        const target = `${String(appId)}.desktop`;
        const values = Array.from(DesktopEntries.applications.values || []);
        return values.find(entry => String(entry.id || "") === target || String(entry.id || "") === String(appId)) || null;
    }

    function appName(app) {
        return String(desktopEntry(app.id)?.name || app.name || app.id);
    }

    function appIcon(app) {
        return String(desktopEntry(app.id)?.icon || "application-x-executable");
    }

    function context(app, layer) {
        return app?.[layer]?.context || {};
    }

    function listValue(value) {
        return String(value || "").split(";").filter(item => item.length > 0);
    }

    function hasContext(app, key) {
        return listValue(context(app, "effective")[key]).length > 0;
    }

    function portalFor(app) {
        return (AppPermissions.portalEntries || []).filter(entry => entry.appId === app.id);
    }

    SettingsGroup {
        title: Translation.tr("APP PERMISSIONS")

        SettingsRow {
            icon: "admin_panel_settings"
            title: Translation.tr("Application permissions")
            description: Translation.tr("Permissions managed by application sandboxes and desktop portals.")
            registerInSearch: false
        }

        SettingsRow {
            icon: "refresh"
            title: Translation.tr("Refresh")
            description: AppPermissions.loading
                ? Translation.tr("Reading Flatpak and portal state…")
                : Translation.tr("Reload permission information.")
            registerInSearch: false
            DialogButton {
                buttonText: AppPermissions.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !AppPermissions.loading
                onClicked: AppPermissions.refresh()
            }
        }

        SettingsStateRow {
            statusState: "loading"
            stateTitle: Translation.tr("Loading permissions…")
            stateDescription: Translation.tr("Reading installed sandbox and portal metadata.")
            visible: AppPermissions.loading
        }

        Repeater {
            model: AppPermissions.flatpakApps
            SettingsRow {
                required property var modelData
                iconSource: Quickshell.iconPath(root.appIcon(modelData), "image-missing")
                title: root.appName(modelData)
                description: Translation.tr("Flatpak") + ` · ${modelData.id}`
                clickable: true
                registerInSearch: false
                onClicked: root.selectedApp = modelData
                MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        SettingsStateRow {
            statusState: "empty"
            stateTitle: Translation.tr("No managed app permissions")
            stateDescription: Translation.tr("No installed Flatpak applications with sandbox permissions were found.")
            visible: AppPermissions.ready && AppPermissions.flatpakApps.length === 0
        }

        SettingsRow {
            icon: "info"
            title: Translation.tr("Native applications")
            description: Translation.tr("Most system applications are not sandboxed and do not have centrally managed per-app permissions.")
            registerInSearch: false
        }

        SettingsRow {
            visible: AppPermissions.ready && AppPermissions.portalHealth.hyprland !== "active"
            icon: "warning"
            title: Translation.tr("Some desktop portal permissions are unavailable")
            description: Translation.tr("Screen capture and related portal capabilities may not be available right now.")
            registerInSearch: false
        }
    }

    SettingsRow {
        visible: AppPermissions.ready && AppPermissions.stalePortalEntries.length > 0
        icon: "history"
        title: Translation.tr("Stored permissions for uninstalled apps")
        description: Translation.tr("%1 stored portal permission(s) belong to applications that are no longer installed.").arg(AppPermissions.stalePortalEntries.length)
        registerInSearch: false
    }

    SettingsStateRow {
        statusState: "error"
        stateTitle: Translation.tr("Permission information unavailable")
        stateDescription: AppPermissions.error
        visible: AppPermissions.ready && AppPermissions.error.length > 0
    }

    SettingsGroup {
        visible: root.selectedApp !== null
        title: root.selectedApp ? root.appName(root.selectedApp) : ""

        SettingsRow {
            iconSource: root.selectedApp ? Quickshell.iconPath(root.appIcon(root.selectedApp), "image-missing") : ""
            title: root.selectedApp ? root.appName(root.selectedApp) : ""
            description: root.selectedApp ? `${Translation.tr("Flatpak")} · ${root.selectedApp.id}` : ""
            registerInSearch: false
        }

        SettingsRow {
            title: Translation.tr("Network access")
            description: root.selectedApp && root.hasContext(root.selectedApp, "shared") && root.listValue(root.context(root.selectedApp, "effective").shared).includes("network")
                ? Translation.tr("Allowed")
                : Translation.tr("Not shared")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.selectedApp && root.hasContext(root.selectedApp, "devices")
            title: Translation.tr("Device access")
            description: root.listValue(root.context(root.selectedApp, "effective").devices).join(", ")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.selectedApp && root.hasContext(root.selectedApp, "sockets")
            title: Translation.tr("Display access")
            description: root.listValue(root.context(root.selectedApp, "effective").sockets).filter(value => value === "wayland" || value === "fallback-x11").map(value => value === "fallback-x11" ? Translation.tr("X11 fallback") : Translation.tr("Wayland")).join(", ")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.selectedApp && root.hasContext(root.selectedApp, "persistent")
            title: Translation.tr("Persistent sandbox storage")
            description: root.listValue(root.context(root.selectedApp, "effective").persistent).join(", ")
            registerInSearch: false
        }

        SettingsRow {
            visible: root.selectedApp && root.portalFor(root.selectedApp).length === 0
            title: Translation.tr("Portal permissions")
            description: Translation.tr("No remembered portal permissions")
            registerInSearch: false
        }

        Repeater {
            model: root.selectedApp ? root.portalFor(root.selectedApp) : []
            SettingsRow {
                required property var modelData
                title: modelData.table
                description: `${modelData.id}: ${modelData.value}`
                registerInSearch: false
            }
        }

        SettingsRow {
            visible: root.selectedApp && Object.keys(root.selectedApp?.effective?.sessionBusPolicy || {}).length > 0
            title: Translation.tr("Advanced sandbox permissions")
            description: Translation.tr("D-Bus access: %1 service entries").arg(Object.keys(root.selectedApp?.effective?.sessionBusPolicy || {}).length)
            registerInSearch: false
        }
    }
}
