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
    // Three tiers rather than two: a network we already have a profile for is one
    // click away, an unknown one costs a password. That difference decides which
    // row you actually want when you walk into range of a dozen of them, so it
    // gets to be structure instead of a badge buried in a subtitle.
    // Display order, snapshotted rather than live. `friendlyWifiNetworks` sorts
    // by strength, so every scan that lands reshuffles the rows — click "Forget"
    // on one network and a signal fluctuation can slide a different one under the
    // pointer first. Positions are kept for networks already on screen,
    // newcomers are appended, and the strength sort is only re-applied when the
    // dialog opens or the user asks for a refresh.
    property var networkOrder: []

    // Filtered through the live list so a network that disappeared (or an object
    // the service destroyed) can never be read out of the snapshot.
    readonly property var rest: {
        const live = Network.friendlyWifiNetworks;
        return root.networkOrder.filter(n => live.includes(n) && n !== Network.active);
    }
    readonly property var savedNetworks: root.rest.filter(n => Network.isKnownNetwork(n.ssid))
    readonly property var otherNetworks: root.rest.filter(n => !Network.isKnownNetwork(n.ssid))
    readonly property real maxListHeight: 380

    // The dialog is vertically centred, so any content change moves the footer
    // buttons by half the delta — a scan landing mid-click used to pull the
    // button out from under the pointer. While the dialog is open the list keeps
    // the tallest height it has needed, so it grows once on open and then holds
    // still; the cap means a full list is stable from the first frame.
    property real listHeight: 0
    readonly property real listContentHeight: Math.min(root.maxListHeight, networkColumn.implicitHeight)
    onListContentHeightChanged: root.listHeight = Math.max(root.listHeight, root.listContentHeight)

    // Cascade lives in WindowDialog; this dialog only declares its steps:
    // header, connected, saved, other, footer.
    staggerContent: true
    revealSections: 5

    function resortNetworks(): void {
        root.networkOrder = Network.friendlyWifiNetworks.slice();
    }

    function reconcileNetworks(): void {
        const live = Network.friendlyWifiNetworks;
        const kept = root.networkOrder.filter(n => live.includes(n));
        root.networkOrder = kept.concat(live.filter(n => !kept.includes(n)));
    }

    Connections {
        target: Network

        function onFriendlyWifiNetworksChanged() {
            root.reconcileNetworks();
        }
    }

    // Not an `onShowChanged` handler: WindowDialog declares one of its own (it
    // drives the cascade), and a handler in a derived type would take its place.
    Connections {
        target: root

        function onShowChanged() {
            if (!root.show)
                return;
            // Re-measure rather than zero it: if the content is the same height
            // as last time, the change signal wouldn't fire and the list would
            // open at nothing.
            root.listHeight = root.listContentHeight;
            root.resortNetworks();
        }
    }

    Component.onCompleted: root.resortNetworks()


    // Walking around the house means the list is already out of date by the time
    // the dialog opens, and a scan takes seconds to land. Keep pulling
    // NetworkManager's cached list while the dialog is on screen — it's cheap,
    // and the scan behind it is rate-limited inside the service.
    Timer {
        running: root.show
        interval: 2500
        repeat: true
        onTriggered: Network.rescanWifi()
    }

    WindowDialogHeader {
        id: header

        opacity: root.sectionOpacity(0)
        transform: Translate {
            y: root.sectionOffset(0)
        }

        title: Translation.tr("Wi-Fi")
        subtitle: Network.wifiScanning ? Translation.tr("Scanning…") : root.rest.length > 0 ? Translation.tr("%1 nearby").arg(root.rest.length) : Translation.tr("No networks found")

        DialogIconButton {
            iconName: "refresh"
            enabled: !Network.wifiScanning
            spinning: Network.wifiScanning
            onClicked: {
                // An explicit refresh is the one moment reordering is expected —
                // the user asked for a fresh picture.
                Network.rescanWifi(true); // and it skips the scan cooldown
                root.resortNetworks();
            }
        }
    }

    // Hairline progress under the header, full-bleed to the dialog edges. It
    // keeps its space at all times and only fades: toggling `visible` relaid the
    // dialog out the instant a scan began, which is the jump you feel most
    // because it happens exactly when you reach for the refresh button.
    StyledIndeterminateProgressBar {
        Layout.fillWidth: true
        Layout.topMargin: -10
        Layout.bottomMargin: -10
        Layout.leftMargin: -root.contentPadding
        Layout.rightMargin: -root.contentPadding

        // Part of the header block as far as the cascade is concerned.
        opacity: root.sectionOpacity(0) * (Network.wifiScanning ? 1 : 0)
        // No point animating a bar nobody can see.
        indeterminate: Network.wifiScanning

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
        implicitHeight: root.listHeight

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

                    opacity: root.sectionOpacity(1)
                    transform: Translate {
                        y: root.sectionOffset(1)
                    }

                    ListSectionLabel {
                        text: Translation.tr("Connected")
                    }

                    WifiNetworkItem {
                        Layout.fillWidth: true
                        visible: root.connectedNetwork !== null
                        wifiNetwork: root.connectedNetwork
                        indexInSection: 0
                        sectionCount: 1
                        staggered: root.revealing
                    }
                }

                NetworkSection {
                    label: Translation.tr("Saved networks")
                    networks: root.savedNetworks
                    revealIndex: 2
                }

                NetworkSection {
                    label: Translation.tr("Other networks")
                    networks: root.otherNetworks
                    revealIndex: 3
                }
            }
        }

    }

    ScrollDivider {
        target: flickable
        atStart: false
        revealOpacity: root.sectionOpacity(3)
    }

    component NetworkSection: ColumnLayout {
        id: section

        required property string label
        required property var networks
        required property int revealIndex

        Layout.fillWidth: true
        visible: section.networks.length > 0
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
                    values: section.networks
                }

                delegate: WifiNetworkItem {
                    required property WifiAccessPoint modelData
                    required property int index

                    Layout.fillWidth: true
                    wifiNetwork: modelData
                    indexInSection: index
                    sectionCount: section.networks.length
                    staggered: root.revealing
                }
            }
        }
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
