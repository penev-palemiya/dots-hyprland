import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    SettingsGroup {
        title: Translation.tr("Security")

        SettingsToggleRow {
            icon: "settings_power"
            title: Translation.tr("Require authentication for power actions")
            description: Translation.tr("Require lock authentication before powering off or restarting.")
            checked: Config.options.lock.security.requirePasswordToPower
            onToggled: checked => Config.options.lock.security.requirePasswordToPower = checked
        }

        SettingsToggleRow {
            icon: "key_vertical"
            title: Translation.tr("Unlock keyring after authentication")
            description: Translation.tr("Unlock the keyring after a successful lock-screen authentication.")
            checked: Config.options.lock.security.unlockKeyring
            onToggled: checked => Config.options.lock.security.unlockKeyring = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("Status")

        SettingsRow {
            icon: "lock"
            title: Translation.tr("Lock screen backend")
            description: Config.options.lock.useHyprlock ? Translation.tr("Hyprlock") : Translation.tr("Quickshell")
            registerInSearch: false
        }

        SettingsRow {
            icon: "password"
            title: Translation.tr("Authentication")
            description: Translation.tr("Password authentication available")
            registerInSearch: false
        }

        SettingsRow {
            icon: "schedule"
            title: Translation.tr("Automatic locking")
            description: Translation.tr("Managed in Power & Battery")
            registerInSearch: false
        }
    }
}
