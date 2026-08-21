import QtQuick
import qs.modules.common
import qs.modules.common.widgets

/**
 * A SettingsRow whose trailing control is a switch. The whole row is clickable,
 * which is a much larger hit target than the switch itself.
 */
SettingsRow {
    id: root

    property bool checked: false
    signal toggled(bool checked)

    clickable: true
    onClicked: root.toggled(!root.checked)

    StyledSwitch {
        id: switchWidget
        checked: root.checked
        enabled: root.enabled
        // The row's MouseArea already covers this; let it handle the click so
        // both paths behave identically instead of double-toggling.
        onClicked: {
            checked = Qt.binding(() => root.checked);
            root.toggled(!root.checked);
        }
    }
}
