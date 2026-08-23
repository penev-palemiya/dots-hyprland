import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    SettingsGroup {
        title: Translation.tr("OVERVIEW")

        SettingsToggleRow {
            icon: "overview"
            title: Translation.tr("Show workspace overview")
            description: Translation.tr("Show workspaces and open windows when Overview opens")
            checked: Config.options.overview.enable
            onToggled: checked => Config.options.overview.enable = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("WINDOW PREVIEWS")

        SettingsToggleRow {
            icon: "center_focus_strong"
            title: Translation.tr("Center application icons")
            description: Config.options.overview.enable
                ? Translation.tr("Place application icons in the center of window previews")
                : Translation.tr("Enable the workspace overview to use this option")
            checked: Config.options.overview.centerIcons
            enabled: Config.options.overview.enable
            onToggled: checked => Config.options.overview.centerIcons = checked
        }
    }
}
