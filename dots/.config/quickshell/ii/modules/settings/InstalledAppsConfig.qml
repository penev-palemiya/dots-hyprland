import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property string query: ""
    property var selectedApp: null

    readonly property var filteredApps: {
        const needle = root.query.trim().toLowerCase();
        if (!needle)
            return InstalledApps.apps;
        return InstalledApps.apps.filter(app => String(app.searchText || "").includes(needle));
    }

    Component.onCompleted: InstalledApps.refresh()

    function detailValue(value) {
        return value ? String(value) : Translation.tr("Not available");
    }

    SettingsGroup {
        title: Translation.tr("INSTALLED APPS")

        SettingsRow {
            icon: "search"
            title: Translation.tr("Search applications")
            description: root.query.length > 0
                ? Translation.tr("Showing %1 matching applications").arg(root.filteredApps.length)
                : Translation.tr("Search by name, description, package, or app ID.")

            MaterialTextField {
                Layout.preferredWidth: 280
                placeholderText: Translation.tr("Search")
                text: root.query
                onTextChanged: root.query = text
            }
        }

        SettingsRow {
            icon: "refresh"
            title: Translation.tr("Refresh")
            description: InstalledApps.loading
                ? Translation.tr("Reading local application metadata…")
                : Translation.tr("Reload the installed application inventory.")
            registerInSearch: false

            DialogButton {
                buttonText: InstalledApps.loading ? Translation.tr("Refreshing…") : Translation.tr("Refresh")
                enabled: !InstalledApps.loading
                onClicked: InstalledApps.refresh()
            }
        }

        SettingsRow {
            visible: InstalledApps.loading
            icon: "hourglass_top"
            title: Translation.tr("Loading installed applications…")
            description: Translation.tr("Reading local package and Flatpak metadata.")
            registerInSearch: false
        }

        SettingsRow {
            visible: !InstalledApps.loading && InstalledApps.ready && root.filteredApps.length === 0
            icon: "search_off"
            title: root.query.length > 0 ? Translation.tr("No matching applications") : Translation.tr("No installed applications found")
            description: root.query.length > 0 ? Translation.tr("Try a different search.") : Translation.tr("No visible desktop applications were detected.")
            registerInSearch: false
        }

        Repeater {
            model: root.filteredApps

            SettingsRow {
                required property var modelData
                iconSource: Quickshell.iconPath(modelData.icon || "application-x-executable", "image-missing")
                title: modelData.displayName
                description: modelData.sourceLabel + (modelData.description ? ` · ${modelData.description}` : "")
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
    }

    SettingsRow {
        visible: InstalledApps.error.length > 0
        icon: "error_outline"
        title: Translation.tr("Installed application inventory unavailable")
        description: InstalledApps.error
        registerInSearch: false
    }

    SettingsGroup {
        visible: root.selectedApp !== null
        title: root.selectedApp?.displayName || Translation.tr("Application details")

        SettingsRow {
            iconSource: root.selectedApp ? Quickshell.iconPath(root.selectedApp.icon || "application-x-executable", "image-missing") : ""
            title: root.selectedApp?.displayName || ""
            description: root.selectedApp?.sourceLabel || ""
            registerInSearch: false
        }
        SettingsRow { visible: !!root.selectedApp?.version; title: Translation.tr("Version"); description: root.detailValue(root.selectedApp?.version); registerInSearch: false }
        SettingsRow { visible: !!root.selectedApp?.installedSize; title: Translation.tr("Installed size"); description: root.detailValue(root.selectedApp?.installedSize); registerInSearch: false }
        SettingsRow { visible: !!root.selectedApp?.installDate; title: Translation.tr("Installed"); description: root.detailValue(root.selectedApp?.installDate); registerInSearch: false }
        SettingsRow { visible: !!root.selectedApp?.packageId; title: Translation.tr("Package"); description: root.detailValue(root.selectedApp?.packageId); registerInSearch: false }
        SettingsRow { visible: !!root.selectedApp?.appId; title: Translation.tr("Application ID"); description: root.detailValue(root.selectedApp?.appId); registerInSearch: false }
        SettingsRow { visible: !!root.selectedApp?.description; title: Translation.tr("Description"); description: root.detailValue(root.selectedApp?.description); registerInSearch: false }
        SettingsRow {
            visible: (root.selectedApp?.desktopEntries?.length || 0) > 0
            title: Translation.tr("Launchers")
            description: (root.selectedApp?.desktopEntries || []).map(entry => entry.name).join(" · ")
            registerInSearch: false
        }
    }
}
