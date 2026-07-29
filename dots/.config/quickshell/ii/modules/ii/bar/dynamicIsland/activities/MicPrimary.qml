import qs.modules.common
import qs.services
import QtQuick

StateTransitionPrimary {
    id: root

    readonly property bool micMuted: Audio.source && Audio.source.audio ? Audio.source.audio.muted : false

    active: !micMuted
    activeIcon: "mic"
    inactiveIcon: "mic_off"
    activeText: Translation.tr("Microphone unmuted")
    inactiveText: Translation.tr("Microphone muted")
    inactiveIconColor: Appearance.colors.colError

    MouseArea {
        anchors.fill: parent
        onClicked: Audio.toggleMicMute()
    }
}
