import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * A titled group of settings: a label, then a card of rows.
 * Publishes settingsSectionTitle so rows inside can pick it up for search
 * results without being told which section they're in.
 */
ColumnLayout {
    id: root

    property string title: ""
    property string settingsSectionTitle: root.title
    default property alias cardContent: card.contentData

    Layout.fillWidth: true
    spacing: 10

    StyledText {
        Layout.fillWidth: true
        Layout.minimumWidth: 1
        Layout.preferredWidth: 1
        Layout.leftMargin: 4
        visible: root.title.length > 0
        text: root.title
        font.pixelSize: Appearance.font.pixelSize.large
        font.weight: Font.Medium
        color: Appearance.colors.colOnSurfaceVariant
    }

    SettingsCard {
        id: card
        Layout.fillWidth: true
    }
}
