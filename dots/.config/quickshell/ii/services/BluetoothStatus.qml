pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: Bluetooth.adapters.values.length > 0
    readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
    // -1 means "no adapter at all", distinct from any real BluetoothAdapterState value.
    readonly property int adapterState: Bluetooth.defaultAdapter?.state ?? -1
    readonly property bool blocked: root.adapterState === BluetoothAdapterState.Blocked
    readonly property BluetoothDevice firstActiveDevice: Bluetooth.defaultAdapter?.devices.values.find(device => device.connected) ?? null
    readonly property int activeDeviceCount: Bluetooth.defaultAdapter?.devices.values.filter(device => device.connected).length ?? 0
    readonly property bool connected: (Bluetooth.defaultAdapter?.devices.values ?? []).some(d => d.connected)
    // True while any device on the adapter is mid-pair or mid-connect. Lets the dialogs
    // pause discovery for the duration of an operation without any single component
    // needing to track "did I pause it" across its own lifetime - which delegates don't
    // reliably have, since a device moving from Nearby to Saved the moment it pairs
    // destroys and recreates the delegate that started the operation.
    readonly property bool anyDevicePairingOrConnecting: (Bluetooth.defaultAdapter?.devices.values ?? []).some(d => d.pairing || d.state === BluetoothDeviceState.Connecting)

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
    property list<var> connectedDevices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d => d.connected).sort(sortFunction)
    property list<var> pairedButNotConnectedDevices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d => d.paired && !d.connected).sort(sortFunction)
    property list<var> unpairedDevices: (Bluetooth.defaultAdapter?.devices.values ?? []).filter(d => !d.paired && !d.connected).sort(sortFunction)
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
        for (const d of (Bluetooth.defaultAdapter?.devices.values ?? []))
            livePaths[d.dbusPath] = true;
        for (const path in root._connectAfterPair) {
            if (!livePaths[path])
                delete root._connectAfterPair[path];
        }
    }
}
