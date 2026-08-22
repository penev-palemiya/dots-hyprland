pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/** Shared NetworkManager-backed model for Quick Settings and Settings. */
Singleton {
    id: root

    readonly property string service: "org.freedesktop.NetworkManager"
    readonly property string rootPath: "/org/freedesktop/NetworkManager"
    readonly property string managerInterface: "org.freedesktop.NetworkManager"
    readonly property string objectManagerInterface: "org.freedesktop.DBus.ObjectManager"
    readonly property string deviceInterface: "org.freedesktop.NetworkManager.Device"
    readonly property string wirelessInterface: "org.freedesktop.NetworkManager.Device.Wireless"
    readonly property string accessPointInterface: "org.freedesktop.NetworkManager.AccessPoint"
    readonly property string activeInterface: "org.freedesktop.NetworkManager.Connection.Active"
    readonly property string settingsInterface: "org.freedesktop.NetworkManager.Settings"
    readonly property string settingsConnectionInterface: "org.freedesktop.NetworkManager.Settings.Connection"
    readonly property string hotspotMarker: "ii-hotspot-v1"
    readonly property string hotspotProfileName: "ii Hotspot"

    property bool wifi: true
    property bool ethernet: false
    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: actionProc.running
    property WifiAccessPoint wifiConnectTarget
    readonly property list<WifiAccessPoint> wifiNetworks: []
    property list<var> wifiDevices: []
    property list<var> savedWifiProfilesList: []
    property list<var> ethernetDevices: []
    property list<var> ethernetProfilesList: []
    property list<var> vpnProfiles: []
    property list<var> activeVpnConnections: []
    property list<var> hotspotDevices: []
    property var hotspotProfile: null
    property string hotspotProfileUuid: ""
    property bool hotspotActive: false
    property bool hotspotStarting: false
    property bool hotspotStopping: false
    property string hotspotStatus: "off"
    property string hotspotError: ""
    property string hotspotSsid: ""
    property string hotspotBand: ""
    property string hotspotInterface: ""
    property bool hotspotHasUpstream: false
    property bool hotspotMayInterruptWifi: false
    property bool hotspotCapabilitiesReady: false
    property bool hotspotHas24Ghz: false
    property bool hotspotHas5Ghz: false
    property bool hotspotHas6Ghz: false
    property var savedWifiProfiles: ({})
    property var currentDetails: ({ ssid: "", band: "", signal: 0, ipv4: "", ipv6: "", gateway: "", dns: "", activePath: "" })
    property string activeWifiName: ""
    property string activeProfileUuid: ""
    property string activeProfilePath: ""
    property string wifiStatus: "disconnected"
    property string networkName: ""
    property int networkStrength: 0
    property bool secretsRequired: false
    property bool ready: false
    property string error: ""
    property real lastScanTime: 0
    readonly property real scanCooldownMs: 10000

    readonly property WifiAccessPoint active: {
        if (root.activeWifiName.length > 0)
            return root.wifiNetworks.find(network => network.ssid === root.activeWifiName) ?? null;
        return root.wifiNetworks.find(network => network.active) ?? null;
    }
    readonly property list<var> friendlyWifiNetworks: [...root.wifiNetworks].sort((a, b) => {
        if (a.active && !b.active) return -1;
        if (!a.active && b.active) return 1;
        return b.strength - a.strength;
    })
    readonly property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (root.networkStrength > 83 ? "signal_wifi_4_bar" : root.networkStrength > 67 ? "network_wifi" : root.networkStrength > 50 ? "network_wifi_3_bar" : root.networkStrength > 33 ? "network_wifi_2_bar" : root.networkStrength > 17 ? "network_wifi_1_bar" : "signal_wifi_0_bar")
            : root.wifiStatus === "connecting" ? "signal_wifi_statusbar_not_connected"
            : root.wifiStatus === "disconnected" ? "wifi_find"
            : root.wifiStatus === "disabled" ? "signal_wifi_off" : "signal_wifi_bad"

    signal operationFailed(string reason)

    function value(object, key, fallback) {
        const item = object?.[key];
        return item && Object.prototype.hasOwnProperty.call(item, "data") ? item.data : (item ?? fallback);
    }

    function unwrap(parsed) {
        const raw = parsed?.data ?? parsed;
        return Array.isArray(raw) && raw.length === 1 ? raw[0] : raw;
    }

    function bytes(value) {
        if (Array.isArray(value)) {
            const encoded = value.filter(byte => byte !== 0).map(byte => `%${Number(byte).toString(16).padStart(2, "0")}`).join("");
            try { return decodeURIComponent(encoded); } catch (exception) { return String.fromCharCode(...value.filter(byte => byte !== 0)); }
        }
        return String(value ?? "");
    }

    function band(frequency) {
        if (frequency >= 5925) return "6 GHz";
        if (frequency >= 4900) return "5 GHz";
        if (frequency >= 2400) return "2.4 GHz";
        return "";
    }

    function securityLabel(flags, wpaFlags, rsnFlags) {
        if (!(Number(flags) & 1) && !Number(wpaFlags) && !Number(rsnFlags)) return "Open";
        if (Number(rsnFlags) && Number(wpaFlags)) return "WPA/WPA2 Personal";
        if (Number(rsnFlags)) return "WPA3 Personal";
        if (Number(wpaFlags)) return "WPA Personal";
        return "Secured";
    }

    function ethernetState(state, carrier) {
        state = Number(state);
        if (state >= 100 && state < 110) return "Connected";
        if (state >= 40 && state < 100) return "Connecting";
        if (state === 20) return carrier ? "Unavailable" : "Cable unplugged";
        if (state === 30) return carrier ? "Disconnected" : "Cable unplugged";
        if (state >= 110) return "Unavailable";
        return carrier ? "Disconnected" : "Cable unplugged";
    }

    function speedText(speedMbps) {
        const speed = Number(speedMbps || 0);
        if (speed <= 0) return "";
        if (speed >= 1000) return `${speed % 1000 === 0 ? speed / 1000 : (speed / 1000).toFixed(1)} Gbps`;
        return `${speed} Mbps`;
    }

    function utf8Length(value) {
        try { return encodeURIComponent(String(value)).replace(/%[0-9A-F]{2}|./g, "x").length; }
        catch (exception) { return String(value).length; }
    }

    function validHotspotSsid(ssid) {
        return String(ssid || "").length > 0 && utf8Length(ssid) <= 32;
    }

    function validHotspotPassword(password) {
        const value = String(password || "");
        return /^[\x20-\x7e]{8,63}$/.test(value) || /^[0-9a-fA-F]{64}$/.test(value);
    }

    readonly property bool hotspotSupported: root.hotspotDevices.length > 0;
    readonly property list<var> hotspotBands: [
        { label: "Automatic", value: "" },
        ...(root.hotspotHas24Ghz ? [{ label: "2.4 GHz", value: "bg" }] : []),
        ...(root.hotspotHas5Ghz ? [{ label: "5 GHz", value: "a" }] : [])
    ];

    function updateHotspotState() {
        const profile = root.hotspotProfile;
        const device = root.hotspotDevices[0] || null;
        root.hotspotInterface = device?.interfaceName || "";
        root.hotspotSsid = profile?.ssid || "";
        root.hotspotBand = profile?.band || "";
        root.hotspotActive = Boolean(profile && root.activeProfilePath === profile.path);
        root.hotspotStatus = root.hotspotStarting ? "starting" : root.hotspotStopping ? "stopping" : root.hotspotActive ? "on" : root.hotspotError.length > 0 ? "failed" : "off";
        // A Wi-Fi client connection on the same radio is not a reliable
        // upstream once AP mode is activated. Only a separate wired uplink
        // is advertised as available in v1.
        root.hotspotHasUpstream = Boolean(root.ethernetDevices.some(item => item.connected));
        root.hotspotMayInterruptWifi = Boolean(root.wifiStatus === "connected" && !root.hotspotActive && device && root.activeProfilePath !== profile?.path);
    }

    function startHotspot(ssid, password, band = "", confirmed = false) {
        const device = root.hotspotDevices[0];
        if (!device || root.hotspotStarting || root.hotspotStopping) return false;
        if (!root.validHotspotSsid(ssid)) { root.hotspotError = "Enter a network name up to 32 bytes."; return false; }
        if (!root.validHotspotPassword(password) && !root.hotspotProfile) { root.hotspotError = "Use 8–63 printable characters for the password."; return false; }
        if (root.hotspotMayInterruptWifi && !confirmed) return "confirm";
        root.hotspotError = "";
        root.hotspotStarting = true;
        root.hotspotStatus = "starting";
        hotspotActionProc.environment = ({ LANG: "C", LC_ALL: "C", HOTSPOT_IFACE: device.interfaceName, HOTSPOT_NAME: root.hotspotProfileName, HOTSPOT_SSID: String(ssid), HOTSPOT_BAND: String(band || ""), HOTSPOT_PASSWORD: String(password || "") });
        const script = [
            "set -e",
            "find_hotspot() {",
            "  while IFS=: read -r id type; do",
            "    [ \"$type\" = 802-11-wireless ] || continue",
            "    mode=$(nmcli -g 802-11-wireless.mode connection show uuid \"$id\")",
            "    marker=$(nmcli -g connection.stable-id connection show uuid \"$id\")",
            "    if [ \"$mode\" = ap ] && [ \"$marker\" = ii-hotspot-v1 ]; then echo \"$id\"; return 0; fi",
            "  done < <(nmcli -t -f UUID,TYPE connection show)",
            "}",
            "UUID=$(find_hotspot || true)",
            "if [ -n \"$UUID\" ]; then",
            "  nmcli connection modify uuid \"$UUID\" connection.interface-name \"$HOTSPOT_IFACE\" 802-11-wireless.ssid \"$HOTSPOT_SSID\" ipv4.method shared ipv6.method disabled connection.autoconnect no",
            "  if [ -n \"$HOTSPOT_BAND\" ]; then nmcli connection modify uuid \"$UUID\" 802-11-wireless.band \"$HOTSPOT_BAND\"; else nmcli connection modify uuid \"$UUID\" 802-11-wireless.band \"\"; fi",
            "  if [ -n \"$HOTSPOT_PASSWORD\" ]; then nmcli connection modify uuid \"$UUID\" 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk \"$HOTSPOT_PASSWORD\"; fi",
            "else",
            "  nmcli connection add type wifi ifname \"$HOTSPOT_IFACE\" con-name \"$HOTSPOT_NAME\" ssid \"$HOTSPOT_SSID\" wifi.mode ap ipv4.method shared ipv6.method disabled connection.autoconnect no",
            "  UUID=$(nmcli -t -f UUID,NAME connection show | awk -F: -v n=\"$HOTSPOT_NAME\" '$2 == n { print $1; exit }')",
            "  nmcli connection modify uuid \"$UUID\" connection.stable-id ii-hotspot-v1 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk \"$HOTSPOT_PASSWORD\"",
            "  if [ -n \"$HOTSPOT_BAND\" ]; then nmcli connection modify uuid \"$UUID\" 802-11-wireless.band \"$HOTSPOT_BAND\"; fi",
            "fi",
            "nmcli connection up uuid \"$UUID\" ifname \"$HOTSPOT_IFACE\""
        ].join("\n");
        hotspotActionProc.command = ["bash", "-c", script];
        hotspotActionProc.running = true;
        return true;
    }

    function stopHotspot() {
        if (!root.hotspotActive || root.hotspotStopping) return false;
        root.hotspotError = "";
        root.hotspotStopping = true;
        root.hotspotStatus = "stopping";
        hotspotActionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        hotspotActionProc.command = ["busctl", "--system", "call", root.service, root.rootPath, root.managerInterface, "DeactivateConnection", "o", root.currentDetails.activePath];
        hotspotActionProc.running = true;
        return true;
    }

    function vpnTypeLabel(connectionType, serviceType) {
        if (connectionType === "wireguard") return "WireGuard";
        const service = String(serviceType || "").toLowerCase();
        if (service.includes("openvpn")) return "OpenVPN";
        if (service.includes("openconnect")) return "OpenConnect";
        if (service.includes("l2tp")) return "L2TP";
        if (service.includes("pptp")) return "PPTP";
        if (service.includes("strongswan") || service.includes("libreswan") || service.includes("openswan") || service.includes("ipsec")) return "IPsec";
        return "VPN";
    }

    function vpnState(vpnStateCode, activeStateCode, isClassicVpn) {
        const state = Number(isClassicVpn ? vpnStateCode : activeStateCode);
        if (isClassicVpn) {
            if (state === 2) return "Authentication required";
            if ([1, 3, 4].includes(state)) return "Connecting";
            if (state === 5) return "Connected";
            if (state === 6) return "Failed";
            return "Disconnected";
        }
        if (state === 1) return "Connecting";
        if (state === 2) return "Connected";
        if (state === 3 || state === 4) return "Disconnected";
        return state > 0 ? "Failed" : "Disconnected";
    }

    function preferredProfile(ssid) {
        const profiles = root.savedWifiProfilesList.filter(profile => profile.ssid === ssid);
        return profiles.find(profile => profile.uuid === root.activeProfileUuid) || profiles[0] || null;
    }

    function isKnownNetwork(ssid) { return root.savedWifiProfilesList.some(profile => profile.ssid === ssid); }

    function scheduleRefresh() {
        if (snapshotProc.running) {
            refreshPending = true;
            return;
        }
        refreshDebounce.restart();
    }

    function refresh() { scheduleRefresh(); }

    function requestScan(force = false) {
        const now = Date.now();
        if (!force && now - root.lastScanTime < root.scanCooldownMs) return false;
        const device = root.wifiDevices[0];
        if (!device) return false;
        root.lastScanTime = now;
        root.wifiScanning = true;
        scanProc.command = ["busctl", "--system", "call", root.service, device.path,
            root.wirelessInterface, "RequestScan", "a{sv}", "0"];
        scanProc.running = true;
        return true;
    }

    // Existing Quick Settings API name.
    function rescanWifi(force = false) { return requestScan(force); }

    function enableWifi(enabled = true) {
        setWifiProc.command = ["busctl", "--system", "set-property", root.service, root.rootPath,
            root.managerInterface, "WirelessEnabled", "b", enabled ? "true" : "false"];
        setWifiProc.running = true;
    }

    function toggleWifi() { enableWifi(!root.wifiEnabled); }

    function connectToWifiNetwork(accessPoint, password = "") {
        if (!accessPoint) return;
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        root.secretsRequired = false;
        const profile = root.preferredProfile(accessPoint.ssid);
        const device = root.wifiDevices[0];
        if (!device) return;

        if (!profile && accessPoint.isSecure && password.length === 0) {
            accessPoint.askingPassword = true;
            return;
        }

        if (password.length > 0 || (!profile && accessPoint.isSecure)) {
            // One-shot compatibility path: password is supplied via the
            // environment, never as a command-line argument or shell config.
            actionProc.environment = ({ LANG: "C", LC_ALL: "C", PASSWORD: password, SSID: accessPoint.ssid });
            actionProc.command = ["bash", "-c", "nmcli dev wifi connect \"$SSID\" password \"$PASSWORD\""];
        } else if (profile) {
            actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
            actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
                root.managerInterface, "ActivateConnection", "ooo", profile.path, device.path, accessPoint.bestAccessPoint || "/"];
        } else {
            actionProc.environment = ({ LANG: "C", LC_ALL: "C", SSID: accessPoint.ssid });
            actionProc.command = ["bash", "-c", "nmcli dev wifi connect \"$SSID\""];
        }
        actionProc.running = true;
    }

    function connectSavedProfile(profile) {
        const device = root.wifiDevices[0];
        if (!profile?.path || !device) return false;
        const network = root.wifiNetworks.find(item => item.ssid === profile.ssid);
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "ActivateConnection", "ooo", profile.path, device.path, network?.bestAccessPoint || "/"];
        actionProc.running = true;
        return true;
    }

    function disconnectWifiNetwork() {
        if (!root.currentDetails.activePath) return;
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "DeactivateConnection", "o", root.currentDetails.activePath];
        actionProc.running = true;
    }

    function connectEthernetProfile(profile, device) {
        if (!profile?.path || !device || actionProc.running) return false;
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "ActivateConnection", "ooo", profile.path, device.dbusPath, "/"];
        actionProc.running = true;
        return true;
    }

    function disconnectEthernet(device) {
        if (!device?.activeConnection || actionProc.running) return false;
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "DeactivateConnection", "o", device.activeConnection];
        actionProc.running = true;
        return true;
    }

    function connectVpnProfile(profile) {
        if (!profile?.path || actionProc.running || profile.available === false) return false;
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "ActivateConnection", "ooo", profile.path, "/", "/"];
        actionProc.running = true;
        return true;
    }

    function disconnectVpn(connection) {
        if (!connection?.activePath || actionProc.running) return false;
        actionProc.environment = ({ LANG: "C", LC_ALL: "C" });
        actionProc.command = ["busctl", "--system", "call", root.service, root.rootPath,
            root.managerInterface, "DeactivateConnection", "o", connection.activePath];
        actionProc.running = true;
        return true;
    }

    function forgetWifiProfile(profile) {
        if (!profile?.path || actionProc.running) return false;
        actionProc.command = ["busctl", "--system", "call", root.service, profile.path,
            root.settingsConnectionInterface, "Delete"];
        actionProc.running = true;
        return true;
    }

    // Compatibility for the existing grouped Quick Settings row. It still
    // resolves a concrete profile UUID deterministically before deleting.
    function forgetWifiNetwork(ssid) { return forgetWifiProfile(preferredProfile(ssid)); }
    function changePassword(network, password, username = "") { connectToWifiNetwork(network, password); }
    function openPublicWifiPortal() { Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]); }

    function parseSnapshot(parsed) {
        const objects = root.unwrap(parsed);
        if (!objects || typeof objects !== "object") return;
        const manager = objects[root.rootPath]?.[root.managerInterface] || {};
        root.wifiEnabled = Boolean(root.value(manager, "WirelessEnabled", false));
        const devices = [];
        const accessPoints = {};
        const activeConnections = {};
        const ipConfigs = {};
        const ethernetCandidates = [];
        const deviceInfo = {};
        root.hotspotHas24Ghz = false;
        root.hotspotHas5Ghz = false;
        root.hotspotHas6Ghz = false;

        for (const path of Object.keys(objects)) {
            const interfaces = objects[path] || {};
            const device = interfaces[root.deviceInterface];
            const wireless = interfaces[root.wirelessInterface];
            const ap = interfaces[root.accessPointInterface];
            const active = interfaces[root.activeInterface];
            const ip4 = interfaces["org.freedesktop.NetworkManager.IP4Config"];
            const ip6 = interfaces["org.freedesktop.NetworkManager.IP6Config"];
            if (ap) accessPoints[path] = { path, data: ap };
            if (active) activeConnections[path] = { path, data: active, vpn: interfaces["org.freedesktop.NetworkManager.VpnConnection"] || null };
            if (ip4 || ip6) ipConfigs[path] = { path, ip4, ip6 };
            if (!device) continue;
            deviceInfo[path] = {
                path,
                interfaceName: root.value(device, "Interface", ""),
                state: Number(root.value(device, "State", 0)),
                ip4Path: root.value(device, "Ip4Config", "/"),
                ip6Path: root.value(device, "Ip6Config", "/")
            };
            const type = Number(root.value(device, "DeviceType", 0));
            if (type === 2) {
                const wirelessCapabilities = Number(root.value(wireless, "WirelessCapabilities", 0));
                root.hotspotHas24Ghz = root.hotspotHas24Ghz || Boolean(wirelessCapabilities & 0x200);
                root.hotspotHas5Ghz = root.hotspotHas5Ghz || Boolean(wirelessCapabilities & 0x400);
                root.hotspotHas6Ghz = root.hotspotHas6Ghz || Boolean(wirelessCapabilities & 0x800);
                devices.push({
                    path,
                    interfaceName: root.value(device, "Interface", ""),
                    state: Number(root.value(device, "State", 0)),
                    apSupported: Boolean(wirelessCapabilities & 0x40),
                    activePath: root.value(device, "ActiveConnection", "/"),
                    accessPoints: root.value(wireless, "AccessPoints", []),
                    activeAccessPoint: root.value(wireless, "ActiveAccessPoint", "/"),
                    ip4Path: root.value(device, "Ip4Config", "/"),
                    ip6Path: root.value(device, "Ip6Config", "/")
                });
            } else if (type === 1) {
                const wired = interfaces["org.freedesktop.NetworkManager.Device.Wired"];
                const virtual = interfaces["org.freedesktop.NetworkManager.Device.Veth"] ||
                    interfaces["org.freedesktop.NetworkManager.Device.Bridge"] ||
                    interfaces["org.freedesktop.NetworkManager.Device.Bond"] ||
                    interfaces["org.freedesktop.NetworkManager.Device.Vlan"] ||
                    interfaces["org.freedesktop.NetworkManager.Device.Tun"];
                const udi = root.value(device, "Udi", "");
                if (wired && !virtual && root.value(device, "Real", false) && !udi.includes("/virtual/")) {
                    ethernetCandidates.push({
                        id: root.value(device, "Interface", ""),
                        dbusPath: path,
                        interfaceName: root.value(device, "Interface", ""),
                        stateCode: Number(root.value(device, "State", 0)),
                        carrier: Boolean(root.value(wired, "Carrier", false)),
                        speedMbps: Number(root.value(wired, "Speed", 0)),
                        hwAddress: root.value(wired, "HwAddress", root.value(device, "HwAddress", "")),
                        activeConnection: root.value(device, "ActiveConnection", "/"),
                        ip4Path: root.value(device, "Ip4Config", "/"),
                        ip6Path: root.value(device, "Ip6Config", "/")
                    });
                }
            }
        }
        root.wifiDevices = devices;
        root.hotspotDevices = devices.filter(device => device.apSupported).map(device => Object.assign({}, device, {
            apSupported: true,
            interfaceName: device.interfaceName
        }));
        root.hotspotCapabilitiesReady = true;
        root.deviceInfo = deviceInfo;
        root.activeConnectionRecords = Object.values(activeConnections);
        const ethernetDevices = ethernetCandidates.map(candidate => {
            const activeConnection = activeConnections[candidate.activeConnection];
            const details = root.detailsFor(candidate, activeConnection, ipConfigs);
            return Object.assign(candidate, details, {
                state: root.ethernetState(candidate.stateCode, candidate.carrier),
                connected: candidate.stateCode >= 100 && candidate.stateCode < 110,
                connecting: candidate.stateCode >= 40 && candidate.stateCode < 100,
                speed: root.speedText(candidate.speedMbps),
                activeProfile: activeConnection?.data ? root.value(activeConnection.data, "Id", "") : "",
                activeProfilePath: activeConnection?.data ? root.value(activeConnection.data, "Connection", "/") : "/",
                profiles: []
            });
        });
        root.ethernetDevices = ethernetDevices;
        root.ethernet = ethernetDevices.some(device => device.connected);

        const activeDevice = devices.find(device => device.state >= 100) || devices[0];
        const activeConnection = activeDevice ? activeConnections[activeDevice.activePath] : null;
        const activeId = root.value(activeConnection?.data, "Id", "");
        root.activeProfilePath = root.value(activeConnection?.data, "Connection", "/");
        root.activeWifiName = activeId;
        root.currentDetails = root.detailsFor(activeDevice, activeConnection, ipConfigs);
        root.wifiStatus = !root.wifiEnabled ? "disabled" : !activeDevice ? "disconnected" : activeDevice.state >= 100 ? "connected" : activeDevice.state >= 50 ? "connecting" : "disconnected";
        root.networkName = activeId;
        root.updateHotspotState();

        const grouped = new Map();
        for (const device of devices) {
            for (const apPath of device.accessPoints || []) {
                const entry = accessPoints[apPath];
                if (!entry) continue;
                const data = entry.data;
                const ssid = root.bytes(root.value(data, "Ssid", []));
                const hidden = ssid.length === 0;
                if (hidden) continue;
                const item = {
                    path: apPath,
                    bssid: root.value(data, "HwAddress", ""),
                    ssid,
                    hidden,
                    strength: Number(root.value(data, "Strength", 0)),
                    frequency: Number(root.value(data, "Frequency", 0)),
                    band: root.band(Number(root.value(data, "Frequency", 0))),
                    security: root.securityLabel(root.value(data, "Flags", 0), root.value(data, "WpaFlags", 0), root.value(data, "RsnFlags", 0)),
                    active: apPath === device.activeAccessPoint,
                    devicePath: device.path
                };
                let network = grouped.get(ssid);
                if (!network) {
                    network = { ssid, hidden, accessPoints: [], best: null, active: false };
                    grouped.set(ssid, network);
                }
                network.accessPoints.push(item);
                network.active = network.active || item.active || ssid === activeId;
                if (!network.best || (item.active && !network.best.active) || (!network.best.active && item.strength > network.best.strength)) network.best = item;
            }
        }

        for (const network of grouped.values()) {
            const existing = root.wifiNetworks.find(item => item.ssid === network.ssid);
            const best = network.best || network.accessPoints[0];
            const normalized = {
                ssid: network.ssid,
                hidden: network.hidden,
                bssid: best.bssid,
                strength: best.strength,
                frequency: best.frequency,
                band: best.band,
                security: best.security,
                isSecure: best.security !== "Open",
                active: network.active,
                connected: network.active,
                bestAccessPoint: best.path,
                accessPoints: network.accessPoints,
                savedProfiles: root.savedWifiProfilesList.filter(profile => profile.ssid === network.ssid)
            };
            if (existing) existing.lastIpcObject = normalized;
            else root.wifiNetworks.push(apComp.createObject(root, { lastIpcObject: normalized }));
        }
        for (const existing of [...root.wifiNetworks]) {
            if (!grouped.has(existing.ssid)) { root.wifiNetworks.splice(root.wifiNetworks.indexOf(existing), 1); existing.destroy(); }
        }
        root.wifiNetworksChanged();
        root.networkStrength = root.active?.strength ?? 0;
        root.ready = true;
        root.wifiScanning = false;
        root.beginProfiles(objects);
    }

    function detailsFor(device, activeConnection, ipConfigs) {
        const ap = activeConnection?.data ? root.value(activeConnection.data, "SpecificObject", "/") : "/";
        const apData = ap && ap !== "/" ? currentAccessPointData(ap) : null;
        const ip4 = ipConfigs[device?.ip4Path]?.ip4 || {};
        const ip6 = ipConfigs[device?.ip6Path]?.ip6 || {};
        const addresses = root.value(ip4, "AddressData", []);
        const address = addresses[0]?.address?.data || addresses[0]?.address || "";
        const v6 = root.value(ip6, "AddressData", []).map(entry => entry.address?.data || entry.address || "").filter(value => value && !value.startsWith("fe80:") );
        const dns4 = root.value(ip4, "NameserverData", []).map(entry => entry.address?.data || entry.address || "").filter(Boolean);
        const dns6 = root.value(ip6, "NameserverData", []).map(entry => entry.address?.data || entry.address || "").filter(value => value && !value.startsWith("fe80:"));
        return {
            activePath: activeConnection?.path || "",
            ssid: root.value(activeConnection?.data, "Id", ""),
            signal: Number(root.value(apData, "Strength", 0)),
            frequency: Number(root.value(apData, "Frequency", 0)),
            band: root.band(Number(root.value(apData, "Frequency", 0))),
            ipv4: address,
            ipv6: v6.join(", "),
            gateway4: root.value(ip4, "Gateway", ""),
            gateway6: root.value(ip6, "Gateway", ""),
            gateway: root.value(ip4, "Gateway", "") || root.value(ip6, "Gateway", ""),
            dns4: dns4.join(", "),
            dns6: dns6.join(", "),
            dns: dns4.concat(dns6).join(", ")
        };
    }

    function currentAccessPointData(path) { return snapshotObjects[path]?.[root.accessPointInterface] || {}; }

    function vpnDetails(activeData) {
        const ip4Path = root.value(activeData, "Ip4Config", "/");
        const ip6Path = root.value(activeData, "Ip6Config", "/");
        const ip4 = root.snapshotObjects[ip4Path]?.["org.freedesktop.NetworkManager.IP4Config"] || {};
        const ip6 = root.snapshotObjects[ip6Path]?.["org.freedesktop.NetworkManager.IP6Config"] || {};
        const addresses4 = root.value(ip4, "AddressData", []).map(entry => entry.address?.data || entry.address || "").filter(Boolean);
        const addresses6 = root.value(ip6, "AddressData", []).map(entry => entry.address?.data || entry.address || "").filter(value => value && !value.startsWith("fe80:"));
        const dns4 = root.value(ip4, "NameserverData", []).map(entry => entry.address?.data || entry.address || "").filter(Boolean);
        const dns6 = root.value(ip6, "NameserverData", []).map(entry => entry.address?.data || entry.address || "").filter(value => value && !value.startsWith("fe80:"));
        return {
            ipv4: addresses4,
            ipv6: addresses6,
            gateway4: root.value(ip4, "Gateway", ""),
            gateway6: root.value(ip6, "Gateway", ""),
            dns4,
            dns6
        };
    }

    function rebuildVpnState(profiles) {
        const vpnProfiles = profiles.filter(profile => profile.kind === "vpn");
        const active = [];
        for (const record of root.activeConnectionRecords) {
            const activeData = record.data;
            const profilePath = root.value(activeData, "Connection", "/");
            const profile = vpnProfiles.find(item => item.path === profilePath);
            if (!profile) continue;
            const isClassicVpn = Boolean(record.vpn);
            const vpnData = record.vpn || {};
            const devices = root.value(activeData, "Devices", []);
            const firstDevice = devices.length > 0 ? root.deviceInfo[devices[0]] : null;
            const details = root.vpnDetails(activeData);
            active.push(Object.assign({}, details, {
                id: profile.id,
                uuid: profile.uuid,
                profile: profile.id,
                profilePath,
                activePath: record.path,
                type: profile.displayType,
                connectionType: profile.connectionType,
                state: root.vpnState(root.value(vpnData, "VpnState", 0), root.value(activeData, "State", 0), isClassicVpn),
                interfaceName: firstDevice?.interfaceName || root.value(activeData, "VpnTunnel", "")
            }));
        }
        root.vpnProfiles = vpnProfiles.map(profile => Object.assign({}, profile, {
            dbusPath: profile.path,
            active: active.some(connection => connection.profilePath === profile.path)
        }));
        root.activeVpnConnections = active;
    }

    property var snapshotObjects: ({})
    property var deviceInfo: ({})
    property var activeConnectionRecords: []

    function beginProfiles(objects) {
        root.snapshotObjects = objects;
        const settings = objects[`${root.rootPath}/Settings`]?.[root.settingsInterface] || {};
        profilePaths = root.value(settings, "Connections", []);
        profileRecords = [];
        profileIndex = 0;
        readNextProfile();
    }

    function readNextProfile() {
        if (profileIndex >= profilePaths.length) {
            const profiles = profileRecords.filter(profile => profile.ssid || profile.kind === "ethernet");
            const allWifiProfiles = profiles.filter(profile => profile.kind === "wifi");
            const managedHotspots = allWifiProfiles.filter(profile => profile.mode === "ap" && profile.stableId === root.hotspotMarker);
            const wifiProfiles = allWifiProfiles.filter(profile => profile.mode !== "ap");
            const ethernetProfiles = profiles.filter(profile => profile.kind === "ethernet");
            root.savedWifiProfilesList = wifiProfiles;
            root.hotspotProfile = managedHotspots[0] || null;
            root.hotspotProfileUuid = root.hotspotProfile?.uuid || "";
            root.updateHotspotState();
            root.ethernetProfilesList = ethernetProfiles;
            const bySsid = {};
            wifiProfiles.forEach(profile => { if (!bySsid[profile.ssid]) bySsid[profile.ssid] = profile; });
            root.savedWifiProfiles = bySsid;
            root.activeProfileUuid = wifiProfiles.find(profile => profile.path === root.activeProfilePath)?.uuid || "";
            root.wifiNetworks.forEach(network => network.lastIpcObject = Object.assign({}, network.lastIpcObject, { savedProfiles: wifiProfiles.filter(profile => profile.ssid === network.ssid) }));
            root.ethernetDevices = root.ethernetDevices.map(device => Object.assign({}, device, {
                profiles: ethernetProfiles.filter(profile => !profile.interfaceName || profile.interfaceName === device.interfaceName).map(profile => Object.assign({}, profile, { active: profile.path === device.activeProfilePath })),
                activeProfile: ethernetProfiles.find(profile => profile.path === device.activeProfilePath)?.id || device.activeProfile
            }));
            root.ethernetProfilesList = ethernetProfiles.map(profile => Object.assign({}, profile, {
                dbusPath: profile.path,
                active: root.ethernetDevices.some(device => device.activeProfilePath === profile.path)
            }));
            root.rebuildVpnState(profiles);
            root.wifiNetworksChanged();
            return;
        }
        profileProc.command = ["busctl", "--system", "--json=short", "call", root.service, profilePaths[profileIndex], root.settingsConnectionInterface, "GetSettings"];
        profileProc.running = true;
    }

    property var profilePaths: []
    property var profileRecords: []
    property int profileIndex: 0
    property bool refreshPending: false

    function parseProfile(parsed, path) {
        const settings = root.unwrap(parsed) || {};
        const connection = settings.connection || {};
        const wireless = settings["802-11-wireless"] || {};
        const security = settings["802-11-wireless-security"] || {};
        const vpn = settings.vpn || {};
        const get = (section, key, fallback) => root.value(section, key, fallback);
        const type = get(connection, "type", "");
        if (type === "802-11-wireless") {
                profileRecords.push({
                    path, dbusPath: path, kind: "wifi", id: get(connection, "id", ""), uuid: get(connection, "uuid", ""),
                    ssid: root.bytes(get(wireless, "ssid", [])), mode: get(wireless, "mode", "infrastructure"),
                    band: get(wireless, "band", ""), keyManagement: get(security, "key-mgmt", ""),
                    ipv4Method: get(settings.ipv4 || {}, "method", ""), stableId: get(connection, "stable-id", ""),
                    autoconnect: Boolean(get(connection, "autoconnect", true)), interfaceName: get(connection, "interface-name", "")
                });
        } else if (type === "802-3-ethernet") {
            // A profile enslaved to a bridge/bond is not a standalone user-facing
            // Ethernet connection. Keep generic and directly-bound wired profiles.
            const master = get(connection, "master", "");
            const slaveType = get(connection, "slave-type", "");
            if (!master && !slaveType)
                profileRecords.push({ path, dbusPath: path, kind: "ethernet", id: get(connection, "id", ""), uuid: get(connection, "uuid", ""), ssid: get(connection, "id", ""), interfaceName: get(connection, "interface-name", "") });
        } else if (type === "vpn" || type === "wireguard") {
            const serviceType = type === "vpn" ? get(vpn, "service-type", "") : "wireguard";
            profileRecords.push({
                path,
                dbusPath: path,
                kind: "vpn",
                id: get(connection, "id", ""),
                uuid: get(connection, "uuid", ""),
                ssid: get(connection, "id", ""),
                connectionType: type,
                serviceType,
                vpnType: type === "wireguard" ? "wireguard" : serviceType,
                displayType: root.vpnTypeLabel(type, serviceType),
                interfaceName: get(connection, "interface-name", ""),
                available: true,
                unavailableReason: ""
            });
        }
    }

    Process {
        id: snapshotProc
        command: ["busctl", "--system", "--json=short", "call", root.service, "/org/freedesktop", root.objectManagerInterface, "GetManagedObjects"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.snapshotObjects = root.unwrap(parsed);
                    root.parseSnapshot(parsed);
                } catch (exception) { root.error = "Could not read NetworkManager state."; }
            }
        }
        onExited: code => {
            if (code !== 0) root.error = "NetworkManager is unavailable.";
            if (root.refreshPending) { root.refreshPending = false; root.scheduleRefresh(); }
        }
    }

    Process {
        id: profileProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.parseProfile(JSON.parse(text), root.profilePaths[root.profileIndex]); } catch (exception) {}
            }
        }
        onExited: { root.profileIndex++; root.readNextProfile(); }
    }

    Process { id: scanProc; onExited: { root.wifiScanning = false; root.scheduleRefresh(); } }
    Process { id: setWifiProc; onExited: root.scheduleRefresh() }
    Process {
        id: hotspotActionProc
        property string actionError: ""
        stderr: StdioCollector { onStreamFinished: hotspotActionProc.actionError = text }
        onRunningChanged: if (running) actionError = ""
        onExited: code => {
            root.hotspotStarting = false;
            root.hotspotStopping = false;
            hotspotActionProc.environment = ({ LANG: "C", LC_ALL: "C" });
            if (code !== 0) {
                const errorText = actionError.trim();
                root.hotspotError = errorText.includes("Secrets") ? "A valid hotspot password is required." : errorText.includes("not authorized") ? "Network authorization was denied." : "Hotspot operation failed.";
                root.hotspotStatus = "failed";
            }
            root.scheduleRefresh();
        }
    }
    Process {
        id: actionProc
        property string actionError: ""
        stderr: StdioCollector { onStreamFinished: actionProc.actionError = text }
        onRunningChanged: if (running) actionError = ""
        onExited: code => {
            const target = root.wifiConnectTarget;
            root.wifiConnectTarget = null;
            if (code !== 0 && target && actionError.includes("Secrets")) {
                root.secretsRequired = true;
                target.askingPassword = true;
            }
            if (code !== 0) root.error = actionError.trim() || "Wi-Fi operation failed.";
            root.scheduleRefresh();
        }
    }

    Timer { id: refreshDebounce; interval: 250; repeat: false; onTriggered: snapshotProc.running = true }

    Process {
        id: signalMonitor
        command: ["gdbus", "monitor", "--system", "--dest", root.service]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PropertiesChanged") || line.includes("InterfacesAdded") || line.includes("InterfacesRemoved") || line.includes("AccessPointAdded") || line.includes("AccessPointRemoved")) root.scheduleRefresh();
            }
        }
        stderr: SplitParser { onRead: line => {} }
        running: true
    }

    Component { id: apComp; WifiAccessPoint {} }
    Component.onCompleted: root.scheduleRefresh()
}
