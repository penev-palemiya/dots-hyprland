import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root
    readonly property bool hotCornersEnabled: Config.options.sidebar.cornerOpen.enable
    readonly property bool bottomEnabled: Config.options.sidebar.cornerOpen.bottom

    SettingsGroup {
        title: Translation.tr("HOT CORNERS")
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 170
            radius: Appearance.rounding.normal
            color: Appearance.colors.colSurfaceContainerHighest
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            opacity: root.hotCornersEnabled ? 1 : 0.45

            StyledText { anchors.top: parent.top; anchors.left: parent.left; anchors.topMargin: 18; anchors.leftMargin: 22; text: Translation.tr("Left sidebar"); color: Appearance.colors.colOnSurface }
            StyledText { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 18; anchors.rightMargin: 22; text: Translation.tr("Right sidebar"); color: Appearance.colors.colOnSurface }
            StyledText { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.bottomMargin: 18; anchors.leftMargin: 22; text: Translation.tr("Left sidebar"); color: Appearance.colors.colOnSurfaceVariant; opacity: root.bottomEnabled ? 1 : 0.45 }
            StyledText { anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.bottomMargin: 18; anchors.rightMargin: 22; text: Translation.tr("Right sidebar"); color: Appearance.colors.colOnSurfaceVariant; opacity: root.bottomEnabled ? 1 : 0.45 }
            Rectangle { anchors.centerIn: parent; width: parent.width - 110; height: 1; color: Appearance.colors.colOutlineVariant }
            Rectangle { anchors.centerIn: parent; width: 1; height: parent.height - 64; color: Appearance.colors.colOutlineVariant }
        }
    }

    SettingsGroup {
        title: Translation.tr("ACTIVATION")
        SettingsToggleRow {
            icon: "check"
            title: Translation.tr("Enable hot corners")
            description: Translation.tr("Enable the existing corner regions that open the sidebars.")
            checked: root.hotCornersEnabled
            onToggled: checked => Config.options.sidebar.cornerOpen.enable = checked
        }
        SettingsToggleRow {
            icon: "highlight_mouse_cursor"
            title: Translation.tr("Activate on hover")
            description: Translation.tr("Entering an active corner can open its sidebar without clicking.")
            enabled: root.hotCornersEnabled
            checked: Config.options.sidebar.cornerOpen.clickless
            onToggled: checked => Config.options.sidebar.cornerOpen.clickless = checked
        }
        SettingsToggleRow {
            icon: "gps_fixed"
            title: Translation.tr("Activate at exact corner")
            description: Translation.tr("Trigger when the pointer reaches the very corner of the screen.")
            enabled: root.hotCornersEnabled && !Config.options.sidebar.cornerOpen.clickless
            checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
            onToggled: checked => Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked
        }
        SettingsToggleRow {
            icon: "vertical_align_bottom"
            title: Translation.tr("Enable bottom corners")
            description: Translation.tr("Also enable bottom-left and bottom-right sidebar triggers.")
            enabled: root.hotCornersEnabled
            checked: Config.options.sidebar.cornerOpen.bottom
            onToggled: checked => Config.options.sidebar.cornerOpen.bottom = checked
        }
    }

    SettingsGroup {
        title: Translation.tr("INTERACTION")
        SettingsToggleRow {
            icon: "unfold_more_double"
            title: Translation.tr("Adjust brightness and volume")
            description: Translation.tr("Scroll on left corners for brightness and right corners for volume.")
            enabled: root.hotCornersEnabled
            checked: Config.options.sidebar.cornerOpen.valueScroll
            onToggled: checked => Config.options.sidebar.cornerOpen.valueScroll = checked
        }
    }
}
