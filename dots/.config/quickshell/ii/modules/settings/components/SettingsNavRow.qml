import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * A grouped-list row that opens a detail sub-page. The optional trailing hint
 * shows a compact current value without competing with the row description.
 */
SettingsRow {
    id: root

    property string trailingHint: ""

    clickable: true

    RowLayout {
        spacing: 6

        StyledText {
            visible: root.trailingHint.length > 0
            text: root.trailingHint
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
        }

        MaterialSymbol {
            text: "chevron_right"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}
