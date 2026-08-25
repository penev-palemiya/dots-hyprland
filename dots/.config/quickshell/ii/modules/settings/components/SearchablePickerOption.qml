import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    property string primaryText: ""
    property string secondaryText: ""
    property string iconText: ""
    property bool selected: false
    property bool keyboardCurrent: false

    implicitHeight: root.secondaryText.length > 0 ? 54 : 40
    leftPadding: 12
    rightPadding: 12
    spacing: 8
    activeFocusOnTab: true
    toggled: root.selected
    opacity: enabled ? 1 : 0.38
    buttonRadius: Appearance.rounding.small
    colBackground: root.keyboardCurrent
        ? Appearance.colors.colSurfaceContainerHighestHover
        : Appearance.colors.colSurfaceContainerHighest
    colBackgroundHover: Appearance.colors.colSurfaceContainerHighestHover
    colBackgroundToggled: root.keyboardCurrent
        ? Appearance.colors.colSecondaryContainerHover
        : Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRipple: Appearance.colors.colOnSurface
    colRippleToggled: Appearance.colors.colOnSecondaryContainer
    Accessible.name: root.primaryText + (root.selected ? ", " + Translation.tr("Selected") : "")

    contentItem: RowLayout {
        spacing: root.spacing

        MaterialSymbol {
            visible: root.iconText.length > 0
            text: root.iconText
            iconSize: Appearance.font.pixelSize.larger
            color: root.selected
                ? Appearance.colors.colOnSecondaryContainer
                : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.primaryText
                color: root.selected
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurface
                elide: Text.ElideRight
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.secondaryText.length > 0
                text: root.secondaryText
                color: root.selected
                    ? Appearance.colors.colOnSecondaryContainer
                    : Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        MaterialSymbol {
            visible: root.selected
            text: "check"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colPrimary
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 1
        visible: root.activeFocus
        radius: root.buttonRadius
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
    }
}
