pragma Singleton
pragma ComponentBehavior: Bound

// Took many bits from https://github.com/caelestia-dots/shell (GPLv3)

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services.network

/**
 * Network service with nmcli.
 */
Singleton {
    id: root

    property bool wifi: true
    property bool ethernet: false

    property bool wifiEnabled: false
    property bool wifiScanning: false
    property bool wifiConnecting: connectProc.running
    property WifiAccessPoint wifiConnectTarget
    readonly property list<WifiAccessPoint> wifiNetworks: []

    // Connection name NetworkManager reports on the wifi device itself. Unlike
    // the `ACTIVE` column of a scan result this is never stale, so it is what
    // decides which access point counts as connected.
    property string activeWifiName: ""
    // ssid -> name of a saved connection profile for it.
    property var savedWifiProfiles: ({})
    // Set from connect stderr; only a real secrets complaint should make the UI
    // ask for a password.
    property bool secretsRequired: false

    // A cached scan list is served instantly, a real scan takes seconds. Every
    // refresh reads the cache; the scan itself is rate-limited so that reopening
    // the dialog or a burst of nmcli monitor events can't queue up scans.
    property real lastScanTime: 0
    readonly property real scanCooldownMs: 10000

    // The cached scan list keeps its `ACTIVE` flag until the next scan lands, so
    // after walking to another repeater it can still mark the *previous* SSID as
    // connected — which is how the bar preview and the Wi-Fi dialog ended up
    // disagreeing about what we're on. Trust the device, fall back to the flag
    // only while we don't know the connection name.
    readonly property WifiAccessPoint active: {
        if (root.activeWifiName.length > 0)
            return root.wifiNetworks.find(n => n.ssid === root.activeWifiName) ?? null;
        return root.wifiNetworks.find(n => n.active) ?? null;
    }
    readonly property list<var> friendlyWifiNetworks: [...wifiNetworks].sort((a, b) => {
        if (a.active && !b.active)
            return -1;
        if (!a.active && b.active)
            return 1;
        return b.strength - a.strength;
    })
    property string wifiStatus: "disconnected"

    property string networkName: ""
    property int networkStrength
    property string materialSymbol: root.ethernet
        ? "lan"
        : (root.wifiEnabled && root.wifiStatus === "connected")
            ? (
                (root.active?.strength ?? 0) > 83 ? "signal_wifi_4_bar" :
                (root.active?.strength ?? 0) > 67 ? "network_wifi" :
                (root.active?.strength ?? 0) > 50 ? "network_wifi_3_bar" :
                (root.active?.strength ?? 0) > 33 ? "network_wifi_2_bar" :
                (root.active?.strength ?? 0) > 17 ? "network_wifi_1_bar" :
                "signal_wifi_0_bar"
            )
            : (root.wifiStatus === "connecting")
                ? "signal_wifi_statusbar_not_connected"
                : (root.wifiStatus === "disconnected")
                    ? "wifi_find"
                    : (root.wifiStatus === "disabled")
                        ? "signal_wifi_off"
                        : "signal_wifi_bad"

    // Control
    function enableWifi(enabled = true): void {
        const cmd = enabled ? "on" : "off";
        enableWifiProc.exec(["nmcli", "radio", "wifi", cmd]);
    }

    function toggleWifi(): void {
        enableWifi(!wifiEnabled);
    }

    // Re-read NetworkManager's cached scan list. Cheap (single-digit ms) and
    // never blocks, so it is safe to call on every event that could have changed
    // something.
    function refreshNetworks(): void {
        if (!getNetworks.running)
            getNetworks.running = true;
    }

    function rescanWifi(force = false): void {
        // Show what NetworkManager already knows immediately instead of making
        // the list wait out a scan — that wait was the whole reason the dialog
        // took seconds to catch up after moving between repeaters.
        root.refreshNetworks();
        const now = Date.now();
        if (!force && now - root.lastScanTime < root.scanCooldownMs)
            return;
        root.lastScanTime = now;
        wifiScanning = true;
        rescanProcess.running = true;
    }

    function isKnownNetwork(ssid: string): bool {
        return !!root.savedWifiProfiles[ssid];
    }

    function connectToWifiNetwork(accessPoint: WifiAccessPoint, password = ""): void {
        accessPoint.askingPassword = false;
        root.wifiConnectTarget = accessPoint;
        root.secretsRequired = false;

        const profile = root.savedWifiProfiles[accessPoint.ssid];
        if (password.length > 0) {
            // Creates the profile if missing, updates the stored secret if not.
            connectProc.exec({
                "environment": {
                    LANG: "C",
                    LC_ALL: "C",
                    PASSWORD: password,
                    SSID: accessPoint.ssid
                },
                "command": ["bash", "-c", 'nmcli dev wifi connect "$SSID" password "$PASSWORD"']
            });
        } else if (profile) {
            // Bring the saved profile up by name so NetworkManager uses the
            // secret it already has. `nmcli dev wifi connect` picks a profile by
            // itself, and with several profiles for one SSID (a "Foo" and a
            // "Foo 1" left over from earlier connects) it can land on the one
            // without a stored password — which is why joining a known network
            // sometimes asked for a password it didn't need.
            connectProc.exec(["nmcli", "connection", "up", "id", profile]);
        } else {
            connectProc.exec(["nmcli", "dev", "wifi", "connect", accessPoint.ssid]);
        }
    }

    function disconnectWifiNetwork(): void {
        // The profile name isn't always the SSID, so take down the connection the
        // device actually reports.
        const target = root.activeWifiName.length > 0 ? root.activeWifiName : root.active?.ssid;
        if (target) disconnectProc.exec(["nmcli", "connection", "down", "id", target]);
    }

    // Delete every saved profile for this SSID, not just the one we'd connect
    // with: duplicates ("Foo", "Foo 1") are exactly what makes "forget" feel
    // broken otherwise — the network reconnects from the leftover profile and
    // looks like it was never forgotten. Deleting the active one disconnects,
    // which is what forgetting the current network means.
    function forgetWifiNetwork(ssid: string): void {
        if (!ssid)
            return;
        forgetProc.exec({
            "environment": {
                LANG: "C",
                LC_ALL: "C",
                SSID: ssid
            },
            "command": ["bash", "-c", 'nmcli -t -g UUID,TYPE connection show | while IFS=: read -r uuid type; do [ "$type" = "802-11-wireless" ] || continue; if [ "$(nmcli -g 802-11-wireless.ssid connection show "$uuid")" = "$SSID" ]; then nmcli connection delete "$uuid"; fi; done']
        });
    }

    function openPublicWifiPortal() {
        Quickshell.execDetached(["xdg-open", "https://nmcheck.gnome.org/"]) // From some StackExchange thread, seems to work
    }

    function changePassword(network: WifiAccessPoint, password: string, username = ""): void {
        // TODO: enterprise wifi with username
        network.askingPassword = false;
        // An empty field means "just connect" — for a known network that is a
        // valid answer, and the saved secret is used.
        root.connectToWifiNetwork(network, password);
    }

    Process {
        id: enableWifiProc
    }

    Process {
        id: connectProc
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: SplitParser {
            onRead: line => {
                // print(line)
                getNetworks.running = true
            }
        }
        stderr: SplitParser {
            onRead: line => {
                // print("err:", line)
                if (line.includes("Secrets were required") || line.includes("secrets were required") || line.includes("Passwords or encryption keys")) {
                    root.secretsRequired = true;
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            const target = root.wifiConnectTarget;
            root.wifiConnectTarget = null;
            getSavedConnections.running = true;
            root.refreshNetworks();
            if (!target)
                return;
            // Only prompt when NetworkManager actually asked for a secret. Any
            // non-zero exit used to open the password field, so a timeout or a
            // transient activation failure on a known network looked like a
            // forgotten password.
            target.askingPassword = (exitCode !== 0) && root.secretsRequired;
        }
    }

    Process {
        id: disconnectProc
        onExited: root.refreshNetworks()
    }

    Process {
        id: forgetProc
        onExited: {
            getSavedConnections.running = true;
            root.update();
            root.refreshNetworks();
        }
    }

    Process {
        id: rescanProcess
        // Asks NetworkManager to start scanning and returns straight away; the
        // blocking `list --rescan yes` form is what made the dialog sit still.
        // Results are picked up by scanPollTimer as they arrive.
        command: ["nmcli", "dev", "wifi", "rescan"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        onExited: (exitCode, exitStatus) => {
            // A refused rescan ("not allowed immediately following previous
            // scan") is not worth surfacing — the cached list is already on
            // screen and NetworkManager scans periodically anyway. Poll either
            // way so the spinner always resolves; the old code cleared the flag
            // from stdout only, so an error left it spinning forever.
            scanPollTimer.ticks = 0;
            scanPollTimer.restart();
        }
    }

    Timer {
        id: scanPollTimer

        property int ticks: 0

        // A NetworkManager scan takes ~7 s to land here, so keep reading the
        // cache for a little longer than that; results appear as they come in
        // rather than all at once at the end.
        interval: 1000
        repeat: true
        onTriggered: {
            root.refreshNetworks();
            if (++ticks >= 10) {
                stop();
                root.wifiScanning = false;
            }
        }
    }

    // nmcli monitor is chatty during a scan or a roam; coalesce it.
    Timer {
        id: networksDebounce

        interval: 400
        onTriggered: root.refreshNetworks()
    }

    Process {
        id: getSavedConnections
        running: true
        // A profile's name is not necessarily its SSID (a second profile for the
        // same network gets called "Foo 1"), so ask for the SSID explicitly and
        // key the map on that. ~120 ms for a dozen profiles, and this only runs
        // at startup and after a connect.
        command: ["bash", "-c", 'nmcli -t -g UUID,TYPE connection show | while IFS=: read -r uuid type; do [ "$type" = "802-11-wireless" ] || continue; nmcli -g 802-11-wireless.ssid,connection.id connection show "$uuid" | paste -sd"\t"; done']
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const profiles = {};
                for (const line of text.trim().split("\n")) {
                    const [ssid, name] = line.split("\t");
                    if (!ssid || !name)
                        continue;
                    // Prefer the profile named exactly after the network — that's
                    // the original; the "Foo 1" duplicates came later.
                    if (!profiles[ssid] || name === ssid)
                        profiles[ssid] = name;
                }
                root.savedWifiProfiles = profiles;
            }
        }
    }

    // Status update
    function update() {
        updateConnectionType.startCheck();
        wifiStatusProcess.running = true
        updateNetworkStrength.running = true;
    }

    Process {
        id: subscriber
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: {
                root.update();
                // Keep the access point list live too, so strength and the
                // connected row follow a roam without waiting for a rescan.
                networksDebounce.restart();
            }
        }
    }

    Process {
        id: updateConnectionType
        property string buffer
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION d status && nmcli -t -f CONNECTIVITY g"]
        running: true
        function startCheck() {
            buffer = "";
            updateConnectionType.running = true;
        }
        stdout: SplitParser {
            onRead: data => {
                updateConnectionType.buffer += data + "\n";
            }
        }
        onExited: (exitCode, exitStatus) => {
            const lines = updateConnectionType.buffer.trim().split('\n');
            const connectivity = lines.pop() // none, limited, full
            let hasEthernet = false;
            let hasWifi = false;
            let wifiStatus = "disconnected";
            let wifiName = "";
            let ethernetName = "";
            lines.forEach(line => {
                // TYPE:STATE:CONNECTION — the connection name may itself contain
                // colons (escaped), so keep everything past the second field.
                const fields = line.split(":");
                const type = fields[0];
                const state = fields[1] ?? "";
                const connection = fields.slice(2).join(":").replace(/\\:/g, ":");

                if (type === "ethernet" && state.startsWith("connected")) {
                    hasEthernet = true;
                    ethernetName = connection;
                } else if (type === "wifi") {
                    if (state.startsWith("disconnected")) {
                        wifiStatus = "disconnected"
                    }
                    else if (state.startsWith("connected")) {
                        hasWifi = true;
                        wifiStatus = "connected"
                        wifiName = connection;

                        if (connectivity === "limited") {
                            hasWifi = false;
                            wifiStatus = "limited"
                        }
                    }
                    else if (state.startsWith("connecting")) {
                        wifiStatus = "connecting"
                    }
                    else if (state.startsWith("unavailable")) {
                        wifiStatus = "disabled"
                    }
                }
            });
            root.wifiStatus = wifiStatus;
            root.ethernet = hasEthernet;
            root.wifi = hasWifi;
            root.activeWifiName = wifiName;
            // Was `nmcli -t -f NAME c show --active | head -1`, which returns
            // whichever active connection nmcli happens to list first — a VPN or
            // a docker bridge just as easily as the Wi-Fi. That is why the bar
            // and the dialog could name two different networks.
            root.networkName = wifiName.length > 0 ? wifiName : ethernetName;
        }
    }

    Process {
        id: updateNetworkStrength
        running: true
        // `--rescan no` keeps this reading the cache: without it nmcli starts a
        // scan whenever the cached results are stale and blocks until it lands.
        command: ["sh", "-c", "nmcli -f IN-USE,SIGNAL,SSID device wifi list --rescan no | awk '/^\\*/{if (NR!=1) {print $2}}'"]
        stdout: SplitParser {
            onRead: data => {
                root.networkStrength = parseInt(data);
            }
        }
    }

    Process {
        id: wifiStatusProcess
        command: ["nmcli", "radio", "wifi"]
        Component.onCompleted: running = true
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiEnabled = text.trim() === "enabled";
            }
        }
    }

    Process {
        id: getNetworks
        running: true
        // See updateNetworkStrength: `--rescan no` is what makes this return
        // immediately instead of occasionally blocking on a full scan.
        command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        environment: ({
            LANG: "C",
            LC_ALL: "C"
        })
        stdout: StdioCollector {
            onStreamFinished: {
                const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                const rep = new RegExp("\\\\:", "g");
                const rep2 = new RegExp(PLACEHOLDER, "g");

                const allNetworks = text.trim().split("\n").map(n => {
                    const net = n.replace(rep, PLACEHOLDER).split(":");
                    return {
                        active: net[0] === "yes",
                        strength: parseInt(net[1]),
                        frequency: parseInt(net[2]),
                        ssid: net[3],
                        bssid: net[4]?.replace(rep2, ":") ?? "",
                        security: net[5] || ""
                    };
                }).filter(n => n.ssid && n.ssid.length > 0);

                // Group networks by SSID and prioritize connected ones
                const networkMap = new Map();
                for (const network of allNetworks) {
                    const existing = networkMap.get(network.ssid);
                    if (!existing) {
                        networkMap.set(network.ssid, network);
                    } else {
                        // Prioritize active/connected networks
                        if (network.active && !existing.active) {
                            networkMap.set(network.ssid, network);
                        } else if (!network.active && !existing.active) {
                            // If both are inactive, keep the one with better signal
                            if (network.strength > existing.strength) {
                                networkMap.set(network.ssid, network);
                            }
                        }
                        // If existing is active and new is not, keep existing
                    }
                }

                const wifiNetworks = Array.from(networkMap.values());

                const rNetworks = root.wifiNetworks;

                const destroyed = rNetworks.filter(rn => !wifiNetworks.find(n => n.frequency === rn.frequency && n.ssid === rn.ssid && n.bssid === rn.bssid));
                for (const network of destroyed)
                    rNetworks.splice(rNetworks.indexOf(network), 1).forEach(n => n.destroy());

                for (const network of wifiNetworks) {
                    const match = rNetworks.find(n => n.frequency === network.frequency && n.ssid === network.ssid && n.bssid === network.bssid);
                    if (match) {
                        match.lastIpcObject = network;
                    } else {
                        rNetworks.push(apComp.createObject(root, {
                            lastIpcObject: network
                        }));
                    }
                }

                // The list is mutated in place, which does not notify on its own:
                // bindings over it only re-ran because updating an existing access
                // point's `lastIpcObject` happened to notify. With an empty list
                // there is nothing to update, so the first batch of networks could
                // land without a single binding noticing and the picker stayed
                // empty for the life of the process.
                root.wifiNetworksChanged();
            }
        }
    }

    Component {
        id: apComp

        WifiAccessPoint {}
    }
}
