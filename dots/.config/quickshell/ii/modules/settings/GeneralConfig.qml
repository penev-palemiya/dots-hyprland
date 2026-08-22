import QtQuick
import Quickshell
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsPage {
    pageTitle: Translation.tr("General")

    SettingsGroup {
        title: Translation.tr("Battery")

        SettingsRow {
            icon: "warning"
            title: Translation.tr("Low warning")
            description: Translation.tr("Battery percentage at which the first warning appears.")
            keywords: "battery percent"

            StyledSpinBox {
                value: Config.options.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: Config.options.battery.low = value
            }
        }

        SettingsRow {
            icon: "dangerous"
            title: Translation.tr("Critical warning")
            description: Translation.tr("Battery percentage at which an urgent warning appears.")
            keywords: "battery percent"

            StyledSpinBox {
                value: Config.options.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: Config.options.battery.critical = value
            }
        }

        SettingsRow {
            icon: "charger"
            title: Translation.tr("Full warning")
            description: Translation.tr("Tells you when the battery reaches this level, so you can unplug.")
            keywords: "battery percent charge"

            StyledSpinBox {
                value: Config.options.battery.full
                from: 0
                to: 101
                stepSize: 5
                onValueChanged: Config.options.battery.full = value
            }
        }

        SettingsToggleRow {
            icon: "pause"
            title: Translation.tr("Automatic suspend")
            description: Translation.tr("Suspends the system on its own once the battery gets critically low.")
            keywords: "sleep power"
            checked: Config.options.battery.automaticSuspend
            onToggled: checked => Config.options.battery.automaticSuspend = checked
        }

        SettingsSubRow {
            title: Translation.tr("Suspend at")
            description: Translation.tr("Battery percentage that triggers the automatic suspend.")
            enabled: Config.options.battery.automaticSuspend

            StyledSpinBox {
                value: Config.options.battery.suspend
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: Config.options.battery.suspend = value
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Language")

        SettingsRow {
            icon: "language"
            title: Translation.tr("Interface language")
            description: Translation.tr("Language used across the shell. \"Auto\" follows your system locale.")
            keywords: "locale translation"

            StyledComboBox {
                textRole: "displayName"

                model: [
                    {
                        displayName: Translation.tr("Auto (System)"),
                        value: "auto"
                    },
                    ...Translation.allAvailableLanguages.map(lang => {
                        return {
                            displayName: Translation.friendlyLanguageName(lang),
                            value: lang
                        };
                    })]

                currentIndex: {
                    const index = model.findIndex(item => item.value === Config.options.language.ui);
                    return index !== -1 ? index : 0;
                }

                onActivated: index => Config.options.language.ui = model[index].value
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Sounds")

        SettingsToggleRow {
            icon: "battery_android_full"
            title: Translation.tr("Battery sounds")
            description: Translation.tr("Play a sound for battery warnings.")
            checked: Config.options.sounds.battery
            onToggled: checked => Config.options.sounds.battery = checked
        }

        SettingsToggleRow {
            icon: "av_timer"
            title: Translation.tr("Pomodoro sounds")
            description: Translation.tr("Play a sound when a Pomodoro interval ends.")
            checked: Config.options.sounds.pomodoro
            onToggled: checked => Config.options.sounds.pomodoro = checked
        }

        SettingsToggleRow {
            icon: "hourglass_bottom"
            title: Translation.tr("Countdown timer sounds")
            description: Translation.tr("Play a sound when a countdown timer finishes.")
            checked: Config.options.sounds.countdownTimer
            onToggled: checked => Config.options.sounds.countdownTimer = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("Time")

        SettingsToggleRow {
            icon: "pace"
            title: Translation.tr("Second precision")
            description: Translation.tr("Show seconds on clocks and update them every second.")
            keywords: "clock seconds"
            checked: Config.options.time.secondPrecision
            onToggled: checked => Config.options.time.secondPrecision = checked
        }

        SettingsRow {
            icon: "schedule"
            title: Translation.tr("Time format")
            description: Translation.tr("How the time is written across the shell and lock screen.")
            keywords: "24h 12h am pm clock"

            ConfigSelectionArray {
                currentValue: Config.options.time.format
                onSelected: newValue => {
                    // The lock screen reads its format from hyprlock.conf, so keep
                    // that file in step with the choice made here.
                    if (newValue === "hh:mm") {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    } else {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    }

                    Config.options.time.format = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("24h"),
                        value: "hh:mm"
                    },
                    {
                        displayName: Translation.tr("12h am/pm"),
                        value: "h:mm ap"
                    },
                    {
                        displayName: Translation.tr("12h AM/PM"),
                        value: "h:mm AP"
                    },
                ]
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Work safety")

        SettingsToggleRow {
            icon: "assignment"
            title: Translation.tr("Hide clipboard images copied from sussy sources")
            description: Translation.tr("Blurs clipboard image previews that came from flagged sites, but only while you're on a public network.")
            keywords: "nsfw privacy clipboard"
            checked: Config.options.workSafety.enable.clipboard
            onToggled: checked => Config.options.workSafety.enable.clipboard = checked
        }
    }
}
