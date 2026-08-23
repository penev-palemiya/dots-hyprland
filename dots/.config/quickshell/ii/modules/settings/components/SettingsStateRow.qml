import QtQuick
import qs.modules.common

SettingsRow {
    id: root

    property string statusState: ""
    property string stateTitle: ""
    property string stateDescription: ""
    property string stateIcon: ""

    readonly property string resolvedIcon: root.stateIcon.length > 0 ? root.stateIcon
        : root.statusState === "loading" ? "hourglass_top"
        : root.statusState === "empty" ? "info"
        : root.statusState === "no-results" ? "search_off"
        : root.statusState === "unavailable" ? "block"
        : root.statusState === "disabled" ? "block"
        : root.statusState === "unsupported" ? "help_outline"
        : root.statusState === "error" ? "error_outline" : "info"

    icon: root.resolvedIcon
    title: root.stateTitle
    description: root.stateDescription
    enabled: root.statusState !== "disabled"
    registerInSearch: false
}
