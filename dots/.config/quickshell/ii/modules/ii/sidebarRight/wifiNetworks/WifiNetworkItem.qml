import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.network
import QtQuick
import QtQuick.Layouts

/**
 * One Wi-Fi network, as a card in a grouped list.
 *
 * The strength is spelled out as a number rather than left entirely to the
 * icon: in a list of a dozen networks every row carries the same visual
 * weight, and telling "three bars" from "four bars" at 19px is exactly the
 * kind of thing the eye is bad at.
 */
GroupedListCard {
    id: root

    required property WifiAccessPoint wifiNetwork

    readonly property int strength: root.wifiNetwork?.strength ?? 0
    readonly property bool connected: root.wifiNetwork?.active ?? false
    readonly property bool connecting: Network.wifiConnectTarget === root.wifiNetwork && !root.connected
    readonly property bool askingPassword: root.wifiNetwork?.askingPassword ?? false
    readonly property bool secure: root.wifiNetwork?.isSecure ?? false
    // An active network with no security string is the classic captive-portal
    // shape: joined, but not actually online until you sign in.
    readonly property bool needsPortal: root.connected && (root.wifiNetwork?.security ?? "").trim().length === 0

    selected: root.connected
    expanded: root.askingPassword || root.needsPortal
    interactive: !root.connected

    iconName: root.strength > 80 ? "signal_wifi_4_bar" : root.strength > 60 ? "network_wifi_3_bar" : root.strength > 40 ? "network_wifi_2_bar" : root.strength > 20 ? "network_wifi_1_bar" : "signal_wifi_0_bar"

    title: root.wifiNetwork?.ssid ?? Translation.tr("Unknown")

    subtitle: {
        const parts = [];
        if (root.connecting)
            parts.push(Translation.tr("Connecting…"));
        else if (root.connected)
            parts.push(Translation.tr("Connected"));
        const security = (root.wifiNetwork?.security ?? "").trim();
        if (security.length > 0)
            parts.push(security);
        else if (!root.secure)
            parts.push(Translation.tr("Open"));
        parts.push(`${root.strength}%`);
        return parts.join(" • ");
    }

    // The connected row already says so in colour and text, so its trailing
    // slot carries the confirmation glyph; everything else shows whether a
    // password will be needed.
    trailingIcon: root.connected ? "check_circle" : root.connecting ? "sync" : root.secure ? "lock" : ""

    onClicked: {
        if (!root.connected)
            Network.connectToWifiNetwork(root.wifiNetwork);
    }

    // ---- password prompt ----
    MaterialTextField {
        id: passwordField

        Layout.fillWidth: true
        visible: root.askingPassword
        placeholderText: Translation.tr("Password")
        echoMode: TextInput.Password
        inputMethodHints: Qt.ImhSensitiveData
        onAccepted: Network.changePassword(root.wifiNetwork, passwordField.text)
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.askingPassword
        spacing: 8

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Cancel")
            onClicked: root.wifiNetwork.askingPassword = false
        }

        DialogButton {
            buttonText: Translation.tr("Connect")
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            colText: Appearance.colors.colOnPrimary
            onClicked: Network.changePassword(root.wifiNetwork, passwordField.text)
        }
    }

    // ---- captive portal ----
    DialogButton {
        Layout.fillWidth: true
        visible: root.needsPortal
        buttonText: Translation.tr("Open network portal")
        colBackground: Appearance.colors.colPrimary
        colBackgroundHover: Appearance.colors.colPrimaryHover
        colRipple: Appearance.colors.colPrimaryActive
        colText: Appearance.colors.colOnPrimary
        onClicked: {
            Network.openPublicWifiPortal();
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
