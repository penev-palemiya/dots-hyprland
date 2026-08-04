import qs
import qs.services
import qs.services.network
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * Wi-Fi picker, as grouped sections rather than one undifferentiated list.
 *
 * `Network.friendlyWifiNetworks` already sorts the active network first and
 * the rest by strength — but sorting alone doesn't communicate anything: the
 * connected network used to look identical to every other row apart from a
 * small check glyph. Splitting it into its own section is the same finding as
 * with notifications and Bluetooth: the grouping existed in the data and was
 * being thrown away by the view.
 */
WindowDialog {
    id: root

    backgroundHeight: 600

    readonly property var connectedNetwork: Network.active
    readonly property var otherNetworks: Network.friendlyWifiNetworks.filter(n => n !== Network.active)

    WindowDialogTitle {
        text: Translation.tr("Connect to Wi-Fi")
    }

    WindowDialogSeparator {
        visible: !Network.wifiScanning
    }

    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    StyledFlickable {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: 4
        Layout.bottomMargin: -8
        clip: true
        contentHeight: networkColumn.implicitHeight

        ColumnLayout {
            id: networkColumn

            width: parent.width
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.connectedNetwork !== null
                spacing: 6

                ListSectionLabel {
                    text: Translation.tr("Connected")
                }

                WifiNetworkItem {
                    Layout.fillWidth: true
                    visible: root.connectedNetwork !== null
                    wifiNetwork: root.connectedNetwork
                    indexInSection: 0
                    sectionCount: 1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.otherNetworks.length > 0
                spacing: 6

                ListSectionLabel {
                    text: Translation.tr("Available networks")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ScriptModel {
                            values: root.otherNetworks
                        }

                        delegate: WifiNetworkItem {
                            required property WifiAccessPoint modelData
                            required property int index

                            Layout.fillWidth: true
                            wifiNetwork: modelData
                            indexInSection: index
                            sectionCount: root.otherNetworks.length
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 20
                horizontalAlignment: Text.AlignHCenter
                visible: root.connectedNetwork === null && root.otherNetworks.length === 0
                text: Network.wifiScanning ? Translation.tr("Scanning…") : Translation.tr("No networks found")
                color: Appearance.colors.colOutline
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Details")
            onClicked: {
                Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
                GlobalStates.sidebarRightOpen = false;
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
