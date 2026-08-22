import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    function iconFor(appId) {
        return Quickshell.iconPath(AppSearch.guessIcon(appId), "image-missing");
    }

    function nameFor(appId, entry) {
        return entry?.name || appId;
    }

    function windowText(count) {
        return count === 1
            ? Translation.tr("1 window")
            : Translation.tr("%1 windows").arg(count);
    }

    function windowCount(appId) {
        const app = TaskbarApps.apps.find(entry => entry.appId === String(appId).toLowerCase());
        return app?.toplevels.length ?? 0;
    }

    property var runningApps: TaskbarApps.apps.filter(app => app.appId !== "SEPARATOR" && !app.pinned)

    SettingsGroup {
        title: Translation.tr("DOCK")

        SettingsToggleRow {
            icon: Config.options.dock.enable ? "dock_to_bottom" : "dock_to_bottom"
            title: Translation.tr("Enable Dock")
            description: Config.options.dock.enable
                ? Translation.tr("The Dock is visible on the active screens")
                : Translation.tr("The Dock is disabled; application pins can still be edited below")
            checked: Config.options.dock.enable
            onToggled: checked => Config.options.dock.enable = checked
        }

        SettingsToggleRow {
            icon: "highlight_mouse_cursor"
            title: Translation.tr("Reveal on pointer hover")
            description: Translation.tr("Show the Dock when the pointer reaches the screen edge")
            checked: Config.options.dock.hoverToReveal
            onToggled: checked => Config.options.dock.hoverToReveal = checked
        }

        SettingsToggleRow {
            icon: "keep"
            title: Translation.tr("Start pinned")
            description: Translation.tr("Keep the Dock revealed when it is created")
            checked: Config.options.dock.pinnedOnStartup
            onToggled: checked => Config.options.dock.pinnedOnStartup = checked
        }

        SettingsToggleRow {
            icon: "colors"
            title: Translation.tr("Monochrome app icons")
            description: Translation.tr("Tint Dock application icons with the current shell color")
            checked: Config.options.dock.monochromeIcons
            onToggled: checked => Config.options.dock.monochromeIcons = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("PINNED APPLICATIONS")

        Repeater {
            model: Config.options.dock.pinnedApps ?? []

            delegate: SettingsRow {
                required property string modelData
                property var desktopEntry: DesktopEntries.heuristicLookup(modelData)
                icon: desktopEntry ? "" : "apps"
                iconSource: desktopEntry ? root.iconFor(modelData) : ""
                title: root.nameFor(modelData, desktopEntry)
                description: desktopEntry
                    ? root.windowCount(modelData) > 0
                        ? Translation.tr("Pinned · %1").arg(root.windowText(root.windowCount(modelData)))
                        : Translation.tr("Pinned · Not running")
                    : Translation.tr("Unavailable")

                RippleButton {
                    text: Translation.tr("Unpin")
                    implicitWidth: Math.max(76, implicitContentWidth + 24)
                    implicitHeight: 38
                    onClicked: TaskbarApps.togglePin(modelData)
                }
            }
        }

        SettingsRow {
            visible: (Config.options.dock.pinnedApps ?? []).length === 0
            icon: "push_pin"
            title: Translation.tr("No pinned applications")
            description: Translation.tr("Pin a running application below to show it in the Dock")
            registerInSearch: false
        }
    }

    SettingsGroup {
        title: Translation.tr("RUNNING APPLICATIONS")

        Repeater {
            model: root.runningApps

            delegate: SettingsRow {
                required property var modelData
                property var desktopEntry: DesktopEntries.heuristicLookup(modelData.appId)
                icon: desktopEntry ? "" : "apps"
                iconSource: desktopEntry ? root.iconFor(modelData.appId) : ""
                title: root.nameFor(modelData.appId, desktopEntry)
                description: Translation.tr("Running · %1").arg(root.windowText(modelData.toplevels.length))

                RippleButton {
                    text: Translation.tr("Pin")
                    implicitWidth: Math.max(68, implicitContentWidth + 24)
                    implicitHeight: 38
                    onClicked: TaskbarApps.togglePin(modelData.appId)
                }
            }
        }

        SettingsRow {
            visible: root.runningApps.length === 0
            icon: "check_circle"
            title: Translation.tr("No other applications are running")
            description: Translation.tr("Running applications will appear here and can be pinned to the Dock")
            registerInSearch: false
        }
    }
}
