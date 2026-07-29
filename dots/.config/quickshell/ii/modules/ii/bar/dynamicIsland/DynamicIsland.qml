import qs.modules.common
import QtQuick

/**
 * A fixed-size pill that hosts one "activity" at a time, picked from an
 * ordered list by priority (first available wins). Media is the permanent
 * fallback activity — it always reports available and has its own "No
 * media" empty state, so the island never shows nothing. Future activities
 * (a running timer, a call-style alert, ...) get prepended to `activities`
 * with their own `available` condition and will transparently take over
 * the island while active, falling back to media once they're not.
 *
 * The island's size never changes between activities — only its content.
 */
Rectangle {
    id: root

    radius: Appearance.rounding.small
    color: Config.options?.bar.borderless ? "transparent" : Appearance.colors.colLayer1
    implicitHeight: Appearance.sizes.baseBarHeight

    QtObject {
        id: mediaActivity
        readonly property bool available: true
        readonly property Component content: mediaActivityComponent
    }

    readonly property list<QtObject> activities: [mediaActivity]
    readonly property QtObject activeActivity: activities.find(a => a.available) ?? null

    Loader {
        anchors.fill: parent
        sourceComponent: root.activeActivity?.content ?? null
    }

    Component {
        id: mediaActivityComponent
        MediaActivity {}
    }
}
