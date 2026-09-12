import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A plain list of actions, not the app's SysTrayMenu.qml (which is a
// PopupWindow driven by a QsMenuHandle - a system tray menu handle, which
// nothing here has). This is the file explorer's own right-click menu: open/
// copy/cut/paste/rename/delete on a file, or navigate/copy-path/paste-into on
// a breadcrumb segment. Both call sites build their own `actions` list and
// share this one popup shell.
//
// Anatomy and states follow MD3's menu spec: fixed-width leading icon
// column so labels align across rows regardless of which rows have icons,
// a trailing slot for a shortcut/chevron/badge, a state-layer hover (8%
// mix)/press (12% mix) rather than a flat hover color, and a bordered
// (not filled) indicator for the currently-selected row - see
// FileExplorerDirectoryItem's own selection styling for why filled would be
// wrong here: this is "which row will Enter/click activate", not "which
// file is multi-selected", and MD3 draws those two kinds of state
// differently on purpose.
Popup {
    id: root

    // List of one of:
    //   { separator: true }
    //   { text, icon (optional), shortcut (optional), badge (optional),
    //     hasSubmenu (optional), selected (optional), enabled (optional,
    //     default true), onTriggered }
    // A plain JS array rather than a model type of its own - the call sites
    // (file entries, breadcrumb segments, empty-space actions) have
    // different actions with nothing structural in common beyond "a list of
    // rows", so a dedicated model would be pure ceremony.
    property var actions: []

    readonly property real rowHeight: 36
    readonly property real iconColumnWidth: 20
    readonly property real rowHorizontalPadding: 12
    readonly property real menuPadding: 4

    padding: root.menuPadding
    margins: 0
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    function openAt(x, y, forItem) {
        root.parent = forItem;
        root.x = x;
        root.y = y;
        root.open();
    }

    // MD3 Enter & Exit for a transient overlay: scale in from near-full-size
    // (never a dramatic zoom - a menu is not a hero moment) on
    // elementMoveEnter (emphasizedDecel), fade out faster on elementMoveExit
    // (emphasizedAccel) - the same asymmetry used for the Overview and the
    // dynamic island, where "enter can take its time, exit should get out of
    // the way quickly" is the standing rule (see docs/design/motion.md).
    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            NumberAnimation {
                property: "scale"
                from: 0.85
                to: 1
                duration: Appearance.animation.elementMoveEnter.duration
                easing.type: Appearance.animation.elementMoveEnter.type
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
            NumberAnimation {
                property: "scale"
                from: 1
                to: 0.9
                duration: Appearance.animation.elementMoveExit.duration
                easing.type: Appearance.animation.elementMoveExit.type
                easing.bezierCurve: Appearance.animation.elementMoveExit.bezierCurve
            }
        }
    }
    // Grows from the corner nearest the click, not the popup's geometric
    // center: openAt() places (x, y) at whichever corner the caller's
    // right-click landed on, so scaling from the top-left is what makes the
    // menu appear to originate from the pointer rather than swelling out
    // from its own middle.
    transformOrigin: Item.TopLeft

    // m3colors.* (raw opaque), not colors.col* (composited/transparentized
    // for glass-over-wallpaper surfaces) - this is a floating layer-shell/
    // window popup, not something meant to look like frosted glass over the
    // wallpaper, so it needs a genuinely solid background.
    background: Item {
        // The shadow is a sibling of the filled Rectangle, not something
        // drawn ON it (StyledRectangularShadow anchors.fill: target and
        // paints around/behind it) - matching every other floating surface
        // in the shell (StyledPopup, the dynamic island): a right-click
        // menu sits above the window's normal content and needs the same
        // raised-above-it cue.
        StyledRectangularShadow {
            target: menuBackground
        }
        Rectangle {
            id: menuBackground
            anchors.fill: parent
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.normal
        }
    }

    contentItem: ColumnLayout {
        spacing: 0
        Repeater {
            model: root.actions
            delegate: Loader {
                id: rowLoader
                required property var modelData
                Layout.fillWidth: true
                sourceComponent: modelData.separator ? separatorComponent : actionComponent
                // sourceComponent items don't inherit the Loader's own
                // properties - actionComponent's RippleButton declares its
                // own `required property var modelData`, so it has to be
                // forwarded explicitly once the item exists. separatorComponent
                // has no such property (a divider has no action data).
                onLoaded: {
                    if (!modelData.separator)
                        item.modelData = rowLoader.modelData;
                }
            }
        }
    }

    Component {
        id: separatorComponent
        // 1px hairline with vertical breathing room, not flush against the
        // rows above/below - matches the reference anatomy's divider, which
        // reads as a group boundary rather than just another (empty) row.
        Rectangle {
            implicitHeight: 1
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            color: Appearance.m3colors.m3outlineVariant
        }
    }

    Component {
        id: actionComponent
        RippleButton {
            id: actionButton
            // Not `required`: this component is instantiated via
            // Loader.sourceComponent (see rowLoader above), which does not
            // forward the Loader's own modelData automatically - the
            // Loader's onLoaded assigns this after construction instead, so
            // a required property here would fail before that can happen.
            property var modelData: ({})
            Layout.fillWidth: true
            enabled: modelData.enabled ?? true
            buttonRadius: Appearance.rounding.normal - root.menuPadding
            pointingHandCursor: true

            implicitWidth: rowLayout.implicitWidth + leftPadding + rightPadding
            implicitHeight: root.rowHeight
            leftPadding: root.rowHorizontalPadding
            rightPadding: root.rowHorizontalPadding

            // RippleButton's own colBackground/colBackgroundHover already
            // give a flat-fill hover; a menu row wants MD3's lighter
            // state-layer treatment instead - a translucent mix into the
            // surface rather than a solid block - and a bordered rather
            // than filled indicator for "selected" (the currently
            // highlighted/keyboard-focused row), which is a different
            // state from hover and needs to read differently even while
            // both could be true (hovering the selected row).
            colBackground: "transparent"
            colBackgroundHover: ColorUtils.mix(Appearance.m3colors.m3surfaceContainer, Appearance.m3colors.m3onSurface, 0.92)
            colRipple: ColorUtils.mix(Appearance.m3colors.m3surfaceContainer, Appearance.m3colors.m3onSurface, 0.88)

            // No anchors.fill here - Control (RippleButton's base) already
            // positions contentItem within its own padding box via
            // leftPadding/rightPadding above, the same as MenuButton's own
            // default contentItem does. Anchoring this to `parent` a second
            // time fights that instead of matching it.
            contentItem: RowLayout {
                id: rowLayout
                spacing: 10

                // Fixed-width icon column: a row with no icon still reserves
                // the space, so its label lines up with icon rows above/
                // below it instead of starting further left - the anatomy
                // reference shows every row's label at the same x regardless
                // of whether that row has a leading icon.
                Item {
                    Layout.preferredWidth: root.iconColumnWidth
                    Layout.preferredHeight: root.iconColumnWidth
                    visible: actionButton.modelData.icon !== undefined
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: actionButton.modelData.icon ?? ""
                        iconSize: Appearance.font.pixelSize.larger
                        color: actionButton.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: actionButton.modelData.text
                    color: actionButton.enabled ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3outline
                }

                // Trailing slot: badge, shortcut, and submenu chevron are
                // mutually exclusive per the reference anatomy (each row
                // shows at most one), so a single Loader picks whichever
                // the action data provides rather than three separately
                // visibility-toggled items competing for the same space.
                Loader {
                    active: actionButton.modelData.badge !== undefined
                    sourceComponent: Rectangle {
                        color: Appearance.colors.colSecondaryContainer
                        radius: Appearance.rounding.full
                        implicitWidth: badgeLabel.implicitWidth + 12
                        implicitHeight: 20
                        StyledText {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: actionButton.modelData.badge ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
                Loader {
                    active: actionButton.modelData.badge === undefined && actionButton.modelData.shortcut !== undefined
                    sourceComponent: StyledText {
                        text: actionButton.modelData.shortcut ?? ""
                        color: Appearance.m3colors.m3outline
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }
                }
                Loader {
                    active: actionButton.modelData.badge === undefined && actionButton.modelData.shortcut === undefined && actionButton.modelData.hasSubmenu === true
                    sourceComponent: MaterialSymbol {
                        text: "chevron_right"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3outline
                    }
                }
            }

            // Selected/highlighted indicator: an outline, not a fill - MD3
            // draws "this is the row Enter/click would activate right now"
            // (keyboard focus / the row the pointer most recently settled
            // on) as a border, reserving solid fills for a pressed
            // ripple or a toggled-on state. Layered above the RippleButton's
            // own background rather than replacing it, so hover/press still
            // show through underneath a selected row.
            Rectangle {
                visible: actionButton.modelData.selected === true
                anchors.fill: parent
                anchors.margins: 1
                radius: actionButton.buttonEffectiveRadius
                color: "transparent"
                border.width: 1
                border.color: Appearance.m3colors.m3primary
            }

            onClicked: {
                root.close();
                modelData.onTriggered();
            }
        }
    }
}
