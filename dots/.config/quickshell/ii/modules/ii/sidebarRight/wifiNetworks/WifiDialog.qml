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

    readonly property var connectedNetwork: Network.active
    readonly property var otherNetworks: Network.friendlyWifiNetworks.filter(n => n !== Network.active)
    readonly property real maxListHeight: 380


    WindowDialogHeader {
        id: header

        title: Translation.tr("Wi-Fi")
        subtitle: Network.wifiScanning ? Translation.tr("Scanning…") : root.otherNetworks.length > 0 ? Translation.tr("%1 nearby").arg(root.otherNetworks.length) : Translation.tr("No networks found")

        DialogIconButton {
            iconName: "refresh"
            enabled: !Network.wifiScanning
            onClicked: Network.rescanWifi()
        }
    }

    // Hairline progress under the header, full-bleed to the dialog edges.
    StyledIndeterminateProgressBar {
        visible: Network.wifiScanning
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
        implicitHeight: Math.min(root.maxListHeight, networkColumn.implicitHeight)

        StyledFlickable {
            id: flickable

            anchors.fill: parent
            clip: true
            contentHeight: networkColumn.implicitHeight

            ColumnLayout {
                id: networkColumn

                width: flickable.width
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
                Quickshell.execDetached(["bash", "-c", `${Network.ethernet ? Config.options.apps.networkEthernet : Config.options.apps.network}`]);
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
