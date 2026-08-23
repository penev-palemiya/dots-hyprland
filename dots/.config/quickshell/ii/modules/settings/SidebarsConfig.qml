import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    SettingsGroup {
        title: Translation.tr("PERFORMANCE")

        SettingsToggleRow {
            icon: "speed"
            title: Translation.tr("Keep right sidebar ready")
            description: Translation.tr("Keep its content loaded for faster opening. Uses more memory while closed.")
            checked: Config.options.sidebar.keepRightSidebarLoaded
            onToggled: checked => Config.options.sidebar.keepRightSidebarLoaded = checked
        }
    }
}
