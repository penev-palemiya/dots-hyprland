import qs.modules.common
import qs.services
import QtQuick

StateTransitionPrimary {
    id: root

    readonly property bool capsLockOn: HyprlandXkb.capsLockOn

    active: capsLockOn
    activeIcon: "keyboard_capslock"
    inactiveIcon: "keyboard"
    activeText: Translation.tr("Caps Lock activated")
    inactiveText: Translation.tr("Caps Lock deactivated")
}
