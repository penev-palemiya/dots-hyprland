import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components
import qs.services

SettingsSubPage {
    id: root

    Component.onCompleted: Diagnostics.refresh()

    SettingsGroup {
        title: Translation.tr("Diagnostics")

        SettingsRow {
            icon: Diagnostics.loading ? "sync" : Diagnostics.issueCount > 0 ? "warning" : "check_circle"
            title: Diagnostics.loading
                ? Translation.tr("Checking…")
                : Diagnostics.error.length > 0
                    ? Translation.tr("Snapshot unavailable")
                    : Diagnostics.overallText
            description: Diagnostics.error.length > 0
                ? Diagnostics.error
                : Translation.tr("Read-only local subsystem health")

            DialogButton {
                buttonText: Diagnostics.loading ? Translation.tr("Checking…") : Translation.tr("Refresh")
                enabled: !Diagnostics.loading
                onClicked: Diagnostics.refresh()
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("System")

        Repeater {
            model: Diagnostics.checks.filter(item => ["Shell", "Compositor", "Configuration"].includes(item.name))

            delegate: SettingsRow {
                required property var modelData
                icon: modelData.name === "Shell" ? "terminal" : modelData.name === "Compositor" ? "desktop_windows" : "settings"
                title: modelData.name
                description: Diagnostics.rowDescription(modelData)
                registerInSearch: false
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Services")

        Repeater {
            model: Diagnostics.checks.filter(item => !["Shell", "Compositor", "Configuration"].includes(item.name))

            delegate: SettingsRow {
                required property var modelData
                icon: modelData.name === "Desktop portals" ? "account_tree"
                    : modelData.name === "Audio" ? "volume_up"
                    : modelData.name === "Network" ? "lan"
                    : modelData.name === "Bluetooth" ? "bluetooth"
                    : modelData.name === "Update backend" ? "system_update" : "settings"
                title: modelData.name
                description: Diagnostics.rowDescription(modelData)
                registerInSearch: false
            }
        }
    }
}
