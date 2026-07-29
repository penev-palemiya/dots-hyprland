import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

IslandActivityRow {
    id: root
    icon: "keyboard_capslock"

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        color: Appearance.colors.colOnLayer1
        text: HyprlandXkb.capsLockOn ? Translation.tr("Caps Lock activated") : Translation.tr("Caps Lock deactivated")
    }
}
