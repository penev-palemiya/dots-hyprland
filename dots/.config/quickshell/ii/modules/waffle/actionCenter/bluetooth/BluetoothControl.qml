import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.waffle.looks
import qs.modules.waffle.actionCenter

Item {
    id: root

    Component.onCompleted: {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter?.enabled)
            adapter.discovering = true;
    }
    Component.onDestruction: {
        const adapter = Bluetooth.defaultAdapter;
        if (adapter)
            adapter.discovering = false;
    }

    // Pauses discovery for the duration of any pair/connect operation, and restores
    // it after - tracked here rather than per-row, since a row's delegate can be
    // destroyed/recreated mid-operation as the device's paired/connected state changes
    // (see BluetoothStatus.anyDevicePairingOrConnecting).
    //
    // The specific adapter instance that was paused is remembered (not just a
    // boolean) and resumed on that same instance only - never on whatever
    // Bluetooth.defaultAdapter resolves to when the operation ends, which could by
    // then be a different physical adapter. This QObject-type property is reset to
    // null automatically if the adapter is destroyed (e.g. unplugged mid-operation).
    property BluetoothAdapter pausedAdapter: null

    // StackView.status flips away from Active the instant back() pops this screen,
    // well before the pop transition finishes and this item is actually destroyed
    // (StackView keeps popped items alive through their own exit transition, same
    // as ToggleDialog does on the ii side). Component.onDestruction below only
    // fires after that, so it can't gate this on its own - a pair/connect that
    // outlives the pop transition would otherwise find the watcher still alive.
    readonly property bool activeOnStack: StackView.status === StackView.Active
    onActiveOnStackChanged: if (!root.activeOnStack) root.pausedAdapter = null;

    Connections {
        target: BluetoothStatus
        function onAnyDevicePairingOrConnectingChanged() {
            if (!root.activeOnStack)
                return;
            if (BluetoothStatus.anyDevicePairingOrConnecting) {
                const adapter = Bluetooth.defaultAdapter;
                if (adapter && adapter.discovering && !root.pausedAdapter) {
                    root.pausedAdapter = adapter;
                    adapter.discovering = false;
                }
            } else if (root.pausedAdapter) {
                const adapter = root.pausedAdapter;
                root.pausedAdapter = null;
                adapter.discovering = true;
            }
        }
    }

    WPanelPageColumn {
        anchors.fill: parent

        BodyRectangle {
            implicitHeight: 400
            implicitWidth: 50

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                ColumnLayout {
                    implicitHeight: headerRow.implicitHeight
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        HeaderRow {
                            id: headerRow
                            Layout.fillWidth: true
                            title: Translation.tr("Bluetooth")
                        }
                        WSwitch {
                            id: toggleSwitch
                            Layout.rightMargin: 12
                            // `checked` only ever reflects system state here - it must
                            // not drive a handler, or an external enable/disable (rfkill,
                            // another app, BlueZ restart) would replay as if the user
                            // had clicked the switch. Only `onClicked`, which the base
                            // Switch/AbstractButton fires exclusively for real user
                            // interaction, is allowed to touch adapter state.
                            checked: Bluetooth.defaultAdapter?.enabled ?? false
                            onClicked: {
                                const adapter = Bluetooth.defaultAdapter;
                                if (!adapter)
                                    return;
                                const wantEnabled = !adapter.enabled;
                                adapter.enabled = wantEnabled;
                                adapter.discovering = wantEnabled;
                            }
                        }
                    }
                    WText {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        color: Looks.colors.subfg
                        font.pixelSize: Looks.font.pixelSize.small
                        text: {
                            if (!Bluetooth.defaultAdapter)
                                return Translation.tr("No Bluetooth adapter found");
                            if (BluetoothStatus.blocked)
                                return Translation.tr("Blocked (airplane mode / rfkill)");
                            return "";
                        }
                    }
                    FadeLoader {
                        Layout.leftMargin: -4
                        Layout.rightMargin: -4
                        Layout.fillWidth: true
                        shown: Bluetooth.defaultAdapter?.discovering ?? false
                        visible: true
                        sourceComponent: WIndeterminateProgressBar {}
                    }
                }

                StyledListView {
                    id: listView
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    animateAppearance: false

                    contentHeight: contentLayout.implicitHeight
                    contentWidth: width
                    clip: true
                    spacing: 4

                    model: ScriptModel {
                        values: BluetoothStatus.friendlyDeviceList
                    }
                    delegate: BluetoothDeviceItem {
                        required property BluetoothDevice modelData
                        device: modelData
                        width: ListView.view.width
                    }
                }
            }
        }

        WPanelSeparator {}

        FooterRectangle {
            WTextButton {
                anchors {
                    verticalCenter: parent.verticalCenter
                    left: parent.left
                }
                text: Translation.tr("More Bluetooth settings")
                onClicked: {
                    Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "sidebarLeft", "toggle"]);
                    Quickshell.execDetached(["bash", "-c", Config.options.apps.bluetooth]);
                }
            }
            WBorderlessButton {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12
                enabled: !Bluetooth.defaultAdapter?.discovering && Bluetooth.defaultAdapter?.enabled

                onClicked: {
                    const adapter = Bluetooth.defaultAdapter;
                    if (adapter)
                        adapter.discovering = true;
                }

                contentItem: FluentIcon {
                    icon: "arrow-counterclockwise"
                }
            }
        }
    }
}
