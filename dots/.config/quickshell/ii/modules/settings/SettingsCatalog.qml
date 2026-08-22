import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsPage {
    id: root

    property string pageKey: ""
    property var menuEntries: []

    subPages: root.menuEntries.map(entry => ({
        key: entry.key,
        title: entry.name,
        content: root.contentForKey(entry.key)
    }))

    function contentForKey(key) {
        switch (key) {
        case "system-displays": return displaysPage;
        case "system-sound": return soundPage;
        case "system-power-battery": return powerBatteryPage;
        case "system-notifications": return notificationsPage;
        case "system-date-time": return dateTimePage;
        case "system-language-region": return languageRegionPage;
        case "personalization-colors": return colorsPage;
        case "search-tools-search": return searchPage;
        case "search-tools-clipboard": return clipboardPage;
        case "search-tools-screenshots": return screenshotsPage;
        case "search-tools-screen-recording": return screenRecordingPage;
        case "search-tools-translator": return translatorPage;
        case "search-tools-other": return otherToolsPage;
        case "privacy-security-location": return locationPage;
        case "advanced-diagnostics": return diagnosticsPage;
        case "advanced-configuration": return configurationPage;
        case "about-support": return supportPage;
        case "about-legal": return legalPage;
        default: return placeholderPage;
        }
    }

    Component {
        id: displaysPage
        DisplaysConfig {}
    }

    SettingsGroup {
        title: Translation.tr("Sections")

        Repeater {
            model: root.menuEntries

            SettingsNavRow {
                required property var modelData

                icon: modelData.icon ?? "settings"
                title: modelData.name
                description: Translation.tr("Open section")
                onClicked: root.openSubPage(modelData.key)
            }
        }
    }

    Component {
        id: placeholderPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Pending")

                SettingsRow {
                    icon: "pending"
                    title: Translation.tr("No migrated settings yet")
                    description: Translation.tr("This destination exists in the new menu schema. Its existing controls will be moved here in the next migration pass.")
                    registerInSearch: false
                }
            }
        }
    }

    Component {
        id: soundPage
        SoundConfig {}
    }

    Component {
        id: powerBatteryPage
        PowerBatteryConfig {}
    }

    Component {
        id: notificationsPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Notification behavior")

                SettingsRow {
                    icon: "timer"
                    title: Translation.tr("Timeout duration")
                    description: Translation.tr("How long notifications stay visible.")
                    keywords: "notifications timeout"

                    StyledSpinBox {
                        value: Config.options.notifications.timeout
                        from: 1000
                        to: 30000
                        stepSize: 500
                        onValueChanged: Config.options.notifications.timeout = value
                    }
                }

                SettingsToggleRow {
                    icon: "monitor"
                    title: Translation.tr("Force specific monitor")
                    description: Translation.tr("Always show notifications on the configured monitor.")
                    checked: Config.options.notifications.monitor.enable
                    onToggled: checked => Config.options.notifications.monitor.enable = checked
                }

                SettingsRow {
                    icon: "display_settings"
                    title: Translation.tr("Monitor name to show notifications on")
                    description: Translation.tr("Monitor name used when forced notification placement is enabled.")
                    enabled: Config.options.notifications.monitor.enable

                    MaterialTextArea {
                        Layout.preferredWidth: 240
                        implicitHeight: 42
                        text: Config.options.notifications.monitor.name
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.notifications.monitor.name = text
                    }
                }
            }
        }
    }

    Component {
        id: dateTimePage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Clock")

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
                            if (newValue === "hh:mm") {
                                Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                            } else {
                                Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                            }
                            Config.options.time.format = newValue;
                        }
                        options: [
                            { displayName: Translation.tr("24h"), value: "hh:mm" },
                            { displayName: Translation.tr("12h am/pm"), value: "h:mm ap" },
                            { displayName: Translation.tr("12h AM/PM"), value: "h:mm AP" }
                        ]
                    }
                }
            }
        }
    }

    Component {
        id: languageRegionPage

        SettingsSubPage {
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
                            { displayName: Translation.tr("Auto (System)"), value: "auto" },
                            ...Translation.allAvailableLanguages.map(lang => ({
                                displayName: Translation.friendlyLanguageName(lang),
                                value: lang
                            }))
                        ]
                        currentIndex: {
                            const index = model.findIndex(item => item.value === Config.options.language.ui);
                            return index !== -1 ? index : 0;
                        }
                        onActivated: index => Config.options.language.ui = model[index].value
                    }
                }
            }
        }
    }

    Component {
        id: colorsPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Palette")

                SettingsRow {
                    icon: "colors"
                    title: Translation.tr("Colour palette style")
                    description: Translation.tr("Material You palette algorithm used when generating shell colors.")
                    keywords: "color palette material you"

                    ConfigSelectionArray {
                        currentValue: Config.options.appearance.palette.type
                        onSelected: newValue => {
                            Config.options.appearance.palette.type = newValue;
                            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
                        }
                        options: [
                            { value: "auto", displayName: Translation.tr("Auto") },
                            { value: "scheme-content", displayName: Translation.tr("Content") },
                            { value: "scheme-expressive", displayName: Translation.tr("Expressive") },
                            { value: "scheme-fidelity", displayName: Translation.tr("Fidelity") },
                            { value: "scheme-fruit-salad", displayName: Translation.tr("Fruit Salad") },
                            { value: "scheme-monochrome", displayName: Translation.tr("Monochrome") },
                            { value: "scheme-neutral", displayName: Translation.tr("Neutral") },
                            { value: "scheme-rainbow", displayName: Translation.tr("Rainbow") },
                            { value: "scheme-tonal-spot", displayName: Translation.tr("Tonal Spot") }
                        ]
                    }
                }
            }
        }
    }

    Component {
        id: searchPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Matching")

                SettingsToggleRow {
                    icon: "manage_search"
                    title: Translation.tr("Use Levenshtein instead of fuzzy")
                    description: Translation.tr("Use distance-based matching for typo-heavy searches.")
                    checked: Config.options.search.sloppy
                    onToggled: checked => Config.options.search.sloppy = checked
                }
            }

            SettingsGroup {
                title: Translation.tr("Prefixes")

                SettingsRow {
                    icon: "bolt"
                    title: Translation.tr("Action prefix")
                    description: Translation.tr("Prefix for shell actions in search.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.action
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.action = text
                    }
                }

                SettingsRow {
                    icon: "content_paste"
                    title: Translation.tr("Clipboard prefix")
                    description: Translation.tr("Prefix for clipboard search.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.clipboard
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.clipboard = text
                    }
                }

                SettingsRow {
                    icon: "mood"
                    title: Translation.tr("Emojis prefix")
                    description: Translation.tr("Prefix for emoji search.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.emojis
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.emojis = text
                    }
                }

                SettingsRow {
                    icon: "calculate"
                    title: Translation.tr("Math prefix")
                    description: Translation.tr("Prefix for calculator queries.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.math
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.math = text
                    }
                }

                SettingsRow {
                    icon: "terminal"
                    title: Translation.tr("Shell command prefix")
                    description: Translation.tr("Prefix for running shell commands from search.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.shellCommand
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.shellCommand = text
                    }
                }

                SettingsRow {
                    icon: "travel_explore"
                    title: Translation.tr("Web search prefix")
                    description: Translation.tr("Prefix for sending a query to the configured web search URL.")

                    MaterialTextArea {
                        Layout.preferredWidth: 140
                        implicitHeight: 42
                        text: Config.options.search.prefix.webSearch
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.prefix.webSearch = text
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Web search")

                SettingsRow {
                    icon: "link"
                    title: Translation.tr("Base URL")
                    description: Translation.tr("Search URL template used by the web-search action.")

                    MaterialTextArea {
                        Layout.preferredWidth: 280
                        implicitHeight: 42
                        text: Config.options.search.engineBaseUrl
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.search.engineBaseUrl = text
                    }
                }
            }
        }
    }

    Component {
        id: clipboardPage

        SettingsSubPage {
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
    }

    Component {
        id: screenshotsPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Save path")

                SettingsRow {
                    icon: "folder"
                    title: Translation.tr("Screenshot Path")
                    description: Translation.tr("Where screenshots are saved. Leave empty to only copy.")

                    MaterialTextArea {
                        Layout.preferredWidth: 280
                        implicitHeight: 42
                        text: Config.options.screenSnip.savePath
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.screenSnip.savePath = text
                    }
                }
            }
        }
    }

    Component {
        id: screenRecordingPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Save path")

                SettingsRow {
                    icon: "folder"
                    title: Translation.tr("Video Recording Path")
                    description: Translation.tr("Where screen recordings are saved.")

                    MaterialTextArea {
                        Layout.preferredWidth: 280
                        implicitHeight: 42
                        text: Config.options.screenRecord.savePath
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.screenRecord.savePath = text
                    }
                }
            }
        }
    }

    Component {
        id: translatorPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Translator")

                SettingsToggleRow {
                    icon: "translate"
                    title: Translation.tr("Enable translator")
                    description: Translation.tr("Enable the shell translator tool.")
                    checked: Config.options.sidebar.translator.enable
                    onToggled: checked => Config.options.sidebar.translator.enable = checked
                }
            }
        }
    }

    Component {
        id: otherToolsPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Music recognition")

                SettingsRow {
                    icon: "timer_off"
                    title: Translation.tr("Total duration timeout")
                    description: Translation.tr("Maximum time to listen while recognizing music.")

                    StyledSpinBox {
                        value: Config.options.musicRecognition.timeout
                        from: 10
                        to: 100
                        stepSize: 2
                        onValueChanged: Config.options.musicRecognition.timeout = value
                    }
                }

                SettingsRow {
                    icon: "av_timer"
                    title: Translation.tr("Polling interval")
                    description: Translation.tr("How often recognition status is polled.")

                    StyledSpinBox {
                        value: Config.options.musicRecognition.interval
                        from: 2
                        to: 10
                        stepSize: 1
                        onValueChanged: Config.options.musicRecognition.interval = value
                    }
                }
            }
        }
    }

    Component {
        id: locationPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Weather location")

                SettingsToggleRow {
                    icon: "assistant_navigation"
                    title: Translation.tr("Enable GPS based location")
                    description: Translation.tr("Use GPS location as the weather source.")
                    checked: Config.options.bar.weather.enableGPS
                    onToggled: checked => Config.options.bar.weather.enableGPS = checked
                }

                SettingsToggleRow {
                    icon: "thermometer"
                    title: Translation.tr("Fahrenheit unit")
                    description: Translation.tr("Use Fahrenheit for weather temperatures.")
                    checked: Config.options.bar.weather.useUSCS
                    onToggled: checked => Config.options.bar.weather.useUSCS = checked
                }

                SettingsRow {
                    icon: "location_city"
                    title: Translation.tr("City name")
                    description: Translation.tr("Manual city used when GPS weather location is disabled.")

                    MaterialTextArea {
                        Layout.preferredWidth: 220
                        implicitHeight: 42
                        text: Config.options.bar.weather.city
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.bar.weather.city = text
                    }
                }

                SettingsRow {
                    icon: "av_timer"
                    title: Translation.tr("Polling interval")
                    description: Translation.tr("How often weather data is refreshed, in minutes.")

                    StyledSpinBox {
                        value: Config.options.bar.weather.fetchInterval
                        from: 5
                        to: 50
                        stepSize: 5
                        onValueChanged: Config.options.bar.weather.fetchInterval = value
                    }
                }
            }
        }
    }

    Component {
        id: diagnosticsPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Resources")

                SettingsRow {
                    icon: "memory"
                    title: Translation.tr("Polling interval")
                    description: Translation.tr("How often resource usage is refreshed, in milliseconds.")

                    StyledSpinBox {
                        value: Config.options.resources.updateInterval
                        from: 100
                        to: 10000
                        stepSize: 100
                        onValueChanged: Config.options.resources.updateInterval = value
                    }
                }
            }
        }
    }

    Component {
        id: configurationPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Networking")

                SettingsRow {
                    icon: "cell_tower"
                    title: Translation.tr("User agent")
                    description: Translation.tr("User agent for services that require it.")

                    MaterialTextArea {
                        Layout.preferredWidth: 280
                        implicitHeight: 42
                        text: Config.options.networking.userAgent
                        wrapMode: TextEdit.NoWrap
                        onTextChanged: Config.options.networking.userAgent = text
                    }
                }
            }
        }
    }

    Component {
        id: supportPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Support")

                SettingsRow {
                    icon: "description"
                    title: Translation.tr("Documentation")
                    description: Translation.tr("Open the project documentation.")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "help"
                    title: Translation.tr("Help & Support")
                    description: Translation.tr("Support resources will be wired in a later pass.")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "bug_report"
                    title: Translation.tr("Report a Bug")
                    description: Translation.tr("Bug-report link will be wired in a later pass.")
                    registerInSearch: false
                }
            }
        }
    }

    Component {
        id: legalPage

        SettingsSubPage {
            SettingsGroup {
                title: Translation.tr("Legal")

                SettingsRow {
                    icon: "privacy_tip"
                    title: Translation.tr("Privacy Policy")
                    description: Translation.tr("Legal links will be wired in a later pass.")
                    registerInSearch: false
                }
            }
        }
    }
}
