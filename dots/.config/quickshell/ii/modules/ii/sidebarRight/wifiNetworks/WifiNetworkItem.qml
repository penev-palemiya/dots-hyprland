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
    // Not `wifiNetwork.active`: that flag comes from the cached scan and lags a
    // roam. `Network.active` is resolved from the device's own connection.
    readonly property bool connected: root.wifiNetwork !== null && Network.active === root.wifiNetwork
    readonly property bool connecting: Network.wifiConnectTarget === root.wifiNetwork && !root.connected
    readonly property bool askingPassword: root.wifiNetwork?.askingPassword ?? false
    readonly property bool secure: root.wifiNetwork?.isSecure ?? false
    // Has a saved connection profile, i.e. joining it shouldn't need a password.
    // The dialog groups by this, so the row only uses it for the trailing glyph.
    readonly property bool saved: Network.isKnownNetwork(root.wifiNetwork?.ssid ?? "")
    // An active network with no security string is the classic captive-portal
    // shape: joined, but not actually online until you sign in.
    readonly property bool needsPortal: root.connected && (root.wifiNetwork?.security ?? "").trim().length === 0

    // Forgetting drops a stored password, so it asks first — and asks inside the
    // row, where the network's name is still visible, rather than in a separate
    // dialog that would have to repeat it.
    property bool confirmingForget: false

    selected: root.connected
    expanded: root.askingPassword || root.needsPortal || root.confirmingForget
    interactive: !root.connected

    actionIcon: root.saved && !root.askingPassword ? "delete" : ""
    onActionClicked: root.confirmingForget = !root.confirmingForget

    // A row that scrolls out of view and comes back, or one whose network drops
    // off the scan, must not come back mid-confirmation.
    onSavedChanged: if (!root.saved) root.confirmingForget = false;
    onAskingPasswordChanged: if (root.askingPassword) root.confirmingForget = false;

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
    // password will be needed — which a saved network's won't, so it gets no
    // lock even though it is secured.
    trailingIcon: root.connected ? "check_circle" : root.connecting ? "sync" : (root.secure && !root.saved) ? "lock" : ""
    trailingSpinning: root.connecting

    onClicked: {
        if (!root.connected)
            Network.connectToWifiNetwork(root.wifiNetwork);
    }

    // A row that appears on its own — a network coming into range, or one that
    // moved between the saved and other sections after being forgotten — arrives
    // rather than blinks into place. `staggered` is set by the dialog while its
    // own cascade is running, which already animates these rows; playing both
    // would double the fade.
    property bool staggered: false

    Component.onCompleted: if (!root.staggered) enterAnimation.start();

    ParallelAnimation {
        id: enterAnimation

        running: false

        // Spatial, small and local, so the fast spring per docs/design/motion.md.
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

    // ---- forget confirmation ----
    StyledText {
        Layout.fillWidth: true
        visible: root.confirmingForget
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: Translation.tr("Forget this network? Its saved password will be removed.")
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
            onClicked: {
                root.confirmingForget = false;
                Network.forgetWifiNetwork(root.wifiNetwork.ssid);
            }
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
