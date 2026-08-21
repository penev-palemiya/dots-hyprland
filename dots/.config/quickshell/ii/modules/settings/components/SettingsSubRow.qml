import QtQuick
import qs.modules.common

/**
 * A setting nested under the row above it (e.g. "Language" under "Dictation").
 * Visually it's a SettingsRow with no icon, indented to the parent's text column
 * and with its divider inset to match.
 */
SettingsRow {
    id: root

    property real indent: 34 + 16 // icon column + row spacing, matches SettingsRow

    horizontalPadding: 20 + indent
    dividerInset: 20 + indent
    showTopDivider: true
    minimumHeight: 52
    // Nested rows are usually details of the setting above, and surfacing them
    // as standalone search hits would be more noise than help.
    registerInSearch: false
}
