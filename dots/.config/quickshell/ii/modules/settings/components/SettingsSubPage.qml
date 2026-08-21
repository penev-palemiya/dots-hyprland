import QtQuick
import QtQuick.Layouts

/**
 * Content of one SettingsPage detail view. SettingsSearch reads its key/title
 * while walking a row's parents, so search can open the right detail view.
 */
ColumnLayout {
    id: root

    property string settingsSubPageKey: ""
    property string settingsSubPageTitle: ""

    Layout.fillWidth: true
    spacing: 28
}
