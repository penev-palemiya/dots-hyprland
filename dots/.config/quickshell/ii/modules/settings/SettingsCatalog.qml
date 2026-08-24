import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsPage {
    id: root


    property string pageKey: ""
    property var menuEntries: []

    function syncBluetoothDiscovery() {
        if (root.pageKey !== "connectivity")
            return;
        if (root.currentSubPageKey === "connectivity-bluetooth")
            BluetoothStatus.acquireDiscovery("settings");
        else
            BluetoothStatus.releaseDiscovery("settings");
    }

    Loader {
        id: personalizationLoader
        Layout.fillWidth: true
        // Personalization has a landing surface, but it must not remain alive
        // once a child route is selected. Otherwise the landing Loader and the
        // detail Loader overlap and the next category can inherit a stale
        // content surface.
        active: root.pageKey === "personalization" && root.currentSubPageKey === ""
        visible: active
        sourceComponent: personalizationComponent
    }

    Connections {
        target: personalizationLoader.item
        function onOpenSubPage(key) {
            root.openSubPage(key);
        }
    }

    Component {
        id: personalizationComponent
        PersonalizationConfig {}
    }

    onCurrentSubPageKeyChanged: root.syncBluetoothDiscovery()
    onPageKeyChanged: root.syncBluetoothDiscovery()
    Component.onDestruction: if (root.pageKey === "connectivity") BluetoothStatus.releaseDiscovery("settings")

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
        case "system-storage": return storagePage;
        case "system-info": return systemInfoPage;
        case "desktop-shell-bar-tray": return barTrayPage;
        case "desktop-shell-dock": return dockPage;
        case "desktop-shell-workspaces": return workspacesPage;
        case "desktop-shell-overview": return overviewPage;
        case "desktop-shell-sidebars": return sidebarsPage;
        case "desktop-shell-quick-settings": return quickSettingsPage;
        case "desktop-shell-hot-corners": return hotCornersPage;
        case "desktop-shell-shortcuts": return shortcutsPage;
        case "apps-default-apps": return defaultAppsPage;
        case "apps-startup-apps": return startupAppsPage;
        case "apps-installed-apps": return installedAppsPage;
        case "apps-permissions": return appPermissionsPage;
        case "apps-file-associations": return fileAssociationsPage;
        case "connectivity-wifi": return wifiPage;
        case "connectivity-ethernet": return ethernetPage;
        case "connectivity-bluetooth": return bluetoothPage;
        case "connectivity-vpn": return vpnPage;
        case "connectivity-proxy": return proxyPage;
        case "connectivity-hotspot": return hotspotPage;
        case "devices-keyboard": return keyboardPage;
        case "devices-mouse-touchpad": return mouseTouchpadPage;
        case "devices-printers": return printersPage;
        case "devices-game-controllers": return gameControllersPage;
        case "devices-other": return otherDevicesPage;
        case "personalization-appearance": return appearancePage;
        case "personalization-colors": return colorsPage;
        case "personalization-fonts": return fontsPage;
        case "personalization-lock-screen": return lockScreenPage;
        case "personalization-effects-animations": return effectsAnimationsPage;
        case "search-tools-search": return searchPage;
        case "search-tools-clipboard": return clipboardPage;
        case "search-tools-screenshots": return screenshotsPage;
        case "search-tools-screen-recording": return screenRecordingPage;
        case "privacy-security-screen-lock": return screenLockSecurityPage;
        case "updates-system": return systemUpdatesPage;
        case "advanced-diagnostics": return diagnosticsPage;
        case "about-about": return aboutPage;
        default: return placeholderPage;
        }
    }

    Component {
        id: displaysPage
        DisplaysConfig {}
    }

    SettingsGroup {
        visible: root.pageKey !== "personalization"
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
        id: barTrayPage
        BarConfig {}
    }

    Component {
        id: dockPage
        DockConfig {}
    }

    Component {
        id: workspacesPage
        WorkspaceConfig {}
    }

    Component {
        id: overviewPage
        OverviewConfig {}
    }

    Component {
        id: sidebarsPage
        SidebarsConfig {}
    }

    Component {
        id: quickSettingsPage
        QuickSettingsConfig {}
    }

    Component {
        id: hotCornersPage
        HotCornersConfig {}
    }

    Component {
        id: shortcutsPage
        ShortcutsConfig {}
    }

    Component {
        id: defaultAppsPage
        DefaultAppsConfig {}
    }

    Component {
        id: startupAppsPage
        StartupAppsConfig {}
    }

    Component {
        id: installedAppsPage
        InstalledAppsConfig {}
    }

    Component {
        id: appPermissionsPage
        AppPermissionsConfig {}
    }

    Component {
        id: fileAssociationsPage
        FileAssociationsConfig {}
    }

    Component {
        id: wifiPage

        SettingsSubPage {
            id: wifiRoot

            property WifiAccessPoint passwordTarget: null
            property string password: ""

            Component.onCompleted: Network.requestScan()

            function signalText(network) {
                return `${network.strength}%${network.band ? ` · ${network.band}` : ""}`;
            }

            SettingsGroup {
                title: Translation.tr("Wi-Fi")

                SettingsToggleRow {
                    icon: Network.wifiEnabled ? "wifi" : "wifi_off"
                    title: Translation.tr("Wi-Fi")
                    description: Network.wifiDevices.length > 1
                        ? Translation.tr("%1 Wi-Fi devices").arg(Network.wifiDevices.length)
                        : (Network.wifiDevices[0]?.interfaceName || Translation.tr("No Wi-Fi device detected"))
                    checked: Network.wifiEnabled
                    onToggled: checked => Network.enableWifi(checked)
                }

                SettingsRow {
                    visible: Network.error.length > 0
                    icon: "error"
                    title: Translation.tr("Wi-Fi operation failed")
                    description: Network.error
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Current Network")
                visible: Network.wifiStatus === "connected"

                SettingsRow {
                    icon: "wifi"
                    title: Network.currentDetails.ssid || Network.activeWifiName
                    description: [Translation.tr("Connected"), Network.currentDetails.band, Network.currentDetails.signal > 0 ? `${Network.currentDetails.signal}%` : ""].filter(value => value.length > 0).join(" · ")

                    RippleButtonWithIcon {
                        materialIcon: "link_off"
                        mainText: Translation.tr("Disconnect")
                        enabled: !Network.wifiConnecting
                        onClicked: Network.disconnectWifiNetwork()
                    }
                }

                SettingsRow {
                    icon: "lan"
                    title: Translation.tr("IPv4")
                    description: Network.currentDetails.ipv4 || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    visible: Network.currentDetails.ipv6.length > 0
                    icon: "language"
                    title: Translation.tr("IPv6")
                    description: Network.currentDetails.ipv6
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "router"
                    title: Translation.tr("Gateway")
                    description: Network.currentDetails.gateway || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "dns"
                    title: Translation.tr("DNS")
                    description: Network.currentDetails.dns || Translation.tr("Unavailable")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Available Networks")

                SettingsRow {
                    icon: "refresh"
                    title: Network.wifiScanning ? Translation.tr("Scanning…") : Translation.tr("Refresh")
                    description: Translation.tr("NetworkManager updates this list when access points change.")
                    clickable: true
                    enabled: !Network.wifiScanning
                    onClicked: Network.requestScan(true)
                    registerInSearch: false
                }

                Repeater {
                    model: Network.friendlyWifiNetworks.filter(network => !network.connected)

                    SettingsRow {
                        required property WifiAccessPoint modelData
                        icon: modelData.isSecure ? "lock" : "wifi"
                        title: modelData.ssid
                        description: [modelData.security, wifiRoot.signalText(modelData)].filter(value => value.length > 0).join(" · ")
                        registerInSearch: false

                        ColumnLayout {
                            spacing: 6

                            RowLayout {
                                spacing: 6
                                RippleButtonWithIcon {
                                    visible: !modelData.askingPassword
                                    materialIcon: "login"
                                    mainText: Network.isKnownNetwork(modelData.ssid) ? Translation.tr("Connect") : Translation.tr("Join")
                                    enabled: !Network.wifiConnecting
                                    onClicked: {
                                        if (modelData.isSecure && !Network.isKnownNetwork(modelData.ssid))
                                            modelData.askingPassword = true;
                                        else
                                            Network.connectToWifiNetwork(modelData);
                                    }
                                }
                            }

                            MaterialTextField {
                                id: passwordField
                                visible: modelData.askingPassword
                                Layout.preferredWidth: 220
                                placeholderText: Translation.tr("Password")
                                echoMode: TextInput.Password
                                inputMethodHints: Qt.ImhSensitiveData
                                onAccepted: {
                                    Network.changePassword(modelData, text);
                                    clear();
                                    modelData.askingPassword = false;
                                }
                            }

                            RowLayout {
                                visible: modelData.askingPassword
                                spacing: 6
                                DialogButton {
                                    buttonText: Translation.tr("Cancel")
                                    onClicked: modelData.askingPassword = false
                                }
                                DialogButton {
                                    buttonText: Translation.tr("Connect")
                                    colBackground: Appearance.colors.colPrimary
                                    colText: Appearance.colors.colOnPrimary
                                    onClicked: {
                                        Network.changePassword(modelData, passwordField.text);
                                        passwordField.clear();
                                        modelData.askingPassword = false;
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsRow {
                    visible: Network.ready && Network.friendlyWifiNetworks.length === 0
                    icon: "wifi_find"
                    title: Translation.tr("No networks found")
                    description: Translation.tr("Try refreshing the access-point list.")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Known Networks")
                visible: Network.savedWifiProfilesList.length > 0

                Repeater {
                    model: Network.savedWifiProfilesList

                    SettingsRow {
                        required property var modelData
                        icon: "bookmark"
                        title: modelData.id || modelData.ssid
                        description: modelData.ssid
                        registerInSearch: false

                        RowLayout {
                            spacing: 6
                            RippleButtonWithIcon {
                                visible: Network.wifiDevices.length > 0
                                materialIcon: "login"
                                mainText: Translation.tr("Connect")
                                enabled: !Network.wifiConnecting
                                onClicked: Network.connectSavedProfile(modelData)
                            }
                            RippleButtonWithIcon {
                                materialIcon: "delete"
                                mainText: Translation.tr("Forget")
                                enabled: !Network.wifiConnecting
                                onClicked: Network.forgetWifiProfile(modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: ethernetPage

        SettingsSubPage {
            id: ethernetRoot

            // Standalone Settings has its own Network singleton; take one
            // authoritative snapshot when this page is opened.
            Component.onCompleted: Network.refresh()

            function details(device) {
                const parts = [];
                if (device.ipv4) parts.push(`${Translation.tr("IPv4")}: ${device.ipv4}`);
                if (device.ipv6) parts.push(`${Translation.tr("IPv6")}: ${device.ipv6}`);
                if (device.gateway) parts.push(`${Translation.tr("Gateway")}: ${device.gateway}`);
                if (device.dns) parts.push(`${Translation.tr("DNS")}: ${device.dns}`);
                return parts.join("\n");
            }

            SettingsGroup {
                title: Translation.tr("Ethernet")

                SettingsRow {
                    visible: Network.ethernetDevices.length === 0
                    icon: "lan"
                    title: Translation.tr("No Ethernet adapter detected")
                    description: Translation.tr("Connect a built-in, USB, or dock Ethernet adapter to configure wired networking.")
                    registerInSearch: false
                }

                Repeater {
                    model: Network.ethernetDevices

                    SettingsGroup {
                        required property var modelData
                        readonly property var deviceModel: modelData
                        title: deviceModel.interfaceName

                        SettingsRow {
                            icon: deviceModel.connected ? "lan" : "lan_disconnect"
                            title: deviceModel.state
                            description: [deviceModel.activeProfile, deviceModel.speed].filter(value => value && value.length > 0).join(" · ")
                            registerInSearch: false

                            RippleButtonWithIcon {
                                visible: deviceModel.connected
                                materialIcon: "link_off"
                                mainText: Translation.tr("Disconnect")
                                enabled: !Network.wifiConnecting
                                onClicked: Network.disconnectEthernet(deviceModel)
                            }
                        }

                        SettingsRow {
                            visible: deviceModel.connected
                            icon: "lan"
                            title: Translation.tr("Connection details")
                            description: ethernetRoot.details(deviceModel)
                            registerInSearch: false
                        }

                        Repeater {
                            model: deviceModel.profiles

                            SettingsRow {
                                required property var modelData
                                visible: !modelData.active
                                icon: "bookmark"
                                title: modelData.id
                                description: modelData.interfaceName || Translation.tr("Available wired profile")
                                registerInSearch: false

                                RippleButtonWithIcon {
                                    mainText: Translation.tr("Connect")
                                    materialIcon: "login"
                                    enabled: !Network.wifiConnecting
                                    onClicked: Network.connectEthernetProfile(modelData, deviceModel)
                                }
                            }
                        }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Saved Connections")
                visible: Network.ethernetProfilesList.length > 0

                Repeater {
                    model: Network.ethernetProfilesList

                    SettingsRow {
                        required property var modelData
                        icon: "bookmark"
                        title: modelData.id
                        description: modelData.interfaceName || Translation.tr("Wired connection")
                        registerInSearch: false

                        RippleButtonWithIcon {
                            visible: Network.ethernetDevices.length > 0
                            materialIcon: "login"
                            mainText: Translation.tr("Connect")
                            enabled: !Network.wifiConnecting
                            onClicked: {
                                const device = Network.ethernetDevices.find(item => !modelData.interfaceName || item.interfaceName === modelData.interfaceName) || Network.ethernetDevices[0];
                                Network.connectEthernetProfile(modelData, device);
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: hotspotPage

        SettingsSubPage {
            id: hotspotRoot

            property string draftSsid: Network.hotspotSsid || "My Hotspot"
            property string draftPassword: ""
            property string draftBand: Network.hotspotBand || ""
            property bool confirmingStart: false
            property bool syncing: false
            property bool draftTouched: false
            property bool readyForEdits: false

            Component.onCompleted: readyForEdits = true

            function bandIndex() {
                const index = Network.hotspotBands.findIndex(item => item.value === hotspotRoot.draftBand);
                return index >= 0 ? index : 0;
            }

            function start(confirmed = false) {
                const result = Network.startHotspot(hotspotRoot.draftSsid, hotspotRoot.draftPassword, hotspotRoot.draftBand, confirmed);
                if (result === "confirm") hotspotRoot.confirmingStart = true;
                else if (result === true) {
                    hotspotRoot.confirmingStart = false;
                    hotspotRoot.draftPassword = "";
                }
            }

            Connections {
                target: Network
                function onHotspotProfileChanged() {
                    if (!hotspotRoot.draftTouched && !Network.hotspotStarting) {
                        hotspotRoot.draftSsid = Network.hotspotSsid || "My Hotspot";
                        hotspotRoot.draftBand = Network.hotspotBand || "";
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Hotspot")

                SettingsRow {
                    icon: Network.hotspotStatus === "on" ? "wifi_tethering" : Network.hotspotStatus === "failed" ? "error" : "wifi_find"
                    title: Network.hotspotStatus === "on" ? Translation.tr("On") : Network.hotspotStatus === "starting" ? Translation.tr("Starting…") : Network.hotspotStatus === "stopping" ? Translation.tr("Stopping…") : Network.hotspotStatus === "failed" ? Translation.tr("Failed") : Network.hotspotSupported ? Translation.tr("Off") : Translation.tr("Unsupported")
                    description: Network.hotspotInterface.length > 0 ? `${Network.hotspotInterface}${Network.hotspotHasUpstream ? ` · ${Translation.tr("Upstream connection available")}` : ` · ${Translation.tr("Local network only")}`}` : Translation.tr("No AP-capable Wi-Fi device detected")
                    registerInSearch: false
                }

                SettingsRow {
                    visible: Network.hotspotError.length > 0
                    icon: "error"
                    title: Translation.tr("Hotspot operation failed")
                    description: Network.hotspotError
                    registerInSearch: false
                }

                SettingsRow {
                    visible: Network.hotspotSupported && !Network.hotspotActive
                    icon: "badge"
                    title: Translation.tr("Network name")
                    description: Translation.tr("Visible to nearby devices")
                    registerInSearch: false

                    MaterialTextField {
                        Layout.preferredWidth: 220
                        text: hotspotRoot.draftSsid
                        placeholderText: Translation.tr("My Hotspot")
                        onTextChanged: if (hotspotRoot.readyForEdits && !hotspotRoot.syncing) { hotspotRoot.draftSsid = text; hotspotRoot.draftTouched = true; }
                    }
                }

                SettingsRow {
                    visible: Network.hotspotSupported && !Network.hotspotActive
                    icon: "lock"
                    title: Translation.tr("Password")
                    description: Network.hotspotProfile ? Translation.tr("Leave blank to keep the current password") : Translation.tr("WPA2-Personal, 8–63 characters")
                    registerInSearch: false

                    MaterialTextField {
                        Layout.preferredWidth: 220
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData
                        text: hotspotRoot.draftPassword
                        placeholderText: Network.hotspotProfile ? Translation.tr("Change password") : Translation.tr("Password")
                        onTextChanged: if (hotspotRoot.readyForEdits && !hotspotRoot.syncing) { hotspotRoot.draftPassword = text; hotspotRoot.draftTouched = true; }
                    }
                }

                SettingsRow {
                    visible: Network.hotspotSupported && !Network.hotspotActive
                    icon: "wifi"
                    title: Translation.tr("Band")
                    description: Translation.tr("Automatic lets NetworkManager choose a compatible channel")
                    registerInSearch: false

                    StyledComboBox {
                        textRole: "label"
                        model: Network.hotspotBands
                        currentIndex: hotspotRoot.bandIndex()
                        onActivated: index => { hotspotRoot.draftBand = model[index].value; hotspotRoot.draftTouched = true; }
                    }
                }

                SettingsRow {
                    visible: Network.hotspotSupported && !Network.hotspotActive && hotspotRoot.confirmingStart
                    icon: "warning"
                    title: Translation.tr("Current Wi-Fi may be interrupted")
                    description: Translation.tr("Starting the hotspot can interrupt the current Wi-Fi connection.")
                    registerInSearch: false

                    RowLayout {
                        spacing: 8
                        DialogButton {
                            buttonText: Translation.tr("Cancel")
                            onClicked: hotspotRoot.confirmingStart = false
                        }
                        DialogButton {
                            buttonText: Translation.tr("Start")
                            colBackground: Appearance.colors.colPrimary
                            colText: Appearance.colors.colOnPrimary
                            onClicked: hotspotRoot.start(true)
                        }
                    }
                }

                SettingsRow {
                    visible: Network.hotspotSupported && !Network.hotspotActive && !hotspotRoot.confirmingStart
                    icon: "play_arrow"
                    title: Translation.tr("Start Hotspot")
                    description: Network.hotspotMayInterruptWifi ? Translation.tr("May interrupt the current Wi-Fi connection") : Translation.tr("Creates a local Wi-Fi network")
                    registerInSearch: false

                    DialogButton {
                        buttonText: Network.hotspotStarting ? Translation.tr("Starting…") : Translation.tr("Start Hotspot")
                        enabled: !Network.hotspotStarting && !Network.hotspotStopping
                        colBackground: Appearance.colors.colPrimary
                        colText: Appearance.colors.colOnPrimary
                        onClicked: hotspotRoot.start()
                    }
                }

                SettingsRow {
                    visible: Network.hotspotActive
                    icon: "wifi_tethering"
                    title: hotspotRoot.draftSsid || Network.hotspotSsid
                    description: [Network.hotspotBand === "a" ? "5 GHz" : Network.hotspotBand === "bg" ? "2.4 GHz" : Translation.tr("Automatic"), Network.hotspotHasUpstream ? Translation.tr("Upstream connection available") : Translation.tr("Local network only")].join(" · ")
                    registerInSearch: false

                    DialogButton {
                        buttonText: Network.hotspotStopping ? Translation.tr("Stopping…") : Translation.tr("Stop Hotspot")
                        enabled: !Network.hotspotStarting && !Network.hotspotStopping
                        onClicked: Network.stopHotspot()
                    }
                }
            }
        }
    }

    Component {
        id: keyboardPage
        KeyboardConfig {}
    }

    Component {
        id: mouseTouchpadPage
        MouseTouchpadConfig {}
    }

    Component {
        id: printersPage
        PrintersConfig {}
    }

    Component {
        id: gameControllersPage
        GameControllersConfig {}
    }

    Component {
        id: otherDevicesPage
        OtherDevicesConfig {}
    }

    Component {
        id: proxyPage

        SettingsSubPage {
            id: proxyRoot

            property bool syncing: false
            property bool dirty: false
            property string draftMode: "none"
            property string draftPacUrl: ""
            property string draftHttpHost: ""
            property string draftHttpPort: "8080"
            property string draftHttpsHost: ""
            property string draftHttpsPort: ""
            property string draftSocksHost: ""
            property string draftSocksPort: ""
            property string draftIgnoreHosts: ""

            function loadAuthoritative() {
                syncing = true;
                draftMode = ProxySettings.mode;
                draftPacUrl = ProxySettings.pacUrl;
                draftHttpHost = ProxySettings.httpHost;
                draftHttpPort = ProxySettings.httpPort > 0 ? String(ProxySettings.httpPort) : "";
                draftHttpsHost = ProxySettings.httpsHost;
                draftHttpsPort = ProxySettings.httpsPort > 0 ? String(ProxySettings.httpsPort) : "";
                draftSocksHost = ProxySettings.socksHost;
                draftSocksPort = ProxySettings.socksPort > 0 ? String(ProxySettings.socksPort) : "";
                draftIgnoreHosts = ProxySettings.ignoreHosts.join(", ");
                dirty = false;
                syncing = false;
            }

            function markDirty() { if (!syncing) dirty = true; }
            function applyDraft() {
                return ProxySettings.apply({
                    mode: draftMode,
                    pacUrl: draftPacUrl,
                    httpHost: draftHttpHost,
                    httpPort: Number(draftHttpPort || 0),
                    httpsHost: draftHttpsHost,
                    httpsPort: Number(draftHttpsPort || 0),
                    socksHost: draftSocksHost,
                    socksPort: Number(draftSocksPort || 0),
                    ignoreHosts: draftIgnoreHosts
                });
            }

            Component.onCompleted: proxyRoot.loadAuthoritative()
            Connections {
                target: ProxySettings
                function onPolicyChangedExternally() {
                    if (!proxyRoot.dirty && !ProxySettings.applying)
                        proxyRoot.loadAuthoritative();
                }
            }

            SettingsGroup {
                title: Translation.tr("Mode")

                SettingsRow {
                    icon: "settings_ethernet"
                    title: Translation.tr("Proxy mode")
                    description: proxyRoot.draftMode === "none" ? Translation.tr("Off") : proxyRoot.draftMode === "auto" ? Translation.tr("Automatic") : Translation.tr("Manual")

                    StyledComboBox {
                        textRole: "label"
                        model: [
                            { label: Translation.tr("Off"), value: "none" },
                            { label: Translation.tr("Automatic"), value: "auto" },
                            { label: Translation.tr("Manual"), value: "manual" }
                        ]
                        currentIndex: Math.max(0, model.findIndex(item => item.value === proxyRoot.draftMode))
                        onActivated: index => { proxyRoot.draftMode = model[index].value; proxyRoot.markDirty(); }
                    }
                }

                SettingsRow {
                    visible: proxyRoot.draftMode === "none"
                    icon: "check"
                    title: Translation.tr("No proxy is configured")
                    description: Translation.tr("New applications will use their normal network settings.")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Automatic Proxy")
                visible: proxyRoot.draftMode === "auto"

                SettingsRow {
                    icon: "link"
                    title: Translation.tr("Configuration URL")
                    description: Translation.tr("Used by applications that support the desktop proxy resolver.")
                    registerInSearch: false

                    MaterialTextField {
                        Layout.preferredWidth: 300
                        placeholderText: "https://example.com/proxy.pac"
                        text: proxyRoot.draftPacUrl
                        onTextChanged: { if (!proxyRoot.syncing) { proxyRoot.draftPacUrl = text; proxyRoot.markDirty(); } }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Manual Proxy")
                visible: proxyRoot.draftMode === "manual"

                SettingsRow {
                    icon: "http"
                    title: Translation.tr("HTTP proxy")
                    description: Translation.tr("Unauthenticated endpoint")
                    registerInSearch: false
                    RowLayout {
                        spacing: 6
                        MaterialTextField {
                            Layout.preferredWidth: 190
                            placeholderText: Translation.tr("Host")
                            text: proxyRoot.draftHttpHost
                            onTextChanged: { if (!proxyRoot.syncing) { proxyRoot.draftHttpHost = text; proxyRoot.markDirty(); } }
                        }
                        NumberInput {
                            value: Number(proxyRoot.draftHttpPort || 0)
                            minimum: 1
                            maximum: 65535
                            allowEmpty: true
                            unit: Translation.tr("Port")
                            onTextCommitted: text => { if (!proxyRoot.syncing) { proxyRoot.draftHttpPort = text; proxyRoot.markDirty(); } }
                        }
                    }
                }

                SettingsRow {
                    icon: "https"
                    title: Translation.tr("HTTPS proxy")
                    description: Translation.tr("Unauthenticated endpoint")
                    registerInSearch: false
                    RowLayout {
                        spacing: 6
                        MaterialTextField {
                            Layout.preferredWidth: 190
                            placeholderText: Translation.tr("Host")
                            text: proxyRoot.draftHttpsHost
                            onTextChanged: { if (!proxyRoot.syncing) { proxyRoot.draftHttpsHost = text; proxyRoot.markDirty(); } }
                        }
                        NumberInput {
                            value: Number(proxyRoot.draftHttpsPort || 0)
                            minimum: 1
                            maximum: 65535
                            allowEmpty: true
                            unit: Translation.tr("Port")
                            onTextCommitted: text => { if (!proxyRoot.syncing) { proxyRoot.draftHttpsPort = text; proxyRoot.markDirty(); } }
                        }
                    }
                }

                SettingsRow {
                    icon: "lock"
                    title: Translation.tr("SOCKS proxy")
                    description: Translation.tr("Unauthenticated endpoint")
                    registerInSearch: false
                    RowLayout {
                        spacing: 6
                        MaterialTextField {
                            Layout.preferredWidth: 190
                            placeholderText: Translation.tr("Host")
                            text: proxyRoot.draftSocksHost
                            onTextChanged: { if (!proxyRoot.syncing) { proxyRoot.draftSocksHost = text; proxyRoot.markDirty(); } }
                        }
                        NumberInput {
                            value: Number(proxyRoot.draftSocksPort || 0)
                            minimum: 1
                            maximum: 65535
                            allowEmpty: true
                            unit: Translation.tr("Port")
                            onTextCommitted: text => { if (!proxyRoot.syncing) { proxyRoot.draftSocksPort = text; proxyRoot.markDirty(); } }
                        }
                    }
                }

                SettingsRow {
                    icon: "block"
                    title: Translation.tr("Bypass proxy for")
                    description: Translation.tr("Comma-separated hosts or patterns")
                    registerInSearch: false
                    MaterialTextField {
                        Layout.preferredWidth: 300
                        placeholderText: "localhost, 127.0.0.1, ::1"
                        text: proxyRoot.draftIgnoreHosts
                        onTextChanged: { if (!proxyRoot.syncing) { proxyRoot.draftIgnoreHosts = text; proxyRoot.markDirty(); } }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Apply")

                SettingsRow {
                    icon: ProxySettings.error.length > 0 ? "error" : "save"
                    title: ProxySettings.error.length > 0 ? ProxySettings.error : Translation.tr("Apply proxy settings")
                    description: proxyRoot.draftMode === "auto"
                        ? Translation.tr("Automatic proxy is available to desktop proxy-aware applications.")
                        : Translation.tr("Applies to newly launched and proxy-aware applications. Running applications may need to be restarted.")
                    registerInSearch: false

                    DialogButton {
                        buttonText: ProxySettings.applying ? Translation.tr("Applying…") : Translation.tr("Apply")
                        enabled: proxyRoot.dirty && !ProxySettings.applying
                        onClicked: proxyRoot.applyDraft()
                    }
                }
            }
        }
    }

    Component {
        id: vpnPage

        SettingsSubPage {
            id: vpnRoot

            function activeDescription(connection) {
                const lines = [connection.type, connection.state];
                if (connection.interfaceName) lines.push(`${Translation.tr("Interface")}: ${connection.interfaceName}`);
                if (connection.ipv4.length > 0) lines.push(`${Translation.tr("IPv4")}: ${connection.ipv4.join(", ")}`);
                if (connection.ipv6.length > 0) lines.push(`${Translation.tr("IPv6")}: ${connection.ipv6.join(", ")}`);
                if (connection.dns4.length > 0 || connection.dns6.length > 0)
                    lines.push(`${Translation.tr("DNS")}: ${connection.dns4.concat(connection.dns6).join(", ")}`);
                return lines.join("\n");
            }

            SettingsGroup {
                title: Translation.tr("VPN")

                SettingsRow {
                    visible: Network.activeVpnConnections.length === 0 && Network.vpnProfiles.length === 0
                    icon: "vpn_key"
                    title: Translation.tr("No VPN connections configured")
                    description: Translation.tr("VPN connections added through NetworkManager will appear here.")
                    registerInSearch: false
                }

                Repeater {
                    model: Network.activeVpnConnections

                    SettingsRow {
                        required property var modelData
                        icon: modelData.state === "Connected" ? "vpn_lock" : "vpn_key"
                        title: modelData.profile
                        description: vpnRoot.activeDescription(modelData)
                        registerInSearch: false

                        RippleButtonWithIcon {
                            materialIcon: "link_off"
                            mainText: Translation.tr("Disconnect")
                            enabled: modelData.state !== "Connecting"
                            onClicked: Network.disconnectVpn(modelData)
                        }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Saved VPNs")
                visible: Network.vpnProfiles.length > 0

                Repeater {
                    model: Network.vpnProfiles

                    SettingsRow {
                        required property var modelData
                        icon: modelData.active ? "vpn_lock" : "vpn_key"
                        title: modelData.id
                        description: modelData.displayType + (modelData.active ? ` · ${Translation.tr("Connected")}` : "")
                        registerInSearch: false

                        RippleButtonWithIcon {
                            visible: !modelData.active
                            materialIcon: "link"
                            mainText: Translation.tr("Connect")
                            enabled: modelData.available !== false && !Network.wifiConnecting
                            onClicked: Network.connectVpnProfile(modelData)
                        }
                    }
                }
            }
        }
    }

    Component {
        id: bluetoothPage

        SettingsSubPage {
            id: bluetoothRoot

            function statusText(device) {
                    const parts = [];
                if (device.connected) parts.push(Translation.tr("Connected"));
                else if (device.pairing) parts.push(Translation.tr("Pairing…"));
                else if (BluetoothStatus.deviceConnecting(device)) parts.push(Translation.tr("Connecting…"));
                else if (device.paired) parts.push(Translation.tr("Paired"));
                else parts.push(Translation.tr("Available"));
                if (device.batteryAvailable)
                    parts.push(`${Math.round(device.battery * 100)}%`);
                return parts.join(" · ");
            }

            function addressLine(device) {
                const details = [BluetoothStatus.deviceType(device), bluetoothRoot.statusText(device)];
                if (device.address) details.push(device.address);
                if (device.trusted) details.push(Translation.tr("Trusted"));
                return details.join(" · ");
            }

            SettingsGroup {
                title: Translation.tr("Bluetooth")

                SettingsToggleRow {
                    icon: BluetoothStatus.blocked ? "bluetooth_disabled" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                    title: Translation.tr("Bluetooth")
                    description: BluetoothStatus.blocked ? Translation.tr("Bluetooth is blocked") : BluetoothStatus.enabled ? Translation.tr("On") : Translation.tr("Off")
                    checked: BluetoothStatus.enabled
                    enabled: BluetoothStatus.available && !BluetoothStatus.blocked
                    onToggled: checked => {
                        if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = checked;
                    }
                }

                SettingsRow {
                    icon: "info"
                    title: Translation.tr("Status")
                    description: BluetoothStatus.blocked ? Translation.tr("Blocked") : BluetoothStatus.enabled ? Translation.tr("On") : Translation.tr("Off")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("My Devices")
                visible: BluetoothStatus.pairedDevices.length > 0

                Repeater {
                    model: BluetoothStatus.pairedDevices

                    ColumnLayout {
                        id: deviceDelegate
                        required property var modelData
                        property bool confirmingForget: false
                        Layout.fillWidth: true

                        SettingsRow {
                            icon: Icons.getBluetoothDeviceMaterialSymbol(modelData.icon || "")
                            title: BluetoothStatus.deviceName(modelData)
                            description: bluetoothRoot.addressLine(modelData)
                            registerInSearch: false

                            RowLayout {
                                spacing: 6

                                RippleButtonWithIcon {
                                    materialIcon: modelData.connected ? "link_off" : "link"
                                    mainText: modelData.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")
                                    enabled: !modelData.pairing && !BluetoothStatus.deviceConnecting(modelData)
                                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                }

                                RippleButtonWithIcon {
                                    materialIcon: "delete"
                                    mainText: Translation.tr("Forget")
                                    enabled: !modelData.pairing && !BluetoothStatus.deviceConnecting(modelData)
                                    onClicked: deviceDelegate.confirmingForget = true
                                }
                            }
                        }

                        SettingsRow {
                            visible: deviceDelegate.confirmingForget
                            icon: "warning"
                            title: Translation.tr("Forget this device?")
                            description: Translation.tr("You will need to pair it again before connecting.")
                            registerInSearch: false

                            RowLayout {
                                spacing: 6
                                RippleButtonWithIcon {
                                    materialIcon: "close"
                                    mainText: Translation.tr("Cancel")
                                    onClicked: deviceDelegate.confirmingForget = false
                                }
                                RippleButtonWithIcon {
                                    materialIcon: "delete"
                                    mainText: Translation.tr("Forget")
                                    onClicked: {
                                        modelData.forget();
                                        deviceDelegate.confirmingForget = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            SettingsGroup {
                title: Translation.tr("Available Devices")
                visible: BluetoothStatus.enabled

                SettingsRow {
                    icon: "bluetooth_searching"
                    title: BluetoothStatus.discoveryRequested("settings") ? Translation.tr("Scanning…") : Translation.tr("Scan for devices")
                    description: Translation.tr("Nearby unpaired devices appear here.")
                    clickable: true
                    enabled: BluetoothStatus.available
                    onClicked: {
                        if (BluetoothStatus.discoveryRequested("settings"))
                            BluetoothStatus.releaseDiscovery("settings");
                        else
                            BluetoothStatus.acquireDiscovery("settings");
                    }
                    registerInSearch: false
                }

                Repeater {
                    model: BluetoothStatus.availableDevices

                    ColumnLayout {
                        id: availableDelegate
                        required property var modelData
                        property bool pairFailed: false
                        Layout.fillWidth: true

                        Connections {
                            target: availableDelegate.modelData
                            function onPairedChanged() {
                                if (availableDelegate.modelData.paired)
                                    availableDelegate.pairFailed = false;
                            }
                            function onPairingChanged() {
                                if (!availableDelegate.modelData.pairing && !availableDelegate.modelData.paired)
                                    availableDelegate.pairFailed = true;
                            }
                        }

                        SettingsRow {
                        icon: Icons.getBluetoothDeviceMaterialSymbol(modelData.icon || "")
                        title: BluetoothStatus.deviceName(modelData)
                            description: availableDelegate.pairFailed
                                ? Translation.tr("Couldn't pair")
                                : [BluetoothStatus.deviceType(modelData), modelData.address].filter(value => value).join(" · ")
                        registerInSearch: false

                        RippleButtonWithIcon {
                            materialIcon: "bluetooth"
                            mainText: Translation.tr("Pair")
                            enabled: !modelData.pairing
                            onClicked: {
                                availableDelegate.pairFailed = false;
                                modelData.pair();
                            }
                        }
                        }
                    }
                }

                SettingsRow {
                    visible: BluetoothStatus.availableDevices.length === 0
                    icon: "bluetooth_disabled"
                    title: BluetoothStatus.discoveryRequested("settings") ? Translation.tr("No unpaired devices found") : Translation.tr("Scan to find nearby devices")
                    description: Translation.tr("Paired devices are listed above.")
                    registerInSearch: false
                }
            }
        }
    }

    Component {
        id: storagePage

        SettingsSubPage {
            id: storageRoot
            property var pendingStorageAction: null

            function sizeText(volume) {
                if (!volume || !volume.size)
                    return Translation.tr("Capacity unavailable");
                const used = volume.used > 0 ? `${Storage.humanSize(volume.used)} / ` : "";
                return `${used}${Storage.humanSize(volume.size)}`;
            }

            function volumeDescription(volume) {
                const mount = volume.mountPoints.length > 0 ? volume.mountPoints.join(", ") : Translation.tr("Not mounted");
                const details = [volume.filesystem, mount].filter(value => value.length > 0).join(" · ");
                return `${details}\n${storageRoot.sizeText(volume)}`;
            }
            function requestStorageAction(volume, action) { pendingStorageAction = { volume: volume, action: action }; }
            function confirmStorageAction() {
                const pending = storageRoot.pendingStorageAction;
                if (!pending) return;
                if (pending.action === "eject") Storage.eject(pending.volume);
                else if (pending.action === "powerOff") Storage.powerOff(pending.volume);
                pendingStorageAction = null;
            }

            SettingsGroup {
                title: Translation.tr("Storage")

                SettingsRow {
                    icon: "hard_drive"
                    title: Storage.ready ? `${Storage.humanSize(Storage.overviewUsed)} ${Translation.tr("used")}` : Translation.tr("Loading storage…")
                    description: Storage.ready
                        ? `${Storage.humanSize(Storage.overviewAvailable)} ${Translation.tr("available")} · ${Storage.overviewPercent.toFixed(0)}% ${Translation.tr("used")}`
                        : Translation.tr("Reading mounted filesystems")

                    ColumnLayout {
                        width: 250
                        spacing: 5

                        Rectangle {
                            Layout.fillWidth: true
                            height: 8
                            radius: 4
                            color: Appearance.colors.colSurfaceContainerHighest

                            Rectangle {
                                width: parent.width * Math.min(1, Math.max(0, Storage.overviewPercent / 100))
                                height: parent.height
                                radius: 4
                                color: Appearance.colors.colPrimary
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: Storage.ready ? `${Storage.humanSize(Storage.overviewTotal)} ${Translation.tr("total")}` : ""
                            color: Appearance.colors.colOnSurfaceVariant
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                SettingsRow {
                    visible: Storage.error.length > 0
                    icon: "error"
                    title: Translation.tr("Storage service error")
                    description: Storage.error
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("System Storage")

                Repeater {
                    model: Storage.volumes.filter(volume => volume.system || volume.mountPoints.includes("/home"))

                    SettingsRow {
                        required property var modelData
                        icon: modelData.mountPoints.includes("/") ? "computer" : "folder"
                        title: modelData.mountPoints.includes("/") ? Translation.tr("System") : Translation.tr("Home")
                        description: storageRoot.volumeDescription(modelData)

                        StyledText {
                            text: modelData.used > 0 ? `${(modelData.used / modelData.size * 100).toFixed(0)}%` : ""
                            color: Appearance.colors.colOnSurfaceVariant
                        }
                    }
                }

                SettingsRow {
                    visible: Storage.ready && Storage.volumes.filter(volume => volume.system || volume.mountPoints.includes("/home")).length === 0
                    icon: "info"
                    title: Translation.tr("No system filesystem found")
                    description: Translation.tr("Mounted system storage will appear here.")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Disks & Volumes")

                Repeater {
                    model: Storage.drives

                    SettingsGroup {
                        required property var modelData
                        title: modelData.model || modelData.vendor || Translation.tr("Storage drive")

                        SettingsRow {
                            icon: modelData.removable ? "usb" : "hard_drive"
                            title: modelData.model || Translation.tr("Unknown drive")
                            description: [modelData.vendor, Storage.humanSize(modelData.size)].filter(value => value && value.length > 0).join(" · ")
                            registerInSearch: false
                        }

                        Repeater {
                            model: modelData.volumes.filter(volume => !volume.technical)

                            SettingsRow {
                                required property var modelData
                                icon: modelData.mounted ? "folder" : "storage"
                                title: modelData.label || (modelData.system ? Translation.tr("System") : modelData.device)
                                description: storageRoot.volumeDescription(modelData)
                                registerInSearch: false

                                RowLayout {
                                    spacing: 6

                                    RippleButtonWithIcon {
                                        visible: modelData.removable && modelData.mounted
                                        materialIcon: "eject"
                                        mainText: Translation.tr("Unmount")
                                        enabled: !Storage.busy
                                        onClicked: Storage.unmount(modelData)
                                    }

                                    RippleButtonWithIcon {
                                        visible: modelData.removable && !modelData.mounted
                                        materialIcon: "folder_open"
                                        mainText: Translation.tr("Mount")
                                        enabled: !Storage.busy
                                        onClicked: Storage.mount(modelData)
                                    }

                                    RippleButtonWithIcon {
                                        visible: modelData.ejectable && (!storageRoot.pendingStorageAction || storageRoot.pendingStorageAction.volume !== modelData)
                                        materialIcon: "eject"
                                        mainText: Translation.tr("Eject")
                                        enabled: !Storage.busy
                                        onClicked: storageRoot.requestStorageAction(modelData, "eject")
                                    }

                                    RippleButtonWithIcon {
                                        visible: modelData.canPowerOff && (!storageRoot.pendingStorageAction || storageRoot.pendingStorageAction.volume !== modelData)
                                        materialIcon: "power_settings_new"
                                        mainText: Translation.tr("Safely Remove")
                                        enabled: !Storage.busy
                                        onClicked: storageRoot.requestStorageAction(modelData, "powerOff")
                                    }

                                    DialogButton {
                                        visible: storageRoot.pendingStorageAction?.volume === modelData
                                        buttonText: Translation.tr("Confirm")
                                        enabled: !Storage.busy
                                        onClicked: storageRoot.confirmStorageAction()
                                    }

                                    DialogButton {
                                        visible: storageRoot.pendingStorageAction?.volume === modelData
                                        buttonText: Translation.tr("Cancel")
                                        onClicked: storageRoot.pendingStorageAction = null
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsRow {
                    visible: Storage.ready && Storage.drives.length === 0
                    icon: "hard_drive"
                    title: Translation.tr("No drives detected")
                    description: Translation.tr("Connected storage devices will appear here.")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Removable Storage")
                visible: Storage.drives.some(drive => drive.removable)

                Repeater {
                    model: Storage.volumes.filter(volume => volume.removable && !volume.technical)

                    SettingsRow {
                        required property var modelData
                        icon: "usb"
                        title: modelData.label || modelData.device
                        description: storageRoot.volumeDescription(modelData)
                        registerInSearch: false
                    }
                }
            }
        }
    }

    Component {
        id: powerBatteryPage
        PowerBatteryConfig {}
    }

    Component {
        id: systemInfoPage

        SettingsSubPage {
            id: infoRoot

            property bool copied: false

            function memoryText() {
                return SystemInfo.memoryTotalBytes > 0
                    ? Storage.humanSize(SystemInfo.memoryTotalBytes)
                    : Translation.tr("Unavailable");
            }

            function graphicsText() {
                return SystemInfo.gpuNames.length > 0
                    ? SystemInfo.gpuNames.join("\n")
                    : Translation.tr("Unavailable");
            }

            function storageText() {
                if (!Storage.ready || Storage.overviewTotal <= 0)
                    return Translation.tr("Unavailable");
                return `${Storage.humanSize(Storage.overviewUsed)} ${Translation.tr("used")} · ${Storage.humanSize(Storage.overviewAvailable)} ${Translation.tr("available")} / ${Storage.humanSize(Storage.overviewTotal)}`;
            }

            function summary() {
                const lines = [
                    `OS: ${SystemInfo.distroName || Translation.tr("Unknown")}${SystemInfo.distroVersion ? ` ${SystemInfo.distroVersion}` : ""}`,
                    `Kernel: ${SystemInfo.kernel || Translation.tr("Unknown")}`,
                    `Architecture: ${SystemInfo.architecture || Translation.tr("Unknown")}`,
                    `Desktop: ${SystemInfo.desktopEnvironment || Translation.tr("Unknown")}`,
                    `Session: ${SystemInfo.windowingSystem || Translation.tr("Unknown")}`,
                    `CPU: ${SystemInfo.cpuModel || Translation.tr("Unknown")}`,
                    `Memory: ${infoRoot.memoryText()}`,
                    `GPU: ${SystemInfo.gpuNames.join("; ") || Translation.tr("Unknown")}`,
                    `Storage: ${infoRoot.storageText()}`,
                    `Uptime: ${SystemInfo.formatUptime()}`
                ];
                if (SystemInfo.hyprlandVersion)
                    lines.push(`Hyprland: ${SystemInfo.hyprlandVersion}`);
                if (SystemInfo.quickshellVersion)
                    lines.push(`Quickshell: ${SystemInfo.quickshellVersion}`);
                return lines.join("\n");
            }

            Timer {
                id: copiedTimer
                interval: 1800
                repeat: false
                onTriggered: infoRoot.copied = false
            }

            SettingsGroup {
                title: Translation.tr("Device")

                SettingsRow {
                    icon: "computer"
                    title: Translation.tr("Device name")
                    description: SystemInfo.hostname || Translation.tr("Unavailable")
                }

                SettingsRow {
                    visible: SystemInfo.deviceModel.length > 0
                    icon: "laptop"
                    title: Translation.tr("Model")
                    description: [SystemInfo.deviceVendor, SystemInfo.deviceModel].filter(value => value.length > 0).join(" ")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Operating System")

                SettingsRow {
                    icon: "developer_board"
                    title: Translation.tr("Operating system")
                    description: SystemInfo.distroName || Translation.tr("Unavailable")
                }

                SettingsRow {
                    visible: SystemInfo.distroVersion.length > 0
                    icon: "info"
                    title: Translation.tr("Version")
                    description: SystemInfo.distroVersion
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "terminal"
                    title: Translation.tr("Kernel")
                    description: SystemInfo.kernel || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "architecture"
                    title: Translation.tr("Architecture")
                    description: SystemInfo.architecture || Translation.tr("Unavailable")
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Hardware")

                SettingsRow {
                    icon: "memory"
                    title: Translation.tr("Processor")
                    description: SystemInfo.cpuModel || Translation.tr("Unavailable")
                }

                SettingsRow {
                    icon: "memory"
                    title: Translation.tr("Memory")
                    description: infoRoot.memoryText()
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "developer_board"
                    title: Translation.tr("Graphics")
                    description: infoRoot.graphicsText()
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "hard_drive"
                    title: Translation.tr("Storage")
                    description: infoRoot.storageText()
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("System")

                SettingsRow {
                    icon: "schedule"
                    title: Translation.tr("Uptime")
                    description: SystemInfo.formatUptime()
                }

                SettingsRow {
                    icon: "desktop_windows"
                    title: Translation.tr("Desktop")
                    description: SystemInfo.desktopEnvironment || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    icon: "language"
                    title: Translation.tr("Display server")
                    description: SystemInfo.windowingSystem || Translation.tr("Unavailable")
                    registerInSearch: false
                }

                SettingsRow {
                    visible: SystemInfo.hyprlandVersion.length > 0
                    icon: "layers"
                    title: Translation.tr("Hyprland")
                    description: SystemInfo.hyprlandVersion
                    registerInSearch: false
                }

                SettingsRow {
                    visible: SystemInfo.quickshellVersion.length > 0
                    icon: "code"
                    title: Translation.tr("Quickshell")
                    description: SystemInfo.quickshellVersion
                    registerInSearch: false
                }
            }

            SettingsGroup {
                title: Translation.tr("Diagnostic summary")

                SettingsRow {
                    icon: infoRoot.copied ? "check" : "content_copy"
                    title: infoRoot.copied ? Translation.tr("Copied") : Translation.tr("Copy System Information")
                    description: Translation.tr("Copies a safe summary without serial numbers, UUIDs, network addresses, or account names.")
                    clickable: true
                    onClicked: {
                        Quickshell.clipboardText = infoRoot.summary();
                        infoRoot.copied = true;
                        copiedTimer.restart();
                    }
                }
            }
        }
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
            property bool datePickerOpen: false
            property bool timePickerOpen: false
            property bool timezonePickerOpen: false

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

            function timezoneOffsetLabel() {
                const minutes = -new Date().getTimezoneOffset();
                const sign = minutes >= 0 ? "+" : "-";
                const absolute = Math.abs(minutes);
                return `UTC${sign}${Math.floor(absolute / 60).toString().padStart(2, "0")}:${(absolute % 60).toString().padStart(2, "0")}`;
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
                id: dateRow
                visible: !dateTimeRoot.datePickerOpen && !dateTimeRoot.timePickerOpen && !dateTimeRoot.timezonePickerOpen
                icon: "calendar_today"
                title: Translation.tr("Date")
                description: Qt.locale().toString(DateTime.clock.date, "dd MMMM yyyy")
                registerInSearch: false
                clickable: !TimeDate.ntpEnabled
                enabled: !TimeDate.ntpEnabled && !TimeDate.operationPending
                onClicked: dateTimeRoot.datePickerOpen = true

                MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }

            SettingsRow {
                id: timeRow
                visible: !dateTimeRoot.datePickerOpen && !dateTimeRoot.timePickerOpen && !dateTimeRoot.timezonePickerOpen
                icon: "schedule"
                title: Translation.tr("Time")
                description: DateTime.time
                registerInSearch: false
                clickable: !TimeDate.ntpEnabled
                enabled: !TimeDate.ntpEnabled && !TimeDate.operationPending
                onClicked: dateTimeRoot.timePickerOpen = true

                MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
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

            DatePicker {
                visible: !TimeDate.ntpEnabled && dateTimeRoot.datePickerOpen
                enabled: !TimeDate.operationPending
                selectedDate: dateTimeRoot.editingDate
                onAccepted: value => {
                    dateTimeRoot.editingDate = value;
                    dateTimeRoot.editYear = value.getFullYear();
                    dateTimeRoot.editMonth = value.getMonth() + 1;
                    dateTimeRoot.editDay = value.getDate();
                    dateTimeRoot.submitEditingDate();
                    dateTimeRoot.datePickerOpen = false;
                    Qt.callLater(() => dateRow.forceActiveFocus());
                }
                onCanceled: {
                    dateTimeRoot.datePickerOpen = false;
                    Qt.callLater(() => dateRow.forceActiveFocus());
                }
            }

            TimePicker {
                visible: !TimeDate.ntpEnabled && dateTimeRoot.timePickerOpen
                enabled: !TimeDate.operationPending
                hour: dateTimeRoot.editHour
                minute: dateTimeRoot.editMinute
                format24Hour: Config.options.time.format === "hh:mm"
                onAccepted: (hour, minute) => {
                    dateTimeRoot.editHour = hour;
                    dateTimeRoot.editMinute = minute;
                    dateTimeRoot.submitEditingDate();
                    dateTimeRoot.timePickerOpen = false;
                    Qt.callLater(() => timeRow.forceActiveFocus());
                }
                onCanceled: {
                    dateTimeRoot.timePickerOpen = false;
                    Qt.callLater(() => timeRow.forceActiveFocus());
                }
            }

            TimezonePicker {
                visible: dateTimeRoot.timezonePickerOpen
                timezones: TimeDate.availableTimezones
                currentTimezone: TimeDate.timezone
                onSelected: value => {
                    TimeDate.setTimezone(value);
                    dateTimeRoot.timezonePickerOpen = false;
                    Qt.callLater(() => timezoneRow.forceActiveFocus());
                }
                onCanceled: {
                    dateTimeRoot.timezonePickerOpen = false;
                    Qt.callLater(() => timezoneRow.forceActiveFocus());
                }
            }

            SettingsGroup {
                visible: !dateTimeRoot.timezonePickerOpen
                title: Translation.tr("Time zone")

                SettingsRow {
                    id: timezoneRow
                    icon: "public"
                    title: Translation.tr("Time zone")
                    description: (TimeDate.timezone || Translation.tr("Unavailable")) + "\n" + dateTimeRoot.timezoneOffsetLabel()
                    clickable: true
                    enabled: TimeDate.ready && !TimeDate.operationPending
                    onClicked: dateTimeRoot.timezonePickerOpen = true

                    RowLayout {
                        spacing: 8
                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnSurfaceVariant
                        }
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
        id: appearancePage
        AppearanceConfig {}
    }

    Component {
        id: colorsPage
        ColorsConfig {}
    }

    Component {
        id: fontsPage
        FontsConfig {}
    }

    Component {
        id: lockScreenPage
        LockScreenConfig {}
    }

    Component {
        id: screenLockSecurityPage
        ScreenLockSecurityConfig {}
    }

    Component {
        id: effectsAnimationsPage
        EffectsAnimationsConfig {}
    }

    Component {
        id: searchPage
        SearchConfig {}
    }

    Component {
        id: clipboardPage
        ClipboardConfig {}
    }

    Component {
        id: screenshotsPage
        ScreenshotsConfig {}
    }

    Component {
        id: screenRecordingPage
        ScreenRecordingConfig {}
    }

    Component {
        id: systemUpdatesPage
        SystemUpdatesConfig {}
    }

    Component {
        id: diagnosticsPage
        DiagnosticsConfig {}
    }

    Component {
        id: aboutPage
        AboutConfig {}
    }
}
