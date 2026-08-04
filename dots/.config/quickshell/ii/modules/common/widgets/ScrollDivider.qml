import QtQuick
import QtQuick.Layouts
import qs.modules.common

/**
 * Divider marking a scroll boundary in a dialog: shown only while there is
 * actually content past that edge, faded in and out.
 *
 * This is the Material 3 answer for scrollable dialog content, and it replaces
 * a gradient scrim that was tried first — a fade-to-background works in flat
 * design languages but is not how M3 signals "more content this way"; M3 uses
 * a divider (or a tonal shift on the surface above it), never a soft mask over
 * the content itself.
 *
 * `colOutlineVariant` measures 1.54:1 against the dialog surface, against 4.51
 * for the `colOutline` used by WindowDialogSeparator. That is deliberate: an
 * always-visible 4.5:1 hairline reads as a hard rule cutting the dialog in
 * two, which is exactly what made these dialogs feel dated. A boundary hint
 * only has to be perceptible, not legible.
 */
Rectangle {
    id: root

    required property Flickable target
    property bool atStart: true

    Layout.fillWidth: true
    // Full-bleed to the dialog's edges, like the M3 spec's dialog dividers.
    Layout.leftMargin: -parent.parent?.contentPadding ?? 0
    Layout.rightMargin: -parent.parent?.contentPadding ?? 0
    Layout.topMargin: -8
    Layout.bottomMargin: -8

    implicitHeight: 1
    color: Appearance.colors.colOutlineVariant
    opacity: root.atStart ? (root.target.atYBeginning ? 0 : 1) : (root.target.atYEnd ? 0 : 1)

    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }
}
