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
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF
import qs.modules.settings
import qs.modules.settings.components

ApplicationWindow {
    id: root

    signal closeRequested()
    property string initialRoute: ""

    // Hyprland blurs this window at composite time - see the no_blur exception
    // in hypr/hyprland/rules.lua. That is registered with the wallpaper by
    // construction, including mid-drag, because the compositor knows where the
    // window is at the moment it composites; a client never does.
    //
    // Everything below guarded by this - the wallpaper backdrop and the whole
    // position tracker - is the client-side imitation of that, kept only for
    // compositors that will not do it. Flip to false to compare.
    readonly property bool useCompositorBlur: true
    // ApplicationWindow exposes a QScreen while WallpaperBackdrop needs the
    // matching ShellScreen, whose geometry is in the compositor's global
    // coordinate space. The dedicated tracker updates these only during a
    // titlebar drag; HyprlandData remains a coarse fallback for external moves.
    // ONE property, not an x and a y. Assigning two separately notifies twice,
    // and for the frame in between the backdrop is drawn at a position that
    // never existed - new horizontal, stale vertical. At drag rates that lands
    // as visible jitter. The same trap is documented on WallpaperGeometry's
    // naturalSize; it applies to every coordinate pair updated per frame.
    property point settingsGlobalPos: Qt.point(root.x, root.y)
    property point committedSettingsGlobalPos: Qt.point(root.x, root.y)
    property int settingsMonitor: -1
    readonly property var wallpaperScreen: {
        return Quickshell.screens.find(screen => Hyprland.monitorFor(screen)?.id === root.settingsMonitor)
            ?? Quickshell.screens.find(screen => screen.name === root.screen?.name)
            ?? Quickshell.screens[0]
            ?? null;
    }
    readonly property real wallpaperScreenX: root.settingsGlobalPos.x - (root.wallpaperScreen?.x ?? 0)
    readonly property real wallpaperScreenY: root.settingsGlobalPos.y - (root.wallpaperScreen?.y ?? 0)

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
                { key: "apps-startup-apps", name: Translation.tr("Startup Apps"), icon: "rocket_launch" },
                { key: "apps-installed-apps", name: Translation.tr("Installed Apps"), icon: "deployed_code" },
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
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "privacy-security",
            name: Translation.tr("Privacy & Security"),
            subtitle: Translation.tr("Screen lock and keyring"),
            icon: "shield_lock",
            entries: [
                { key: "privacy-security-screen-lock", name: Translation.tr("Screen Lock"), icon: "lock" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "updates",
            name: Translation.tr("Updates"),
            subtitle: Translation.tr("System update status"),
            icon: "deployed_code_update",
            entries: [
                { key: "updates-system", name: Translation.tr("System Updates"), icon: "system_update" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "advanced",
            name: Translation.tr("Advanced"),
            subtitle: Translation.tr("System health"),
            icon: "construction",
            entries: [
                { key: "advanced-diagnostics", name: Translation.tr("Diagnostics"), icon: "troubleshoot" }
            ],
            component: "modules/settings/SettingsCatalog.qml"
        },
        {
            key: "about",
            name: Translation.tr("About"),
            subtitle: Translation.tr("Project information"),
            icon: "info",
            entries: [
                { key: "about-about", name: Translation.tr("About"), icon: "info" }
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
    onClosing: root.closeRequested()
    title: "illogical-impulse Settings"
    onVisibleChanged: {
        if (!visible)
            return;
        // ApplicationWindow can be mapped before the compositor has accepted
        // the new surface. Activate on the next event turn so pointer and
        // keyboard input are delivered to Settings (including standalone
        // settings.qml, which has no SettingsHost activation hook).
        Qt.callLater(() => {
            if (root.visible) {
                root.raise();
                root.requestActivate();
            }
        });
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.forceShow = true
    }

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Config.readWriteDelay = 0; // Settings app always only sets one var at a time so delay isn't needed
        Qt.callLater(root.syncExternalPosition);
        if (root.initialRoute.length > 0)
            Qt.callLater(() => root.navigateToRoute(root.initialRoute));
    }

    SettingsWindowPositionTracker {
        id: positionTracker
        settingsTitle: root.title
        // Only the wallpaper crop needs the live position, so don't poll when
        // there is no backdrop to keep aligned or nobody is looking.
        watchExternalMoves: root.visible && !root.useCompositorBlur
            && Config.options.appearance.transparency.enable
        onExactPositionUpdated: (globalX, globalY, monitorId) => {
            root.settingsGlobalPos = Qt.point(globalX, globalY);
            root.committedSettingsGlobalPos = Qt.point(globalX, globalY);
            root.settingsMonitor = monitorId;
        }
        // Only fires when the tracker is configured to chase during a drag.
        onPredictedPositionUpdated: (globalX, globalY) => {
            root.settingsGlobalPos = Qt.point(globalX, globalY);
        }
    }

    Connections {
        target: HyprlandData
        function onWindowListChanged() {
            // External compositor/keybind moves retain the existing coarse
            // refresh path. Never replace a live direct-IPC position mid-drag.
            if (!positionTracker.tracking && !positionTracker.requestPending)
                root.syncExternalPosition();
        }
    }

    minimumWidth: 900
    minimumHeight: 600
    width: 1250
    height: 820
    // The tint that guarantees legibility, not decoration. It used to live
    // inside WallpaperBackdrop and covered the whole window; when the backdrop
    // was replaced by compositor blur it went with it, and the sidebar and
    // header - which have no surface of their own - were left as bare glass.
    // Over a dark stretch of wallpaper that looked fine; over a bright one the
    // labels became unreadable.
    //
    // Same recipe as the old backdrop used, so the material is unchanged: a
    // dark base at roughly 89% opacity, letting about a tenth of the blurred
    // wallpaper through. Enough to read as glass, never enough to lose text.
    color: !Config.options.appearance.transparency.enable
        ? Appearance.m3colors.m3background
        : Config.options.appearance.transparency.compositorBlur
            ? Appearance.colors.colGlassTint
            : "transparent"

    // Keep normal windows on the same wallpaper-derived glass material as
    // layer-shell popups. This is a rendered wallpaper crop, not compositor
    // transparency, so another application's pixels can never show through.
    Loader {
        anchors.fill: parent
        z: -1
        active: !root.useCompositorBlur
            && Config.options.appearance.transparency.enable
            && root.wallpaperScreen !== null
        asynchronous: true

        sourceComponent: WallpaperBackdrop {
            screen: root.wallpaperScreen
            screenX: root.wallpaperScreenX
            screenY: root.wallpaperScreenY
        }
    }


    function goToPage(index) {
        root.currentPage = Math.max(0, Math.min(index, root.pages.length - 1));
    }

    function syncExternalPosition() {
        const client = HyprlandData.windowList.find(window => window.title === root.title);
        if (!client?.at || client.at.length < 2)
            return;
        root.settingsGlobalPos = Qt.point(client.at[0], client.at[1]);
        root.committedSettingsGlobalPos = Qt.point(client.at[0], client.at[1]);
        root.settingsMonitor = client.monitor ?? -1;
    }

    function navigateToRoute(route) {
        if (!route || route.length === 0) {
            root.goToPage(0);
            return;
        }
        for (let pageIndex = 0; pageIndex < root.pages.length; pageIndex++) {
            const entries = root.pages[pageIndex].entries ?? [];
            if (entries.some(entry => entry.key === route)) {
                root.goToPage(pageIndex);
                Qt.callLater(() => {
                    if (pageLoader.item?.openSubPage)
                        pageLoader.item.openSubPage(route);
                });
                return;
            }
        }
        root.goToPage(0);
    }

    function configurePage(item) {
        if (!item)
            return;
        const page = root.pages[root.currentPage] ?? {};
        if (item.settingsPageIndex !== undefined)
            item.settingsPageIndex = root.currentPage;
        if (item.settingsPageName !== undefined)
            item.settingsPageName = page.name ?? "";
        if (item.pageTitle !== undefined)
            item.pageTitle = page.name ?? "";
        if (item.pageKey !== undefined)
            item.pageKey = page.key ?? "";
        if (item.menuEntries !== undefined)
            item.menuEntries = page.entries ?? [];
        if (item.currentSubPageKey !== undefined)
            item.currentSubPageKey = "";
    }

    onCurrentPageChanged: configurePage(pageLoader.item)

    Connections {
        target: SettingsLauncher
        function onRouteChanged() {
            if (SettingsLauncher.active)
                root.navigateToRoute(SettingsLauncher.route);
        }
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
            const pageItem = pageLoader.item ?? null;
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

            MouseArea {
                anchors {
                    left: parent.left
                    right: searchField.left
                    top: parent.top
                    bottom: parent.bottom
                }
                cursorShape: Qt.SizeAllCursor
                onPressed: mouse => {
                    positionTracker.begin(root.committedSettingsGlobalPos.x, root.committedSettingsGlobalPos.y, root.settingsMonitor);
                    if (!root.startSystemMove())
                        positionTracker.end();
                    mouse.accepted = true;
                }
                onReleased: positionTracker.end()
                onCanceled: positionTracker.end()
            }

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
                color: Config.options.appearance.transparency.enable
                    ? Appearance.colors.colBackgroundSurfaceContainer
                    : Appearance.m3colors.m3surfaceContainerLowest
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

                    Loader {
                        id: pageLoader
                        anchors.fill: parent
                        // One reusable catalog is enough: it owns only the
                        // selected category and swaps its metadata when the
                        // user navigates. This avoids thirteen inactive Loader
                        // trees and their per-page host objects at startup.
                        active: Config.ready && root.pages.length > 0
                        sourceComponent: catalogComponent
                        onLoaded: root.configurePage(item)
                    }
                }
            }
        }
    }

    Component {
        id: catalogComponent
        SettingsCatalog {}
    }
}
