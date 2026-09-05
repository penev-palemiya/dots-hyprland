import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

/**
 * The Super-key overview: search + workspace grid, opened by
 * GlobalStates.overviewOpen.
 *
 * Motion follows the same container-transform recipe as the bar popups
 * (StyledPopup.qml, docs/design/motion.md) and the dynamic island's overlay:
 * one surface that scales/fades in and out, never destroyed and rebuilt on
 * every toggle, kept mapped through its own exit animation. That last part is
 * what mattering for fast repeated Super presses specifically - the previous
 * version tied `visible` directly to `overviewOpen`, so each toggle mapped or
 * unmapped a real Wayland layer-shell surface immediately. Two presses close
 * together raced a map against an unmap with no animation to absorb either,
 * which is what read as a "jump". Here a second press before the first
 * animation finishes just reverses the same in-flight motionProgress
 * Behavior - there is no remap to race.
 */
Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

        // Kept mapped through the exit animation - see exitTimer below. Never
        // remapped by a same-direction repeat press: `shown` just stays true
        // (or false), so there is nothing to interrupt but the animation
        // itself.
        property bool exiting: false
        property bool built: false
        visible: GlobalStates.overviewOpen || exiting || built

        // Multiplies every animation duration here, so the phases can be
        // watched individually when debugging motion. 1 = normal speed;
        // everything that depends on timing (including exitTimer, which must
        // outlast the exit animation or the surface unmaps mid-flight) reads
        // this, so one value is enough to slow the whole overlay down.
        readonly property real slowMo: 1

        // Built once on first open, then kept - same reasoning as
        // StyledPopup's `built`: constructing the whole content tree AND
        // bringing up the layer-shell surface for the first time is real work,
        // and doing that in the same frame the open animation starts is what
        // makes a first open stutter even when later opens are smooth.
        Timer {
            id: preloadTimer
            interval: 4000
            running: !panelWindow.built
            repeat: false
            onTriggered: panelWindow.built = true
        }

        onVisibleChanged: if (visible) panelWindow.built = true

        Timer {
            id: exitTimer
            // Must outlast the LONGEST exit animation, plus a margin -
            // unmapping the surface mid-animation is what the whole
            // exiting/built arrangement exists to prevent, and it is exactly
            // what the overlay looked like when this was too short: the exit
            // visibly cut off partway instead of playing out.
            //
            // Two things make the exit longer than a single token's duration.
            // The blocks now leave on elementMoveSmall (350ms, not the 200ms
            // elementMoveExit this used to read), and gridProgress carries a
            // PauseAnimation in front of its NumberAnimation. Both are
            // accounted for here so the timer cannot undercut the motion
            // again.
            interval: (Appearance.animation.elementMoveSmall.duration + panelWindow.staggerStep) * panelWindow.slowMo + 40
            onTriggered: panelWindow.exiting = false
        }

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        // Real content while open; collapses to nothing while closing so the
        // window can stay mapped for the exit animation without eating the
        // click/keypress that dismissed it, or blocking whatever is
        // underneath.
        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                    exitTimer.restart();
                } else {
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                    exitTimer.stop();
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }

        // Fixed to the fully-open content size regardless of motionProgress -
        // this is the layer-shell surface's own geometry, and animating it
        // directly would resize the actual Wayland surface every frame
        // instead of just transforming what's painted inside it. The visual
        // grow/shrink comes entirely from motionScale on columnLayout below.
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        // 0 = closed, 1 = fully open.
        //
        // Deliberately NOT the expressive*Spatial spring tokens the bar popups
        // and the island use. Those overshoot by ~21% (expressiveDefaultSpatial's
        // [0.38, 1.21, ...]), which reads as a pleasing bounce on a 26px pill
        // but as the entire screen physically wobbling when it's driving a
        // full-screen overlay's scale - every workspace thumbnail and the
        // search field lurching past their final position together.
        //
        // MD3's motion for a full-screen surface entering is emphasized
        // decelerate (fast start, soft landing, no overshoot) and accelerate
        // on exit - which is exactly what elementMoveEnter/elementMoveExit
        // already wrap. One static NumberAnimation varying its own properties,
        // per docs/design/motion.md's "a Behavior's animation can only be
        // assigned once".
        property real motionProgress: GlobalStates.overviewOpen && panelWindow.built ? 1 : 0

        // Spatial motion gets a spring, the same pairing the dynamic island
        // uses for its height (IslandOverlay.qml): elementMove on the way in
        // (500ms, expressiveDefaultSpatial, ~21% overshoot - the hero moment)
        // and elementMoveSmall on the way out (350ms, expressiveFastSpatial -
        // exits need less attention than whatever comes next).
        //
        // An earlier version of this file deliberately avoided these tokens,
        // because the overshoot was driving `scale` on a full-screen surface
        // and read as the whole screen wobbling. That no longer applies: the
        // motion is now a vertical slide per block, where the overshoot reads
        // as a spring settling into place, which is the point.
        //
        // One static NumberAnimation varying its own duration/curve - a
        // Behavior's `animation` can only be assigned once.
        Behavior on motionProgress {
            NumberAnimation {
                duration: (GlobalStates.overviewOpen ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration) * panelWindow.slowMo
                easing.type: Easing.BezierSpline
                easing.bezierCurve: GlobalStates.overviewOpen ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
            }
        }

        // Second driver, trailing motionProgress by one stagger step.
        //
        // MD3 brings a group of surfaces on in sequence rather than as a
        // single rigid block: each element runs the same curve, offset in
        // time, so the eye reads them as related but distinct. Here the search
        // field leads and the workspace grid follows, which also matches
        // reading order (top down).
        //
        // The delay is applied as a PauseAnimation in front of the same
        // easing, not as a different duration - keeping the curve identical is
        // what makes the two read as one coordinated motion instead of two
        // unrelated ones. On exit the order reverses: the grid leaves first,
        // so the stagger is applied to the leading element instead.
        readonly property int staggerStep: 50
        property real gridProgress: GlobalStates.overviewOpen && panelWindow.built ? 1 : 0

        Behavior on gridProgress {
            SequentialAnimation {
                PauseAnimation {
                    duration: (GlobalStates.overviewOpen ? panelWindow.staggerStep : 0) * panelWindow.slowMo
                }
                NumberAnimation {
                    duration: (GlobalStates.overviewOpen ? Appearance.animation.elementMove.duration : Appearance.animation.elementMoveSmall.duration) * panelWindow.slowMo
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: GlobalStates.overviewOpen ? Appearance.animation.elementMove.bezierCurve : Appearance.animation.elementMoveSmall.bezierCurve
                }
            }
        }

        Column {
            id: columnLayout
            // Tied to motionProgress, NOT to panelWindow.visible. `visible` is
            // true whenever the window is mapped - which, thanks to `built`,
            // is permanently after the preload. An earlier version bound this
            // to panelWindow.visible, so the whole content tree (workspace
            // grid, window previews, search field) stayed in the scene graph
            // being rendered every frame with opacity 0 while the overview was
            // closed. opacity 0 does not skip rendering in QML; visible false
            // does.
            // Either driver still in flight keeps it rendered; both at rest
            // means nothing is on screen and the whole tree can be skipped.
            visible: panelWindow.motionProgress > 0 || panelWindow.gridProgress > 0
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                // The column itself no longer moves - it is a layout box.
                // Each child carries its own offset so the two blocks can
                // enter on staggered timing (see gridProgress above); moving
                // the container as well would drag them back into lockstep.
            }
            spacing: -8

            // Alpha is never animated on this surface.
            //
            // Forced by the compositor, not a style choice. Hyprland's blur is
            // binary: a layer is either blurred or it is not, and the
            // `ignore_alpha` threshold in hyprland/rules.lua decides which by
            // comparing against the pixel's alpha. A surface that fades from 0
            // to 1 crosses that threshold mid-animation and the blur snaps on
            // in a single frame - measured as the panel's empty area jumping
            // from luma 0.1376 to 0.1084 between two consecutive frames.
            // Dropping the threshold to 0 removes the snap but blurs the
            // overlay at full strength from the first frame, so the backdrop
            // stops arriving with the content at all.
            //
            // No threshold fixes this, because the compositor cannot ramp blur
            // in step with a client-side fade. Keeping alpha pinned at 1
            // sidesteps it: the blur stays in exactly one state throughout,
            // and the motion is carried by geometry, which the compositor does
            // not inspect.



            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                }
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter

                // Leads the entry. Slides down from behind the top edge and
                // settles - emphasized decelerate, per elementMoveEnter.
                //
                // The offset goes through a Translate, not through `y`: this
                // is a child of a Column, which assigns `y` itself to lay its
                // children out. Setting `y` here fought the layout and left
                // the search field off-screen entirely.
                transformOrigin: Item.Top
                scale: 0.94 + 0.06 * panelWindow.motionProgress
                transform: Translate {
                    y: -searchWidget.height * (1 - panelWindow.motionProgress)
                }
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                anchors.horizontalCenter: parent.horizontalCenter

                // Follows one stagger step behind, on the same curve. Same
                // Translate reasoning as the search field above.
                transformOrigin: Item.Top
                scale: 0.94 + 0.06 * panelWindow.gridProgress
                transform: Translate {
                    y: -overviewLoader.height * (1 - panelWindow.gridProgress)
                }
                // Tied to `built` (set by preloadTimer, 4s after startup)
                // rather than to overviewOpen, so the grid is instantiated
                // well before any open animation runs. Activating it on open
                // meant paying tree construction inside the animation, which
                // is what made the panel appear several frames late.
                active: panelWindow.built && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                    visible: (panelWindow.searchingText == "")
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        function toggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
