import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: barPage

    function activeScreenNames() {
        return Quickshell.screens.map(screen => screen.name);
    }

    function selectAllDisplays() {
        Config.options.bar.screenList = [];
    }

    function selectCurrentDisplays() {
        const names = barPage.activeScreenNames();
        if (names.length > 0)
            Config.options.bar.screenList = names;
    }

    ContentSection {
        icon: "spoke"
        title: Translation.tr("BAR")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Position")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.bar.bottom ? 1 : 0
                    onSelected: newValue => {
                        Config.options.bar.bottom = newValue === 1;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Auto-hide")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: newValue => {
                        Config.options.bar.autoHide.enable = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Show on displays")
                tooltip: Translation.tr("All displays follows the active monitor set. Selected displays keeps named connectors until you change them.")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (Config.options.bar.screenList ?? []).length === 0 ? 0 : 1
                    onSelected: newValue => {
                        if (newValue === 0)
                            barPage.selectAllDisplays();
                        else
                            barPage.selectCurrentDisplays();
                    }
                    options: [
                        {
                            displayName: Translation.tr("All displays"),
                            icon: "select_all",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Selected displays"),
                            icon: "checklist",
                            value: 1
                        }
                    ]
                }

                ColumnLayout {
                    visible: (Config.options.bar.screenList ?? []).length > 0
                    Layout.fillWidth: true
                    spacing: 2

                    Repeater {
                        model: Quickshell.screens

                        delegate: ConfigSwitch {
                            required property ShellScreen modelData
                            Layout.fillWidth: true
                            buttonIcon: "monitor"
                            text: modelData.name
                            checked: (Config.options.bar.screenList ?? []).includes(modelData.name)
                            onCheckedChanged: {
                                const selected = Config.options.bar.screenList ?? [];
                                if (checked) {
                                    if (!selected.includes(modelData.name))
                                        Config.options.bar.screenList = selected.concat([modelData.name]);
                                } else if (selected.length > 1) {
                                    Config.options.bar.screenList = selected.filter(name => name !== modelData.name);
                                } else {
                                    checked = true;
                                }
                            }
                        }
                    }

                    StyledText {
                        visible: {
                            const active = Quickshell.screens.map(screen => screen.name);
                            return (Config.options.bar.screenList ?? []).some(name => !active.includes(name));
                        }
                        Layout.fillWidth: true
                        text: Translation.tr("Unavailable displays remain selected until you change this setting.")
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Background")
                Layout.fillWidth: false

                ConfigSwitch {
                    buttonIcon: "layers"
                    text: Translation.tr("Show background")
                    checked: Config.options.bar.showBackground
                    onCheckedChanged: Config.options.bar.showBackground = checked
                }
            }
        }

    }

    ContentSection {
        icon: "widgets"
        title: Translation.tr("BAR ITEMS")

        ConfigSwitch {
            buttonIcon: "calendar_month"
            text: Translation.tr("Show date")
            checked: Config.options.bar.verbose
            onCheckedChanged: Config.options.bar.verbose = checked
        }

        ConfigSwitch {
            buttonIcon: "cloud"
            text: Translation.tr("Weather")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: Config.options.bar.weather.enable = checked
        }

        ConfigSwitch {
            buttonIcon: "notifications"
            text: Translation.tr("Show notification count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: Config.options.bar.indicators.notifications.showUnreadCount = checked
        }
    }

    ContentSection {
        icon: "shelf_auto_hide"
        title: Translation.tr("SYSTEM TRAY")

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr('Make icons pinned by default')
            checked: Config.options.tray.invertPinnedItems
            onCheckedChanged: {
                Config.options.tray.invertPinnedItems = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint icons')
            checked: Config.options.tray.monochromeIcons
            onCheckedChanged: {
                Config.options.tray.monochromeIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility_off"
            text: Translation.tr("Hide passive icons")
            checked: Config.options.tray.filterPassive
            onCheckedChanged: Config.options.tray.filterPassive = checked
        }

        ContentSubsection {
            title: Translation.tr("Pinned icons")
            tooltip: Translation.tr("Pinned icons stay visible. Unpinned icons remain available in the tray overflow.")

            Repeater {
                model: ScriptModel {
                    values: SystemTray.items.values
                }

                delegate: SettingsRow {
                    required property SystemTrayItem modelData
                    icon: "apps"
                    title: modelData.title.length > 0 ? modelData.title : modelData.id
                    description: modelData.id
                    registerInSearch: false

                    IconImage {
                        width: 22
                        height: 22
                        source: modelData.icon
                    }

                    ConfigSwitch {
                        buttonIcon: "keep"
                        text: TrayService.isPinned(modelData.id) ? Translation.tr("Pinned") : Translation.tr("Unpinned")
                        checked: TrayService.isPinned(modelData.id)
                        onCheckedChanged: {
                            if (checked !== TrayService.isPinned(modelData.id))
                                TrayService.togglePin(modelData.id);
                        }
                    }
                }
            }
        }
    }

}
