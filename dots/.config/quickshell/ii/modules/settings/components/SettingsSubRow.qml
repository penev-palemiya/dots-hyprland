import QtQuick
import qs.modules.common

/**
 * A setting nested under the row above it (e.g. "Language" under "Dictation").
 * Visually it's a SettingsRow with no icon, indented to line up with the text
 * column above it. It still gets its own rounded/gapped block from
 * SettingsCard like any other row in the section - the indent alone reads as
 * "belongs to the row above".
 */
SettingsRow {
    id: root

    property real indent: 34 + 16 // icon column + row spacing, matches SettingsRow

    horizontalPadding: 20 + indent
    minimumHeight: 52
    // Nested rows are usually details of the setting above, and surfacing them
    // as standalone search hits would be more noise than help.
    registerInSearch: false
}
