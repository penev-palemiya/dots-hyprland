import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell

/**
 * Bluetooth picker, split into the three groups the service already computes.
 *
 * `BluetoothStatus` has kept `connectedDevices`, `pairedButNotConnectedDevices`
 * and `unpairedDevices` separate all along, and the view was flattening them
 * back into `friendlyDeviceList` — so "connected", "saved" and "just nearby"
 * all rendered identically and the sections existed only as sort order.
 */
WindowDialog {
    id: root

    readonly property real maxListHeight: 380

    // Same cascade as the Wi-Fi picker, driven by WindowDialog: header,
    // connected, saved, nearby, footer.
    staggerContent: true
    revealSections: 5

    readonly property bool discovering: Bluetooth.defaultAdapter?.discovering ?? false
    readonly property var connectedDevices: BluetoothStatus.connectedDevices
    readonly property var savedDevices: BluetoothStatus.pairedButNotConnectedDevices
    readonly property var nearbyDevices: BluetoothStatus.unpairedDevices

    // Pauses discovery for the duration of any pair/connect operation happening
    // anywhere in this dialog, and restores it after - tracked here rather than on
    // whichever row started the operation, since that row's delegate can be
    // destroyed and recreated mid-operation (see BluetoothStatus.anyDevicePairingOrConnecting).
    //
    // The specific adapter instance that was paused is remembered (not just a
    // boolean), and resumed on that same instance - never on whatever
    // Bluetooth.defaultAdapter happens to resolve to when the operation ends, which
    // could by then be a different physical adapter. QML object-type properties are
    // reset to null automatically if the referenced QObject is destroyed (e.g. the
    // adapter is unplugged before the operation ends), so this can't dereference a
    // dangling adapter either.
    property bool pausedDiscovery: false
    Connections {
        target: BluetoothStatus
        function onAnyDevicePairingOrConnectingChanged() {
            // `show` goes false the instant the dialog is dismissed, well before
            // ToggleDialog's close animation finishes or this item is actually
            // destroyed (it stays mounted through both - see onShowChanged below).
            // Without this gate, an operation that outlives the close animation
            // would find this watcher still alive and turn discovery back on for a
            // dialog the user already left.
            if (!root.show)
                return;
            if (BluetoothStatus.anyDevicePairingOrConnecting) {
                if (root.show && BluetoothStatus.discoveryRequested("quick-settings")) {
                    root.pausedDiscovery = true;
                    BluetoothStatus.releaseDiscovery("quick-settings");
                }
            } else if (root.pausedDiscovery && root.show) {
                root.pausedDiscovery = false;
                BluetoothStatus.acquireDiscovery("quick-settings");
            }
        }
    }

    // Dismissing the dialog permanently cancels any pending resume, rather than
    // leaving it for a background operation to act on later. This is what makes the
    // `!root.show` gate above airtight even if this property were somehow left set
    // from before the dialog closed.
    onShowChanged: {
        if (!root.show) {
            root.pausedDiscovery = false;
            BluetoothStatus.releaseDiscovery("quick-settings");
        }
    }

    WindowDialogHeader {
        id: header

        opacity: root.sectionOpacity(0)
        transform: Translate {
            y: root.sectionOffset(0)
        }

        title: Translation.tr("Bluetooth")
        subtitle: {
            if (!Bluetooth.defaultAdapter)
                return Translation.tr("No Bluetooth adapter found");
            if (BluetoothStatus.blocked)
                return Translation.tr("Blocked (airplane mode / rfkill)");
            if (!BluetoothStatus.enabled)
                return Translation.tr("Turned off");
            if (root.discovering)
                return Translation.tr("Scanning…");
            const n = root.connectedDevices.length;
            if (n > 0)
                return Translation.tr("%1 connected").arg(n);
            return Translation.tr("Nothing connected");
        }

        // Discovery is a real toggle, not a one-shot: it stays on until turned
        // off, so the button reflects that instead of pretending to be a
        // refresh action.
        DialogIconButton {
            iconName: "bluetooth_searching"
            toggledOn: root.discovering
            enabled: BluetoothStatus.enabled
            onClicked: {
                if (BluetoothStatus.discoveryRequested("quick-settings"))
                    BluetoothStatus.releaseDiscovery("quick-settings");
                else
                    BluetoothStatus.acquireDiscovery("quick-settings");
            }
        }
    }

    // Keeps its space and only fades, so starting discovery doesn't relay the
    // whole dialog out from under the pointer.
    StyledIndeterminateProgressBar {
        Layout.fillWidth: true
        Layout.topMargin: -10
        Layout.bottomMargin: -10
        Layout.leftMargin: -root.contentPadding
        Layout.rightMargin: -root.contentPadding

        opacity: root.sectionOpacity(0) * (root.discovering ? 1 : 0)
        indeterminate: root.discovering

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    ScrollDivider {
        target: flickable
        atStart: true
        revealOpacity: root.sectionOpacity(1)
    }

    Item {
        id: scrollArea

        Layout.fillWidth: true
        implicitHeight: Math.min(root.maxListHeight, deviceColumn.implicitHeight)

        StyledFlickable {
            id: flickable

            anchors.fill: parent
            clip: true
            contentHeight: deviceColumn.implicitHeight

        ColumnLayout {
            id: deviceColumn

            width: flickable.width
            spacing: 16

            component DeviceSection: ColumnLayout {
                id: section

                required property string label
                required property var devices
                required property int revealIndex

                Layout.fillWidth: true
                visible: section.devices.length > 0
                spacing: 6

                opacity: root.sectionOpacity(section.revealIndex)
                transform: Translate {
                    y: root.sectionOffset(section.revealIndex)
                }

                ListSectionLabel {
                    text: section.label
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ScriptModel {
                            values: section.devices
                        }

                        delegate: BluetoothDeviceItem {
                            required property BluetoothDevice modelData
                            required property int index

                            Layout.fillWidth: true
                            device: modelData
                            indexInSection: index
                            sectionCount: section.devices.length
                            staggered: root.revealing
                        }
                    }
                }
            }

            DeviceSection {
                label: Translation.tr("Connected")
                devices: root.connectedDevices
                revealIndex: 1
            }

            DeviceSection {
                label: Translation.tr("Saved")
                devices: root.savedDevices
                revealIndex: 2
            }

            DeviceSection {
                label: Translation.tr("Nearby")
                devices: root.nearbyDevices
                revealIndex: 3
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
                opacity: root.sectionOpacity(2)
                visible: root.connectedDevices.length === 0 && root.savedDevices.length === 0 && root.nearbyDevices.length === 0
                text: root.discovering ? Translation.tr("Scanning…") : Translation.tr("No devices found")
                color: Appearance.colors.colOutline
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
        }

    }

    ScrollDivider {
        target: flickable
        atStart: false
        revealOpacity: root.sectionOpacity(3)
    }

    WindowDialogButtonRow {
        id: footer

        opacity: root.sectionOpacity(4)
        transform: Translate {
            y: root.sectionOffset(4)
        }

        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Config.options.apps.bluetooth}`]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            colText: Appearance.colors.colOnPrimary
            onClicked: root.dismiss()
        }
    }
}
