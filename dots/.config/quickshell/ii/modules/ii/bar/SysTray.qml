import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * System tray. Pinned items are always visible; everything else collapses
 * behind a single dot and expands inline, in the bar itself, instead of into
 * a popup window.
 *
 * Inline expansion is safe here specifically because BarContent puts a
 * `Layout.fillWidth` spacer right next to this item — the spacer absorbs the
 * width change, so growing the tray never displaces another bar module.
 *
 * The reveal is the same idiom as the island's queue chips: one animated
 * `revealPhase` on the root, from which every hidden item derives its own
 * staggered progress. That costs no per-item animation objects — the bindings
 * just re-evaluate — and it keeps the cascade the same length no matter how
 * many items are hidden.
 */
Item {
    id: root

    implicitWidth: gridLayout.implicitWidth
    implicitHeight: gridLayout.implicitHeight

    property bool vertical: false
    property bool invertSide: false
    // Kept under its original name because LockSurface.qml sets it to false to
    // make hidden items unreachable on the lock screen.
    property bool showOverflowMenu: true
    property bool showSeparator: true
    property var activeMenu: null

    // Sticky: click to expand, click again to collapse. Deliberately not
    // hover-driven — the bar would breathe every time the cursor crossed it.
    property bool expanded: false

    property list<var> pinnedItems: TrayService.pinnedItems
    property list<var> unpinnedItems: TrayService.unpinnedItems

    readonly property var hiddenItems: root.showOverflowMenu ? root.unpinnedItems : []
    readonly property bool hasHidden: root.hiddenItems.length > 0
    // A hidden item asking for attention is exactly what a tray is for, and
    // today it's invisible while collapsed — so the dot carries it.
    readonly property bool hiddenNeedsAttention: root.hiddenItems.some(i => i.status === Status.NeedsAttention)

    onHasHiddenChanged: if (!root.hasHidden) root.expanded = false

    // 0 collapsed, 1 fully expanded. Enter on the slower/bouncier token, exit
    // on the faster one — docs/design/motion.md §"Enter vs exit is asymmetric".
    // Not `readonly`: a Behavior has to write to the property it animates.
    property real revealPhase: root.expanded ? 1 : 0

    Behavior on revealPhase {
        NumberAnimation {
            duration: root.expanded ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
        }
    }

    // Item `index` starts at its own point in the phase and takes half of it
    // to arrive, so the last one always lands at the same moment regardless of
    // how many there are.
    function itemProgress(index) {
        const steps = Math.max(1, root.hiddenItems.length - 1);
        const start = Math.min(0.5, (index / steps) * 0.5);
        return Math.max(0, Math.min(1, (root.revealPhase - start) / 0.5));
    }

    function grabFocus() {
        focusGrab.active = true;
    }

    function setExtraWindowAndGrabFocus(window) {
        if (root.activeMenu && root.activeMenu !== window) {
            if (typeof root.activeMenu.close === "function")
                root.activeMenu.close();

            root.activeMenu = null;
        }
        root.activeMenu = window;
        root.grabFocus();
    }

    function releaseFocus() {
        focusGrab.active = false;
    }

    // Only the tray items' own right-click menus need a focus grab now; the
    // expansion is inline, so there is no popup window to dismiss.
    HyprlandFocusGrab {
        id: focusGrab

        active: false
        windows: [root.activeMenu]
        onCleared: {
            if (root.activeMenu) {
                root.activeMenu.close();
                root.activeMenu = null;
            }
        }
    }

    GridLayout {
        id: gridLayout

        columns: root.vertical ? 1 : -1
        anchors.fill: parent
        rowSpacing: 8
        columnSpacing: 15

        RippleButton {
            id: trayToggle

            visible: root.hasHidden
            toggled: root.expanded
            downAction: () => root.expanded = !root.expanded

            Layout.fillHeight: !root.vertical
            Layout.fillWidth: root.vertical
            background.implicitWidth: 24
            background.implicitHeight: 24
            background.anchors.centerIn: this
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive

            contentItem: Item {
                anchors.centerIn: parent

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    implicitWidth: 5
                    implicitHeight: 5
                    radius: width / 2
                    color: root.hiddenNeedsAttention ? Appearance.colors.colError : root.expanded ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(dot)
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.hiddenItems
            }

            delegate: Item {
                id: hiddenSlot

                required property SystemTrayItem modelData
                required property int index
                readonly property real progress: root.itemProgress(hiddenSlot.index)

                // Collapses to nothing so the layout's spacing collapses with
                // it; `visible` going false is what stops a zero-width item
                // from still reserving a gap.
                implicitWidth: root.vertical ? 20 : 20 * hiddenSlot.progress
                implicitHeight: root.vertical ? 20 * hiddenSlot.progress : 20
                visible: hiddenSlot.progress > 0.001
                opacity: hiddenSlot.progress
                scale: hiddenSlot.progress

                Layout.fillHeight: !root.vertical
                Layout.fillWidth: root.vertical

                SysTrayItem {
                    anchors.centerIn: parent
                    item: hiddenSlot.modelData
                    onMenuClosed: root.releaseFocus()
                    onMenuOpened: qsWindow => root.setExtraWindowAndGrabFocus(qsWindow)
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.pinnedItems
            }

            delegate: SysTrayItem {
                required property SystemTrayItem modelData

                item: modelData
                Layout.fillHeight: !root.vertical
                Layout.fillWidth: root.vertical
                onMenuClosed: root.releaseFocus()
                onMenuOpened: qsWindow => {
                    root.setExtraWindowAndGrabFocus(qsWindow);
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colSubtext
            text: "•"
            visible: root.showSeparator && SystemTray.items.values.length > 0
        }
    }
}
