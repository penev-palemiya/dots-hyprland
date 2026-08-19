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
 * Clicking a disconnected device connects to it directly.
 * Clicking a connected device disconnects it.
 */
GroupedListCard {
    id: root

    required property BluetoothDevice device

    readonly property bool connected: root.device?.connected ?? false
    readonly property bool connecting: (root.device?.state === BluetoothDeviceState.Connecting) || (root.device?.connecting ?? false)
    readonly property bool disconnecting: root.device?.state === BluetoothDeviceState.Disconnecting
    readonly property bool paired: root.device?.paired ?? false
    readonly property bool batteryKnown: root.device?.batteryAvailable ?? false
    readonly property int batteryPercent: Math.round((root.device?.battery ?? 0) * 100)
    // Worth flagging before the headphones die mid-call.
    readonly property bool batteryLow: root.batteryKnown && root.batteryPercent <= 20

    property bool confirmingForget: false

    selected: root.connected
    expanded: root.confirmingForget || (root.connected && root.batteryKnown)
    interactive: !root.connecting && !root.disconnecting

    actionIcon: (root.paired && !root.connecting && !root.disconnecting) ? "delete" : ""
    onActionClicked: root.confirmingForget = !root.confirmingForget

    onPairedChanged: if (!root.paired) root.confirmingForget = false;

    iconName: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
    title: root.device?.name || root.device?.deviceName || Translation.tr("Unknown device")

    subtitle: {
        const parts = [];
        if (root.connecting)
            parts.push(Translation.tr("Connecting…"));
        else if (root.disconnecting)
            parts.push(Translation.tr("Disconnecting…"));
        else if (root.connected)
            parts.push(Translation.tr("Connected"));
        else if (root.paired)
            parts.push(Translation.tr("Saved"));

        if (root.batteryKnown)
            parts.push(`${root.batteryPercent}%`);
        return parts.join(" • ");
    }

    trailingIcon: (root.connecting || root.disconnecting) ? "sync" : root.connected ? "check_circle" : ""
    trailingSpinning: root.connecting || root.disconnecting

    function connectDevice(): void {
        if (!root.device) return;

        // Stop active scanning so it doesn't cause radio congestion / packet loss during handshake
        if (Bluetooth.defaultAdapter?.discovering) {
            Bluetooth.defaultAdapter.discovering = false;
        }

        try {
            root.device.trusted = true;
        } catch (e) {}

        try {
            root.device.connect();
        } catch (e) {
            if (root.device.address) {
                Quickshell.execDetached(["bluetoothctl", "connect", root.device.address]);
            }
        }
    }

    function disconnectDevice(): void {
        if (!root.device) return;
        try {
            root.device.disconnect();
        } catch (e) {
            if (root.device.address) {
                Quickshell.execDetached(["bluetoothctl", "disconnect", root.device.address]);
            }
        }
    }

    function forgetDevice(): void {
        if (!root.device) return;
        root.confirmingForget = false;
        if (Bluetooth.defaultAdapter && typeof Bluetooth.defaultAdapter.removeDevice === "function") {
            try {
                Bluetooth.defaultAdapter.removeDevice(root.device);
                return;
            } catch (e) {}
        }
        if (root.device.address) {
            Quickshell.execDetached(["bluetoothctl", "remove", root.device.address]);
        }
    }

    onClicked: {
        if (root.connected) {
            root.disconnectDevice();
        } else {
            root.connectDevice();
        }
    }

    property bool staggered: false

    Component.onCompleted: if (!root.staggered) enterAnimation.start();

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
