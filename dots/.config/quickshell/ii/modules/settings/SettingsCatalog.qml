import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
            id: notificationsRoot

            property var popupTimeouts: [
                { label: Translation.tr("3 seconds"), value: 3000 },
                { label: Translation.tr("5 seconds"), value: 5000 },
                { label: Translation.tr("8 seconds"), value: 8000 },
                { label: Translation.tr("10 seconds"), value: 10000 },
                { label: Translation.tr("15 seconds"), value: 15000 }
            ]
            property var osdTimeouts: [
                { label: Translation.tr("1 second"), value: 1000 },
                { label: Translation.tr("2 seconds"), value: 2000 },
                { label: Translation.tr("3 seconds"), value: 3000 },
                { label: Translation.tr("5 seconds"), value: 5000 },
                { label: Translation.tr("10 seconds"), value: 10000 }
            ]
            property int historyCount: 0

            function displayLabel(screen) {
                const monitor = DisplaysService.monitorByName(screen.name);
                const description = monitor?.description || `${monitor?.make ?? ""} ${monitor?.model ?? ""}`.trim();
                return description ? `${screen.name} — ${description}` : screen.name;
            }

            function refreshHistoryCount() {
                try {
                    historyCount = JSON.parse(historyFile.text() || "[]").length;
                } catch (exception) {
                    historyCount = 0;
                }
            }

            FileView {
                id: historyFile
                path: Qt.resolvedUrl(Directories.notificationsPath)
                watchChanges: true
                onLoaded: notificationsRoot.refreshHistoryCount()
                onLoadFailed: notificationsRoot.historyCount = 0
            }

            Process {
                id: clearHistoryProcess
                command: ["qs", "-c", "ii", "ipc", "call", "notifications", "clearHistory"]
                onExited: historyFile.reload()
            }

            SettingsGroup {
                title: Translation.tr("General")

                SettingsToggleRow {
                    icon: "notifications_active"
                    title: Translation.tr("Notifications enabled")
                    description: Translation.tr("Receive notifications without showing or saving new items when disabled.")
                    checked: Config.options.notifications.enabled
                    onToggled: checked => Config.options.notifications.enabled = checked
                }

                SettingsRow {
                    icon: "timer"
                    title: Translation.tr("Popup timeout")
                    description: Translation.tr("How long notifications stay visible.")
                    keywords: "notifications timeout"

                    StyledComboBox {
                        textRole: "label"
                        model: notificationsRoot.popupTimeouts
                        currentIndex: Math.max(0, model.findIndex(item => item.value === Config.options.notifications.timeout))
                        onActivated: index => Config.options.notifications.timeout = model[index].value
                    }
                }

                SettingsRow {
                    icon: "monitor"
                    title: Translation.tr("Display notifications on")
                    description: Translation.tr("Follow focus or use a specific active display.")

                    StyledComboBox {
                        textRole: "label"
                        model: [{ label: Translation.tr("Active display / Follow focus"), value: "" }].concat(
                            Quickshell.screens.map(screen => ({ label: notificationsRoot.displayLabel(screen), value: screen.name }))
                        )
                        currentIndex: {
                            if (!Config.options.notifications.monitor.enable) return 0;
                            const index = model.findIndex(item => item.value === Config.options.notifications.monitor.name);
                            return index >= 0 ? index : 0;
                        }
                        onActivated: index => {
                            const value = model[index].value;
                            Config.options.notifications.monitor.enable = value !== "";
                            Config.options.notifications.monitor.name = value;
                        }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Do Not Disturb")

                SettingsToggleRow {
                    icon: "notifications_paused"
                    title: Translation.tr("Do Not Disturb")
                    description: Translation.tr("Keep notifications in history without showing popups.")
                    checked: Config.options.notifications.doNotDisturb
                    onToggled: checked => Config.options.notifications.doNotDisturb = checked
                }

                SettingsToggleRow {
                    icon: "priority_high"
                    title: Translation.tr("Allow critical notifications")
                    description: Translation.tr("Show critical notifications while Do Not Disturb is enabled.")
                    enabled: Config.options.notifications.doNotDisturb
                    checked: Config.options.notifications.allowCritical
                    onToggled: checked => Config.options.notifications.allowCritical = checked
                }
            }

            SettingsGroup {
                title: Translation.tr("History")

                SettingsRow {
                    icon: "history"
                    title: Translation.tr("Notification history")
                    description: Translation.tr("%1 notifications saved in the shell history.").arg(notificationsRoot.historyCount)

                    RippleButtonWithIcon {
                        materialIcon: "delete_sweep"
                        mainText: Translation.tr("Clear history")
                        enabled: notificationsRoot.historyCount > 0
                        onClicked: clearHistoryProcess.running = true
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("On-screen display")

                SettingsRow {
                    icon: "timer"
                    title: Translation.tr("OSD timeout")
                    description: Translation.tr("How long volume and brightness indicators stay visible.")

                    StyledComboBox {
                        textRole: "label"
                        model: notificationsRoot.osdTimeouts
                        currentIndex: Math.max(0, model.findIndex(item => item.value === Config.options.osd.timeout))
                        onActivated: index => Config.options.osd.timeout = model[index].value
                    }
                }
            }
        }
    }

    Component {
        id: dateTimePage

        SettingsSubPage {
            id: dateTimeRoot

            property date editingDate: DateTime.clock.date
            property int editYear: editingDate.getFullYear()
            property int editMonth: editingDate.getMonth() + 1
            property int editDay: editingDate.getDate()
            property int editHour: editingDate.getHours()
            property int editMinute: editingDate.getMinutes()

            function syncEditor() {
                const current = DateTime.clock.date;
                editYear = current.getFullYear();
                editMonth = current.getMonth() + 1;
                editDay = current.getDate();
                editHour = current.getHours();
                editMinute = current.getMinutes();
            }

            function validEditingDate() {
                const candidate = new Date(editYear, editMonth - 1, editDay, editHour, editMinute, 0, 0);
                return candidate.getFullYear() === editYear
                    && candidate.getMonth() === editMonth - 1
                    && candidate.getDate() === editDay
                    && candidate.getHours() === editHour
                    && candidate.getMinutes() === editMinute;
            }

            function submitEditingDate() {
                if (!validEditingDate()) {
                    TimeDate.error = Translation.tr("Enter a valid date and time.");
                    return;
                }
                TimeDate.setDateTime(new Date(editYear, editMonth - 1, editDay, editHour, editMinute, 0, 0).getTime());
            }

            Connections {
                target: DateTime.clock
                function onDateChanged() {
                    if (TimeDate.ntpEnabled)
                        dateTimeRoot.syncEditor();
                }
            }

            SettingsRow {
                icon: "calendar_today"
                title: Translation.tr("Current date")
                description: Qt.locale().toString(DateTime.clock.date, "dd MMMM yyyy")
                registerInSearch: false
            }

            SettingsRow {
                icon: "schedule"
                title: Translation.tr("Current time")
                description: DateTime.time
                registerInSearch: false
            }

            SettingsRow {
                icon: "sync"
                title: Translation.tr("Automatic date & time")
                description: TimeDate.ntpSynchronized
                    ? Translation.tr("Synchronized")
                    : Translation.tr("Waiting for synchronization")
                enabled: TimeDate.ready && !TimeDate.operationPending

                StyledSwitch {
                    checked: TimeDate.ntpEnabled
                    enabled: TimeDate.ready && !TimeDate.operationPending
                    onClicked: TimeDate.setNtp(checked)
                }
            }

            SettingsRow {
                visible: TimeDate.error.length > 0
                icon: "error"
                title: Translation.tr("Date & time operation failed")
                description: TimeDate.error
                registerInSearch: false
            }

            SettingsGroup {
                visible: !TimeDate.ntpEnabled
                title: Translation.tr("Manual date & time")

                SettingsRow {
                    icon: "calendar_today"
                    title: Translation.tr("Date")
                    description: Translation.tr("Local date")

                    RowLayout {
                        spacing: 4
                        StyledSpinBox { from: 1; to: 31; value: dateTimeRoot.editDay; onValueChanged: dateTimeRoot.editDay = value }
                        StyledSpinBox { from: 1; to: 12; value: dateTimeRoot.editMonth; onValueChanged: dateTimeRoot.editMonth = value }
                        StyledSpinBox { from: 1970; to: 2100; value: dateTimeRoot.editYear; onValueChanged: dateTimeRoot.editYear = value }
                    }
                }

                SettingsRow {
                    icon: "schedule"
                    title: Translation.tr("Time")
                    description: Translation.tr("Local time")

                    RowLayout {
                        spacing: 4
                        StyledSpinBox { from: 0; to: 23; value: dateTimeRoot.editHour; onValueChanged: dateTimeRoot.editHour = value }
                        StyledText { text: ":"; color: Appearance.colors.colOnSurfaceVariant }
                        StyledSpinBox { from: 0; to: 59; value: dateTimeRoot.editMinute; onValueChanged: dateTimeRoot.editMinute = value }
                        RippleButtonWithIcon {
                            materialIcon: "check"
                            mainText: Translation.tr("Set")
                            enabled: !TimeDate.operationPending && dateTimeRoot.validEditingDate()
                            onClicked: dateTimeRoot.submitEditingDate()
                        }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Time zone")

                SettingsRow {
                    icon: "public"
                    title: Translation.tr("Current time zone")
                    description: TimeDate.timezone || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "public"
                    title: Translation.tr("Time zone")
                    description: Translation.tr("Choose the system time zone.")

                    SearchableSelection {
                        currentValue: TimeDate.timezone
                        options: TimeDate.availableTimezones
                        placeholder: Translation.tr("Select time zone")
                        onSelected: value => TimeDate.setTimezone(value)
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Format")

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

            SettingsGroup {
                title: Translation.tr("Regional formats")

                SettingsRow {
                    icon: "public"
                    title: Translation.tr("Region / locale")
                    description: Translation.tr("Controls date, number, currency, and measurement conventions.")

                    SearchableSelection {
                        currentValue: Locale1.languageLocale
                        options: Locale1.availableLocales
                        placeholder: Translation.tr("Select locale")
                        enabled: Locale1.ready && !Locale1.operationPending
                        onSelected: value => Locale1.setLocale(value)
                    }
                }

                SettingsRow {
                    icon: "computer"
                    title: Translation.tr("System locale")
                    description: Locale1.friendlyName(Locale1.languageLocale)
                    registerInSearch: false
                }

                SettingsRow {
                    visible: Locale1.messageLocale.length > 0 && Locale1.messageLocale !== Locale1.languageLocale
                    icon: "translate"
                    title: Translation.tr("Interface messages")
                    description: Locale1.friendlyName(Locale1.messageLocale)
                    registerInSearch: false
                }

                SettingsRow {
                    visible: Locale1.error.length > 0
                    icon: "error"
                    title: Translation.tr("Locale operation failed")
                    description: Locale1.error
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "info"
                    title: Translation.tr("Applying regional formats")
                    description: Translation.tr("New applications use the new locale. Existing applications may need to be restarted.")
                    registerInSearch: false
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
