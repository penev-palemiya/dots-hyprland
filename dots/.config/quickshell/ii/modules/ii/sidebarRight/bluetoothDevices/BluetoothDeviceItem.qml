import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

/**
 * One Bluetooth device, as a card in a grouped list.
 * Clicking a disconnected paired device connects to it; clicking an unpaired
 * one pairs it first, then connects once pairing succeeds. Clicking a
 * connected device disconnects it.
 */
GroupedListCard {
    id: root

    required property BluetoothDevice device

    readonly property bool connected: root.device?.connected ?? false
    readonly property bool connecting: root.device?.state === BluetoothDeviceState.Connecting
    readonly property bool disconnecting: root.device?.state === BluetoothDeviceState.Disconnecting
    readonly property bool pairingNow: root.device?.pairing ?? false
    readonly property bool paired: root.device?.paired ?? false
    readonly property bool batteryKnown: root.device?.batteryAvailable ?? false
    readonly property int batteryPercent: Math.round((root.device?.battery ?? 0) * 100)
    // Worth flagging before the headphones die mid-call.
    readonly property bool batteryLow: root.batteryKnown && root.batteryPercent <= 20

    property bool confirmingForget: false

    // Set only for an operation *this row* initiated, so a device that connects or
    // fails externally (another app, another Bluetooth UI) doesn't get misread as
    // "we tried and it failed".
    property bool opConnecting: false
    property bool opDisconnecting: false
    property bool opPairing: false
    property int lastKnownState: root.device?.state ?? BluetoothDeviceState.Disconnected

    property bool pairFailed: false
    property bool connectFailed: false

    selected: root.connected
    expanded: root.confirmingForget || (root.connected && root.batteryKnown)
    interactive: !root.connecting && !root.disconnecting && !root.pairingNow

    actionIcon: (root.paired && !root.connecting && !root.disconnecting && !root.pairingNow) ? "delete" : ""
    onActionClicked: root.confirmingForget = !root.confirmingForget

    onPairedChanged: {
        if (root.device?.paired) {
            // Claim the operation as successful immediately, before any deferred
            // failure check (see onPairingChanged below) gets to run. `paired` and
            // `pairing` are independent D-Bus-driven signals with no guaranteed
            // order, so this - not a read of `paired` taken at some other moment -
            // is what makes the outcome order-independent.
            root.opPairing = false;
            root.pairFailed = false;
            // Trust is set on success rather than before attempting it, so a device
            // the user tried once and gave up on doesn't stay auto-reconnect-eligible.
            root.device.trusted = true;
            root.continueAfterPairIfRequested();
        } else {
            root.confirmingForget = false;
        }
    }

    // A device object is only ever handed to this delegate while it's tracked by
    // Quickshell; when BlueZ removes it, the model removes it and this delegate is
    // destroyed along with it, so there's no "stale device" case to guard beyond the
    // required-property binding itself going away.
    Connections {
        target: root.device

        function onStateChanged() {
            const s = root.device.state;
            const prev = root.lastKnownState;
            root.lastKnownState = s;

            if (s === BluetoothDeviceState.Connected) {
                // Any arrival at Connected - ours or someone else's - is success.
                root.opConnecting = false;
                root.opDisconnecting = false;
                root.connectFailed = false;
            } else if (s === BluetoothDeviceState.Disconnected) {
                if (root.opConnecting && prev === BluetoothDeviceState.Connecting) {
                    root.connectFailed = true;
                }
                root.opConnecting = false;
                root.opDisconnecting = false;
            }
        }

        function onPairingChanged() {
            if (root.device.pairing)
                return; // Started pairing; wait for it to resolve.
            if (!root.opPairing)
                return; // Already resolved - either not ours, or already claimed
                         // as a success by onPairedChanged. Nothing to do.
            // Don't decide failure from `paired` read right here: if the `Paired`
            // PropertiesChanged signal hasn't been processed yet, this would read
            // false for a pairing that actually just succeeded. Defer one event
            // loop turn so a `paired` update already in flight gets a chance to
            // reach onPairedChanged and claim success first - see resolvePairingOutcome.
            Qt.callLater(root.resolvePairingOutcome);
        }
    }

    // Runs after yielding once to the event loop, so a `paired` change that arrived
    // essentially simultaneously with (but was queued behind, or ahead of) this
    // pairing-stopped signal has a chance to be processed first. If it was,
    // onPairedChanged already cleared opPairing and this is a no-op.
    function resolvePairingOutcome(): void {
        if (!root.opPairing)
            return;
        root.opPairing = false;
        if (!root.device || !root.device.paired) {
            root.pairFailed = true;
            if (root.device)
                BluetoothStatus.clearConnectAfterPair(root.device);
        }
    }

    iconName: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
    title: root.device?.name || root.device?.deviceName || Translation.tr("Unknown device")

    subtitle: {
        const parts = [];
        if (root.pairingNow)
            parts.push(Translation.tr("Pairing…"));
        else if (root.connecting)
            parts.push(Translation.tr("Connecting…"));
        else if (root.disconnecting)
            parts.push(Translation.tr("Disconnecting…"));
        else if (root.pairFailed)
            parts.push(Translation.tr("Couldn't pair"));
        else if (root.connectFailed)
            parts.push(Translation.tr("Couldn't connect"));
        else if (root.connected)
            parts.push(Translation.tr("Connected"));
        else if (root.paired)
            parts.push(Translation.tr("Saved"));

        if (root.batteryKnown)
            parts.push(`${root.batteryPercent}%`);
        return parts.join(" • ");
    }

    trailingIcon: (root.pairingNow || root.connecting || root.disconnecting) ? "sync" : (root.pairFailed || root.connectFailed) ? "error" : root.connected ? "check_circle" : ""
    trailingSpinning: root.pairingNow || root.connecting || root.disconnecting

    // If a connect-after-pair was requested by a now-destroyed delegate for this
    // same device, and pairing has since succeeded, finish the job. Checked both on
    // the paired-changed transition (same-delegate case) and on mount (the device
    // moved sections and this is a fresh delegate for it).
    function continueAfterPairIfRequested(): void {
        if (!root.device)
            return;
        if (!BluetoothStatus.consumeConnectAfterPair(root.device))
            return;
        if (root.device.paired && !root.device.connected)
            root.startConnect();
    }

    function startConnect(): void {
        if (!root.device || root.device.connected)
            return;
        if (root.device.state === BluetoothDeviceState.Connecting)
            return;
        root.connectFailed = false;
        root.opConnecting = true;
        root.lastKnownState = root.device.state;
        root.device.connect();
    }

    function startPair(): void {
        if (!root.device || root.device.pairing || root.device.paired)
            return;
        root.pairFailed = false;
        root.opPairing = true;
        root.device.pair();
    }

    function connectDevice(): void {
        if (!root.device)
            return;

        root.pairFailed = false;
        root.connectFailed = false;

        if (root.device.paired) {
            root.startConnect();
        } else {
            BluetoothStatus.markConnectAfterPair(root.device);
            root.startPair();
        }
    }

    function disconnectDevice(): void {
        if (!root.device || !root.device.connected)
            return;
        if (root.device.state === BluetoothDeviceState.Disconnecting)
            return;
        root.opDisconnecting = true;
        root.lastKnownState = root.device.state;
        root.device.disconnect();
    }

    function forgetDevice(): void {
        if (!root.device)
            return;
        root.confirmingForget = false;
        BluetoothStatus.clearConnectAfterPair(root.device);
        root.device.forget();
    }

    onClicked: {
        if (root.connected) {
            root.disconnectDevice();
        } else {
            root.connectDevice();
        }
    }

    property bool staggered: false

    Component.onCompleted: {
        root.continueAfterPairIfRequested();
        if (!root.staggered)
            enterAnimation.start();
    }

    ParallelAnimation {
        id: enterAnimation

        running: false

        NumberAnimation {
            target: root
            property: "scale"
            from: 0.94
            to: 1
            duration: Appearance.animation.elementMoveSmall.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveSmall.bezierCurve
        }

        NumberAnimation {
            target: root
            property: "opacity"
            from: 0
            to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    // Battery gets a real bar once it's actually known
    Rectangle {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        visible: root.connected && root.batteryKnown
        implicitHeight: 4
        radius: height / 2
        color: Appearance.colors.colSurfaceContainerHighest

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, (root.device?.battery ?? 0)))
            height: parent.height
            radius: parent.radius
            color: root.batteryLow ? Appearance.colors.colError : Appearance.colors.colPrimary

            Behavior on width {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }

    // ---- forget confirmation ----
    StyledText {
        Layout.fillWidth: true
        visible: root.confirmingForget
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: Translation.tr("Forget this device? It will need to be paired again.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colOnSurfaceVariant
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.confirmingForget
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: root.confirmingForget = false
        }

        DialogButton {
            buttonText: Translation.tr("Forget")
            colBackground: Appearance.colors.colError
            colBackgroundHover: Appearance.colors.colErrorHover
            colRipple: Appearance.colors.colErrorActive
            colText: Appearance.colors.colOnError
            onClicked: root.forgetDevice()
        }
    }
}
