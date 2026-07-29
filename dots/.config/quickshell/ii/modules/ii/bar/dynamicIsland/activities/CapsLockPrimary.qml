import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

IslandActivityRow {
    id: root
    icon: "keyboard_capslock"

    StyledText {
        id: statusText
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        color: Appearance.colors.colOnLayer1
        text: HyprlandXkb.capsLockOn ? Translation.tr("Caps Lock activated") : Translation.tr("Caps Lock deactivated")
        opacity: 1

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(statusText)
        }

        onTextChanged: {
            opacity = 0;
            textFadeBackTimer.restart();
        }
    }

    Timer {
        id: textFadeBackTimer
        interval: 1
        onTriggered: statusText.opacity = 1
    }
}
