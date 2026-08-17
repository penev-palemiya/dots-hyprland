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

    WindowDialogHeader {
        id: header

        opacity: root.sectionOpacity(0)
        transform: Translate {
            y: root.sectionOffset(0)
        }

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
