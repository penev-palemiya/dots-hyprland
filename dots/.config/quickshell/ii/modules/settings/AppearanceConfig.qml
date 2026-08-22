import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property bool themeChanging: themeProcess.running
    property string themeError: ""

    function setTheme(dark) {
        if (themeProcess.running)
            return;

        root.themeError = "";
        themeProcess.dark = dark;
        themeProcess.running = true;
    }

    Process {
        id: themeProcess

        property bool dark: Appearance.m3colors.darkmode
        command: [Directories.wallpaperSwitchScriptPath, "--mode", dark ? "dark" : "light", "--noswitch", "--shell-only"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.themeError = Translation.tr("Could not change the shell color scheme.");
        }
    }

    SettingsGroup {
        title: Translation.tr("Appearance")

        SettingsRow {
            icon: "contrast"
            title: Translation.tr("Color scheme")
            description: root.themeError.length > 0
                ? root.themeError
                : Translation.tr("Changes the shell appearance.")

            ConfigSelectionArray {
                enabled: !root.themeChanging
                currentValue: Appearance.m3colors.darkmode ? "dark" : "light"
                onSelected: newValue => root.setTheme(newValue === "dark")
                options: [
                    {
                        displayName: Translation.tr("Light"),
                        icon: "light_mode",
                        value: "light"
                    },
                    {
                        displayName: Translation.tr("Dark"),
                        icon: "dark_mode",
                        value: "dark"
                    }
                ]
            }
        }

        SettingsToggleRow {
            icon: "opacity"
            title: Translation.tr("Transparency")
            description: Translation.tr("Use transparent shell surfaces where supported.")
            checked: Config.options.appearance.transparency.enable
            onToggled: checked => Config.options.appearance.transparency.enable = checked
        }

        SettingsRow {
            visible: root.themeChanging
            icon: "progress_activity"
            title: Translation.tr("Applying color scheme")
            description: Translation.tr("Updating the shell palette…")
            registerInSearch: false
        }
    }
}
