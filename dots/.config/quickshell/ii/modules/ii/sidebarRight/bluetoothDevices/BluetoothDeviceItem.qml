import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * One Bluetooth device, as a card in a grouped list. Tapping expands the row
 * into its actions rather than acting immediately — connecting and forgetting
 * are both things you want to aim at deliberately.
 */
GroupedListCard {
    id: root

    required property var device

    readonly property bool connected: root.device?.connected ?? false
    readonly property bool paired: root.device?.paired ?? false
    readonly property bool batteryKnown: root.device?.batteryAvailable ?? false
    readonly property int batteryPercent: Math.round((root.device?.battery ?? 0) * 100)
    // Worth flagging before the headphones die mid-call.
    readonly property bool batteryLow: root.batteryKnown && root.batteryPercent <= 20

    selected: root.connected

    iconName: Icons.getBluetoothDeviceMaterialSymbol(root.device?.icon || "")
    title: root.device?.name || Translation.tr("Unknown device")

    subtitle: {
        const parts = [];
        if (root.connected)
            parts.push(Translation.tr("Connected"));
        else if (root.paired)
            parts.push(Translation.tr("Saved"));
        if (root.batteryKnown)
            parts.push(`${root.batteryPercent}%`);
        return parts.join(" • ");
    }

    trailingIcon: "keyboard_arrow_down"
    trailingRotated: root.expanded

    onClicked: root.expanded = !root.expanded

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        // Battery gets a real bar once it's actually known — a percentage in
        // small grey text is easy to miss on the one device that's about to
        // run out.
        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            visible: root.batteryKnown
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

        Item {
            Layout.fillWidth: !root.batteryKnown
        }

        // "Forget" is destructive but secondary, so it stays a quiet button
        // with error-coloured text rather than a filled red slab — a solid
        // errorContainer fill measured fine for contrast (7.24) but visually
        // dominated the whole card for an action you rarely take.
        DialogButton {
            buttonText: root.paired ? Translation.tr("Forget") : Translation.tr("Always connect")
            colBackground: ColorUtils.transparentize(Appearance.colors.colSecondaryContainer, 1)
            colBackgroundHover: Appearance.colors.colSecondaryContainerHover
            colRipple: Appearance.colors.colSecondaryContainerActive
            colText: root.paired ? Appearance.colors.colError : Appearance.colors.colOnSurfaceVariant
            onClicked: {
                if (root.paired)
                    root.device?.forget();
                else
                    root.device?.pair();
            }
        }

        DialogButton {
            buttonText: root.connected ? Translation.tr("Disconnect") : Translation.tr("Connect")
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            colRipple: Appearance.colors.colPrimaryActive
            colText: Appearance.colors.colOnPrimary
            onClicked: {
                if (root.connected)
                    root.device.disconnect();
                else
                    root.device.connect();
            }
        }
    }
}
