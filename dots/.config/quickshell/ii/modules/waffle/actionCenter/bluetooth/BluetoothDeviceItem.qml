import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

ExpandableChoiceButton {
    id: root
    required property BluetoothDevice device

    readonly property bool connecting: root.device?.state === BluetoothDeviceState.Connecting
    readonly property bool disconnecting: root.device?.state === BluetoothDeviceState.Disconnecting
    readonly property bool pairingNow: root.device?.pairing ?? false

    property bool opConnecting: false
    property bool opDisconnecting: false
    property bool opPairing: false
    property int lastKnownState: root.device?.state ?? BluetoothDeviceState.Disconnected

    property bool pairFailed: false
    property bool connectFailed: false

    Connections {
        target: root.device

        function onPairedChanged() {
            if (root.device.paired) {
                // Claim success before any deferred failure check (see
                // onPairingChanged below) runs - `paired` and `pairing` are
                // independent signals with no guaranteed order.
                root.opPairing = false;
                root.pairFailed = false;
                root.device.trusted = true;
                root.continueAfterPairIfRequested();
            }
        }

        function onStateChanged() {
            const s = root.device.state;
            const prev = root.lastKnownState;
            root.lastKnownState = s;

            if (s === BluetoothDeviceState.Connected) {
                root.opConnecting = false;
                root.opDisconnecting = false;
                root.connectFailed = false;
            } else if (s === BluetoothDeviceState.Disconnected) {
                if (root.opConnecting && prev === BluetoothDeviceState.Connecting)
                    root.connectFailed = true;
                root.opConnecting = false;
                root.opDisconnecting = false;
            }
        }

        function onPairingChanged() {
            if (root.device.pairing)
                return;
            if (!root.opPairing)
                return;
            // See resolvePairingOutcome() - deferred so a `paired` change already
            // in flight can claim success first, regardless of signal order.
            Qt.callLater(root.resolvePairingOutcome);
        }
    }

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

    Component.onCompleted: root.continueAfterPairIfRequested()

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

    function toggleConnection(): void {
        if (!root.device)
            return;

        if (root.device.connected) {
            if (root.device.state === BluetoothDeviceState.Disconnecting)
                return;
            root.opDisconnecting = true;
            root.lastKnownState = root.device.state;
            root.device.disconnect();
            return;
        }

        root.pairFailed = false;
        root.connectFailed = false;

        if (root.device.paired) {
            root.startConnect();
        } else {
            BluetoothStatus.markConnectAfterPair(root.device);
            root.startPair();
        }
    }

    contentItem: RowLayout {
        id: contentItem
        spacing: 20

        // Device icon
        FluentIcon {
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.alignment: Qt.AlignTop
            icon: WIcons.bluetoothDeviceIcon(root?.device)
            implicitSize: 18
        }

        ColumnLayout {
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            spacing: 0

            WText {
                // Network name
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Looks.font.pixelSize.large
                text: root.device?.name || Translation.tr("Unknown device")
                textFormat: Text.PlainText
            }
            WText { // Status
                id: statusText
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.pixelSize: Looks.font.pixelSize.large
                color: Looks.colors.subfg
                visible: root.device?.connected || root.expanded || root.pairingNow || root.pairFailed || root.connectFailed
                Behavior on opacity {
                    animation: Looks.transition.opacity.createObject(this)
                }
                text: {
                    if (root.pairingNow)
                        return Translation.tr("Pairing…");
                    if (root.connecting)
                        return Translation.tr("Connecting…");
                    if (root.disconnecting)
                        return Translation.tr("Disconnecting…");
                    if (root.pairFailed)
                        return Translation.tr("Couldn't pair");
                    if (root.connectFailed)
                        return Translation.tr("Couldn't connect");
                    if (!root.device?.paired)
                        return Translation.tr("Not connected");
                    let statusText = root.device?.connected ? Translation.tr("Connected") : Translation.tr("Paired");
                    if (!root.device?.batteryAvailable)
                        return statusText;
                    statusText += ` • ${Math.round(root.device?.battery * 100)}%`;
                    return statusText;
                }
            }

            WButton {
                Layout.alignment: Qt.AlignRight
                horizontalAlignment: Text.AlignHCenter
                visible: root.expanded
                enabled: !root.connecting && !root.disconnecting && !root.pairingNow
                checked: !(root.device?.connected ?? false)
                colBackground: Looks.colors.bg2
                colBackgroundHover: Looks.colors.bg2Hover
                colBackgroundActive: Looks.colors.bg2Active
                implicitHeight: 30
                implicitWidth: 148
                text: root.device?.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")

                onClicked: root.toggleConnection()
            }
        }
    }
}
