import QtQuick
import qs.modules.common

/**
 * Quiet label above a group of GroupedListCards ("Connected", "Available").
 *
 * Deliberately much lighter than WindowDialogSectionHeader, which is a 22px
 * title face: this labels a group *inside* a list, so it has to stay clearly
 * subordinate to the dialog's own title or the hierarchy inverts.
 */
StyledText {
    font {
        pixelSize: Appearance.font.pixelSize.smaller
        weight: Font.Medium
    }
    color: Appearance.colors.colOutline
}
