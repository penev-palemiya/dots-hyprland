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


    readonly property bool discovering: Bluetooth.defaultAdapter?.discovering ?? false
    readonly property var connectedDevices: BluetoothStatus.connectedDevices
    readonly property var savedDevices: BluetoothStatus.pairedButNotConnectedDevices
    readonly property var nearbyDevices: BluetoothStatus.unpairedDevices

    WindowDialogHeader {
        id: header

        title: Translation.tr("Bluetooth")
        subtitle: {
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
            onClicked: {
                if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering;
            }
        }
    }

    StyledIndeterminateProgressBar {
        visible: root.discovering
        Layout.fillWidth: true
        Layout.topMargin: -10
        Layout.bottomMargin: -10
        Layout.leftMargin: -root.contentPadding
        Layout.rightMargin: -root.contentPadding
    }

    ScrollDivider {
        target: flickable
        atStart: true
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

                Layout.fillWidth: true
                visible: section.devices.length > 0
                spacing: 6

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
                        }
                    }
                }
            }

            DeviceSection {
                label: Translation.tr("Connected")
                devices: root.connectedDevices
            }

            DeviceSection {
                label: Translation.tr("Saved")
                devices: root.savedDevices
            }

            DeviceSection {
                label: Translation.tr("Nearby")
                devices: root.nearbyDevices
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
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
    }

    WindowDialogButtonRow {
        id: footer
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
