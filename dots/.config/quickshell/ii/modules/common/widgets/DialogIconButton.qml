import QtQuick
import qs.modules.common

/**
 * Round icon button for a dialog header — rescan, discovery toggle and the
 * like. Same shape language as the island's queue chips and the bar popups'
 * clear-all button, so a circular icon action reads the same everywhere.
 */
RippleButton {
    id: root

    property string iconName: ""
    property bool toggledOn: false
    // Continuous spin while the action this button started is still running, so
    // the feedback sits where the click happened instead of only in a progress
    // bar somewhere else in the dialog.
    property bool spinning: false

    implicitWidth: 36
    implicitHeight: 36
    buttonRadius: Appearance.rounding.full
    toggled: root.toggledOn

    colBackground: Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.colors.colSecondaryContainerActive
    colBackgroundToggled: Appearance.colors.colPrimary
    colBackgroundToggledHover: Appearance.colors.colPrimaryHover
    colRippleToggled: Appearance.colors.colPrimaryActive

    contentItem: MaterialSymbol {
        id: icon

        property real spinAngle: 0

        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.iconName
        fill: 0
        iconSize: Appearance.font.pixelSize.larger
        color: root.toggledOn ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer

        transform: Rotation {
            origin.x: icon.width / 2
            origin.y: icon.height / 2
            angle: icon.spinAngle
        }

        // Linear loop: an eased spin reads as a stutter rather than as work.
        NumberAnimation {
            target: icon
            property: "spinAngle"
            running: root.spinning
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
            onStopped: icon.spinAngle = 0
        }
    }
}
