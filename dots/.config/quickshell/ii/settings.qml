//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.settings
import qs.modules.settings.components

ApplicationWindow {
    id: root

    property var pages: [
        {
            key: "system",
            name: Translation.tr("System"),
            subtitle: Translation.tr("Sound, battery, notifications"),
            icon: "computer",
            entries: [
                { key: "system-displays", name: Translation.tr("Displays"), icon: "monitor" },
                { key: "system-sound", name: Translation.tr("Sound"), icon: "volume_up" },
                { key: "system-power-battery", name: Translation.tr("Power & Battery"), icon: "battery_full" },
                { key: "system-notifications", name: Translation.tr("Notifications"), icon: "notifications" },
                { key: "system-date-time", name: Translation.tr("Date & Time"), icon: "schedule" },
                { key: "system-language-region", name: Translation.tr("Language & Region"), icon: "language" },
                { key: "system-storage", name: Translation.tr("Storage"), icon: "hard_drive" },
                { key: "system-info", name: Translation.tr("System Info"), icon: "info" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "connectivity",
            name: Translation.tr("Connectivity"),
            subtitle: Translation.tr("Wi-Fi, Bluetooth, VPN"),
            icon: "wifi",
            entries: [
                { key: "connectivity-wifi", name: Translation.tr("Wi-Fi"), icon: "wifi" },
                { key: "connectivity-ethernet", name: Translation.tr("Ethernet"), icon: "lan" },
                { key: "connectivity-bluetooth", name: Translation.tr("Bluetooth"), icon: "bluetooth" },
                { key: "connectivity-vpn", name: Translation.tr("VPN"), icon: "vpn_key" },
                { key: "connectivity-proxy", name: Translation.tr("Proxy"), icon: "settings_ethernet" },
                { key: "connectivity-hotspot", name: Translation.tr("Hotspot"), icon: "wifi_tethering" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "devices",
            name: Translation.tr("Devices"),
            subtitle: Translation.tr("Keyboard, mouse, printers"),
            icon: "devices",
            entries: [
                { key: "devices-keyboard", name: Translation.tr("Keyboard"), icon: "keyboard" },
                { key: "devices-mouse-touchpad", name: Translation.tr("Mouse & Touchpad"), icon: "mouse" },
                { key: "devices-printers", name: Translation.tr("Printers"), icon: "print" },
                { key: "devices-game-controllers", name: Translation.tr("Game Controllers"), icon: "sports_esports" },
                { key: "devices-other", name: Translation.tr("Other Devices"), icon: "devices_other" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "personalization",
            name: Translation.tr("Personalization"),
            subtitle: Translation.tr("Appearance, colors, wallpaper"),
            icon: "palette",
            entries: [
                { key: "personalization-appearance", name: Translation.tr("Appearance"), icon: "contrast" },
                { key: "personalization-colors", name: Translation.tr("Colors"), icon: "colors" },
                { key: "personalization-fonts", name: Translation.tr("Fonts"), icon: "font_download" },
                { key: "personalization-lock-screen", name: Translation.tr("Lock Screen"), icon: "lock" },
                { key: "personalization-effects-animations", name: Translation.tr("Effects & Animations"), icon: "animation" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "desktop-shell",
            name: Translation.tr("Desktop & Shell"),
            subtitle: Translation.tr("Bar, workspaces, widgets"),
            icon: "dashboard",
            entries: [
                { key: "desktop-shell-bar-tray", name: Translation.tr("Bar & Tray"), icon: "toast" },
                { key: "desktop-shell-dock", name: Translation.tr("Dock"), icon: "bottom_app_bar" },
                { key: "desktop-shell-workspaces", name: Translation.tr("Workspaces"), icon: "workspaces" },
                { key: "desktop-shell-overview", name: Translation.tr("Overview"), icon: "overview" },
                { key: "desktop-shell-desktop-widgets", name: Translation.tr("Desktop Widgets"), icon: "widgets" },
                { key: "desktop-shell-sidebars", name: Translation.tr("Sidebars"), icon: "side_navigation" },
                { key: "desktop-shell-quick-settings", name: Translation.tr("Quick Settings"), icon: "instant_mix" },
                { key: "desktop-shell-hot-corners", name: Translation.tr("Hot Corners"), icon: "rounded_corner" },
                { key: "desktop-shell-shortcuts", name: Translation.tr("Shortcuts"), icon: "keyboard_command_key" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "apps",
            name: Translation.tr("Apps"),
            subtitle: Translation.tr("Defaults, startup, permissions"),
            icon: "apps",
            entries: [
                { key: "apps-default-apps", name: Translation.tr("Default Apps"), icon: "select_window" },
                { key: "apps-startup", name: Translation.tr("Startup Apps"), icon: "rocket_launch" },
                { key: "apps-installed", name: Translation.tr("Installed Apps"), icon: "deployed_code" },
                { key: "apps-permissions", name: Translation.tr("App Permissions"), icon: "admin_panel_settings" },
                { key: "apps-file-associations", name: Translation.tr("File Associations"), icon: "file_present" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "search-tools",
            name: Translation.tr("Search & Tools"),
            subtitle: Translation.tr("Search, clipboard, screenshots"),
            icon: "search",
            entries: [
                { key: "search-tools-search", name: Translation.tr("Search"), icon: "search" },
                { key: "search-tools-clipboard", name: Translation.tr("Clipboard"), icon: "content_paste" },
                { key: "search-tools-screenshots", name: Translation.tr("Screenshots"), icon: "screenshot_monitor" },
                { key: "search-tools-screen-recording", name: Translation.tr("Screen Recording"), icon: "videocam" },
                { key: "search-tools-region-selection", name: Translation.tr("Region Selection"), icon: "select" },
                { key: "search-tools-color-picker", name: Translation.tr("Color Picker"), icon: "colorize" },
                { key: "search-tools-translator", name: Translation.tr("Translator"), icon: "translate" },
                { key: "search-tools-other", name: Translation.tr("Other Tools"), icon: "construction" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "privacy-security",
            name: Translation.tr("Privacy & Security"),
            subtitle: Translation.tr("Lock, auth, privacy"),
            icon: "shield_lock",
            entries: [
                { key: "privacy-security-screen-lock", name: Translation.tr("Screen Lock"), icon: "lock" },
                { key: "privacy-security-authentication", name: Translation.tr("Authentication"), icon: "passkey" },
                { key: "privacy-security-fingerprint", name: Translation.tr("Fingerprint"), icon: "fingerprint" },
                { key: "privacy-security-keyring", name: Translation.tr("Keyring"), icon: "key" },
                { key: "privacy-security-location", name: Translation.tr("Location"), icon: "location_on" },
                { key: "privacy-security-camera", name: Translation.tr("Camera"), icon: "photo_camera" },
                { key: "privacy-security-microphone", name: Translation.tr("Microphone"), icon: "mic" },
                { key: "privacy-security-screen-capture", name: Translation.tr("Screen Capture"), icon: "capture" },
                { key: "privacy-security-activity-history", name: Translation.tr("Activity & History"), icon: "history" },
                { key: "privacy-security-privacy", name: Translation.tr("Privacy"), icon: "privacy_tip" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "accessibility",
            name: Translation.tr("Accessibility"),
            subtitle: Translation.tr("Vision, input, motion"),
            icon: "accessibility_new",
            entries: [
                { key: "accessibility-vision", name: Translation.tr("Vision"), icon: "visibility" },
                { key: "accessibility-hearing", name: Translation.tr("Hearing"), icon: "hearing" },
                { key: "accessibility-keyboard", name: Translation.tr("Keyboard"), icon: "keyboard" },
                { key: "accessibility-pointer", name: Translation.tr("Pointer"), icon: "ads_click" },
                { key: "accessibility-text-scaling", name: Translation.tr("Text & Scaling"), icon: "format_size" },
                { key: "accessibility-motion", name: Translation.tr("Motion"), icon: "animation" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "accounts",
            name: Translation.tr("Accounts"),
            subtitle: Translation.tr("User, profile, login"),
            icon: "account_circle",
            entries: [
                { key: "accounts-user", name: Translation.tr("User Account"), icon: "person" },
                { key: "accounts-profile", name: Translation.tr("Profile"), icon: "badge" },
                { key: "accounts-password", name: Translation.tr("Password"), icon: "password" },
                { key: "accounts-login", name: Translation.tr("Login"), icon: "login" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "updates",
            name: Translation.tr("Updates"),
            subtitle: Translation.tr("System update status"),
            icon: "deployed_code_update",
            entries: [
                { key: "updates-system", name: Translation.tr("System Updates"), icon: "system_update" },
                { key: "updates-settings", name: Translation.tr("Update Settings"), icon: "update" },
                { key: "updates-history", name: Translation.tr("Update History"), icon: "history" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "advanced",
            name: Translation.tr("Advanced"),
            subtitle: Translation.tr("Performance, diagnostics, config"),
            icon: "construction",
            entries: [
                { key: "advanced-performance", name: Translation.tr("Performance"), icon: "speed" },
                { key: "advanced-power-management", name: Translation.tr("Power Management"), icon: "power_settings_new" },
                { key: "advanced-compatibility", name: Translation.tr("Compatibility"), icon: "extension" },
                { key: "advanced-experimental", name: Translation.tr("Experimental"), icon: "experiment" },
                { key: "advanced-developer", name: Translation.tr("Developer"), icon: "code" },
                { key: "advanced-diagnostics", name: Translation.tr("Diagnostics"), icon: "troubleshoot" },
                { key: "advanced-configuration", name: Translation.tr("Configuration"), icon: "settings_applications" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "about",
            name: Translation.tr("About"),
            subtitle: Translation.tr("Device, software, support"),
            icon: "info",
            entries: [
                { key: "about-device", name: Translation.tr("Device"), icon: "devices" },
                { key: "about-hardware", name: Translation.tr("Hardware"), icon: "memory" },
                { key: "about-software", name: Translation.tr("Software"), icon: "deployed_code" },
                { key: "about-support", name: Translation.tr("Support"), icon: "support_agent" },
                { key: "about-legal", name: Translation.tr("Legal"), icon: "policy" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        }
    ]
    property int currentPage: 0

    // Config and the real (wallpaper-derived) colors both load asynchronously.
    // Appearance.m3colors starts out on a baked-in fallback palette, so a
    // window shown before MaterialThemeLoader finishes paints with the wrong
    // colors for a moment and then jumps to the right ones - visibly "two
    // different designs". Waiting for both here means the window's first
    // frame is already the final one. forceShow is a safety net: if either
    // load hangs or fails in a way that never settles, the window still
    // appears rather than staying invisible forever.
    property bool forceShow: false
    visible: (Config.ready && MaterialThemeLoader.themeApplied) || root.forceShow
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Timer {
        interval: 1500
        running: true
        onTriggered: root.forceShow = true
    }

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0; // Settings app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 900
    minimumHeight: 600
    width: 1250
    height: 820
    color: Appearance.m3colors.m3background

    function goToPage(index) {
        root.currentPage = Math.max(0, Math.min(index, root.pages.length - 1));
    }

    // Search hit selected: switch to its page, then scroll it into view. The
    // page has to be laid out at its new size before its position is meaningful,
    // hence the deferred reveal.
    function openSearchResult(entry) {
        if (!entry)
            return;
        const context = SettingsSearch.resolveContext(entry.target);
        if (context.pageIndex < 0)
            return;
        // Clear through the field, not the singleton: the field's onTextChanged
        // owns the query, so clearing only the singleton gets immediately undone.
        searchField.text = "";
        root.goToPage(context.pageIndex);
        Qt.callLater(() => {
            const pageItem = pageRepeater.itemAt(context.pageIndex)?.pageItem ?? null;
            if (pageItem?.revealRow)
                pageItem.revealRow(entry.target);
        });
    }

    Shortcut {
        sequences: ["Ctrl+F"]
        onActivated: searchField.forceSearchFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Keys.onPressed: event => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.goToPage(root.currentPage + 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.goToPage(root.currentPage - 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Item { // Header: title, search, window controls
            Layout.fillWidth: true
            implicitHeight: 78

            StyledText {
                anchors {
                    left: parent.left
                    leftMargin: 28
                    verticalCenter: parent.verticalCenter
                }
                text: Translation.tr("Settings")
                font {
                    family: Appearance.font.family.title
                    pixelSize: Appearance.font.pixelSize.huge
                    variableAxes: Appearance.font.variableAxes.title
                }
                color: Appearance.colors.colOnSurface
            }

            SettingsSearchField {
                id: searchField
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                width: Math.min(520, parent.width * 0.42)
                onTextChanged: SettingsSearch.query = text
                onEscaped: {
                    text = "";
                    focus = false;
                }
            }

            RippleButton { // Window controls: close only
                visible: Config.options?.windows.showTitlebar ?? true
                anchors {
                    right: parent.right
                    rightMargin: 16
                    verticalCenter: parent.verticalCenter
                }
                buttonRadius: Appearance.rounding.full
                implicitWidth: 38
                implicitHeight: 38
                onClicked: root.close()
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        RowLayout { // Sidebar + content
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            Layout.bottomMargin: 16
            spacing: 16

            ColumnLayout { // Sidebar
                Layout.fillHeight: true
                Layout.fillWidth: false
                // Pin the width from all three sides: children are fillWidth, so
                // preferredWidth alone loses to their implicit sizing.
                Layout.minimumWidth: 268
                Layout.preferredWidth: 268
                Layout.maximumWidth: 268
                spacing: 12

                StyledFlickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: navColumn.implicitHeight

                    ColumnLayout {
                        id: navColumn
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.pages

                            SettingsNavItem {
                                required property var modelData
                                required property int index

                                icon: modelData.icon
                                iconRotation: modelData.iconRotation ?? 0
                                title: modelData.name
                                subtitle: modelData.subtitle ?? ""
                                selected: root.currentPage === index && !SettingsSearch.searching
                                onClicked: {
                                    searchField.text = "";
                                    root.goToPage(index);
                                }
                            }
                        }
                    }
                }

                FloatingActionButton {
                    id: fab
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    property bool justCopied: false
                    iconText: justCopied ? "check" : "edit"
                    buttonText: justCopied ? Translation.tr("Path copied") : Translation.tr("Config file")
                    expanded: true
                    downAction: () => {
                        Qt.openUrlExternally(`${Directories.config}/illogical-impulse/config.json`);
                    }
                    altAction: () => {
                        Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/illogical-impulse/config.json`);
                        fab.justCopied = true;
                        revertTextTimer.restart();
                    }

                    Timer {
                        id: revertTextTimer
                        interval: 1500
                        onTriggered: fab.justCopied = false
                    }

                    StyledToolTip {
                        text: Translation.tr("Open the shell config file\nAlternatively right-click to copy path")
                    }
                }
            }

            Rectangle { // Content surface
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.m3colors.m3surfaceContainerLowest
                radius: Appearance.rounding.windowRounding
                clip: true

                SettingsSearchResults {
                    anchors.fill: parent
                    visible: SettingsSearch.searching
                    onResultActivated: entry => root.openSearchResult(entry)
                }

                Item { // Page host
                    anchors.fill: parent
                    visible: !SettingsSearch.searching

                    Repeater {
                        id: pageRepeater
                        model: root.pages

                        // Every page stays loaded rather than swapping a single
                        // Loader: that's what lets the search index cover all of
                        // them, and it makes switching pages instant.
                        Item {
                            required property var modelData
                            required property int index
                            property alias pageItem: pageLoader.item

                            anchors.fill: parent
                            visible: root.currentPage === index
                            opacity: visible ? 1 : 0

                            Behavior on opacity {
                                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                            }

                            Loader {
                                id: pageLoader
                                anchors.fill: parent
                                active: Config.ready
                                source: modelData.component

                                onLoaded: {
                                    if (item.settingsPageIndex !== undefined)
                                        item.settingsPageIndex = index;
                                    if (item.settingsPageName !== undefined)
                                        item.settingsPageName = modelData.name;
                                    if (item.pageTitle !== undefined)
                                        item.pageTitle = modelData.name;
                                    if (item.pageKey !== undefined)
                                        item.pageKey = modelData.key ?? "";
                                    if (item.menuEntries !== undefined)
                                        item.menuEntries = modelData.entries ?? [];
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
