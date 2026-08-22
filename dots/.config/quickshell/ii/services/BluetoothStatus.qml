pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property var adapters: Bluetooth.adapters.values
    readonly property var defaultAdapter: Bluetooth.defaultAdapter
    readonly property bool available: root.adapters.length > 0
    readonly property bool enabled: root.defaultAdapter?.enabled ?? false
    // -1 means "no adapter at all", distinct from any real BluetoothAdapterState value.
    readonly property int adapterState: root.defaultAdapter?.state ?? -1
    readonly property bool blocked: root.adapterState === BluetoothAdapterState.Blocked
    readonly property var devices: root.adapters.reduce((all, adapter) => all.concat(adapter.devices.values), [])
    readonly property BluetoothDevice firstActiveDevice: root.connectedDevices[0] ?? null
    readonly property int activeDeviceCount: root.connectedDevices.length
    readonly property bool connected: root.connectedDevices.length > 0
    // True while any device on the adapter is mid-pair or mid-connect. Lets the dialogs
    // pause discovery for the duration of an operation without any single component
    // needing to track "did I pause it" across its own lifetime - which delegates don't
    // reliably have, since a device moving from Nearby to Saved the moment it pairs
    // destroys and recreates the delegate that started the operation.
    readonly property bool anyDevicePairingOrConnecting: root.devices.some(d => d.pairing || d.state === BluetoothDeviceState.Connecting)

    // BlueZ identifies devices by object path/address. These normalized lists are
    // shared by Quick Settings and standalone Settings; names are presentation only.
    readonly property var pairedDevices: root.devices.filter(d => d.paired).sort(sortFunction)
    readonly property var connectedDevices: root.devices.filter(d => d.connected).sort(sortFunction)
    readonly property var availableDevices: root.devices.filter(d => !d.paired && !d.connected && (d.name || d.deviceName)).sort(sortFunction)
    readonly property var _discoveryOwners: ({})

    function sortFunction(a, b) {
        const aName = a?.name || a?.deviceName || "";
        const bName = b?.name || b?.deviceName || "";
        // Ones with meaningful names before MAC addresses
        const macRegex = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/;
        const aIsMac = macRegex.test(aName);
        const bIsMac = macRegex.test(bName);
        if (aIsMac !== bIsMac)
            return aIsMac ? 1 : -1;

        // Alphabetical by name
        return aName.localeCompare(bName);
    }
    property var pairedButNotConnectedDevices: root.pairedDevices.filter(d => !d.connected)
    property var unpairedDevices: root.availableDevices
    property list<var> friendlyDeviceList: [
        ...connectedDevices,
        ...pairedButNotConnectedDevices,
        ...unpairedDevices
    ]

    // Records intent to connect a device once its pairing succeeds, keyed by the
    // device's stable dbusPath rather than kept on the delegate that requested it.
    // Reason: pairing succeeding changes `paired`, which moves the device from the
    // Nearby list to the Saved list, which destroys and recreates the delegate that
    // called pair() - any state kept only on that delegate would be lost right as
    // pairing finishes. This is read by whichever delegate is showing the device next.
    property var _connectAfterPair: ({})

    function deviceName(device) { return device?.name || device?.deviceName || "Unknown device"; }

    function deviceConnecting(device) { return device?.state === BluetoothDeviceState.Connecting; }

    function deviceType(device) {
        const icon = (device?.icon || "").toLowerCase();
        if (icon.includes("headset")) return "Headset";
        if (icon.includes("headphone")) return "Headphones";
        if (icon.includes("audio") || icon.includes("speaker")) return "Speaker";
        if (icon.includes("mouse")) return "Mouse";
        if (icon.includes("keyboard")) return "Keyboard";
        if (icon.includes("game") || icon.includes("joystick")) return "Game Controller";
        if (icon.includes("phone")) return "Phone";
        if (icon.includes("computer") || icon.includes("laptop")) return "Computer";
        return "Other";
    }

    function acquireDiscovery(owner) {
        if (!owner) return false;
        root._discoveryOwners[owner] = true;
        root._syncDiscovery();
        return true;
    }

    function releaseDiscovery(owner) {
        if (!owner) return false;
        delete root._discoveryOwners[owner];
        root._syncDiscovery();
        return true;
    }

    function discoveryRequested(owner) { return Boolean(root._discoveryOwners[owner]); }

    function _syncDiscovery() {
        const requested = Object.keys(root._discoveryOwners).length > 0;
        for (const adapter of root.adapters) {
            if (!adapter.enabled) continue;
            if (requested && !adapter.discovering) adapter.discovering = true;
            else if (!requested && adapter.discovering) adapter.discovering = false;
        }
    }

    Connections {
        target: Bluetooth
        function onDefaultAdapterChanged() { root._syncDiscovery(); }
    }

    function markConnectAfterPair(device) {
        if (!device) return;
        root._connectAfterPair[device.dbusPath] = true;
    }

    // One-shot: returns true at most once per markConnectAfterPair() call, so
    // connect() can never be fired twice for the same pairing attempt even if more
    // than one delegate instance ends up checking it.
    function consumeConnectAfterPair(device) {
        if (!device) return false;
        const path = device.dbusPath;
        if (root._connectAfterPair[path]) {
            delete root._connectAfterPair[path];
            return true;
        }
        return false;
    }

    function clearConnectAfterPair(device) {
        if (!device) return;
        delete root._connectAfterPair[device.dbusPath];
    }

    // A device that disappears (goes out of range mid-pair, gets removed, or its
    // adapter disappears entirely) before its own pairing/connect signals resolve
    // would otherwise leave its dbusPath in _connectAfterPair forever. Since BlueZ
    // hands out the same dbusPath to a later rediscovery of the same physical
    // device - a genuinely different BluetoothDevice object, per bluez.cpp deleting
    // the old one and constructing a new one on re-add - a stale entry left behind
    // would wrongly auto-connect that unrelated future device. friendlyDeviceList
    // already recomputes from the live device set on every add/remove (and on
    // adapter change, where it collapses to an empty list), so pruning here runs at
    // exactly the right cadence for free.
    onFriendlyDeviceListChanged: root._prunePendingConnectIntents()

    function _prunePendingConnectIntents() {
        const livePaths = {};
        for (const d of root.devices)
            livePaths[d.dbusPath] = true;
        for (const path in root._connectAfterPair) {
            if (!livePaths[path])
                delete root._connectAfterPair[path];
        }
    }
}
