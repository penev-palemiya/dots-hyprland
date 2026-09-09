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

// Owns the overview surface and external commands. OverviewController is the
// only owner of transition state; the grid exists only while the surface does.
Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false

    OverviewController {
        id: overviewController
        enterDuration: Appearance.animation.elementMoveLarge.duration
        exitDuration: Appearance.animation.elementMoveExit.duration
        enterCurve: Appearance.animation.elementMoveLarge.bezierCurve
        exitCurve: Appearance.animationCurves.emphasizedDecel
        onFullyClosed: searchWidget.workspaceGrid = null
    }

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

        visible: overviewController.surfaceVisible

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: overviewController.acceptsInput ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        // Real content while open; collapses to nothing while closing so the
        // window can stay mapped for the exit animation without eating the
        // click/keypress that dismissed it, or blocking whatever is
        // underneath.
        mask: Region {
            item: overviewController.acceptsInput ? columnLayout : null
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
                if (GlobalStates.overviewOpen)
                    HyprlandData.updateWindowList();
                overviewController.setOpen(GlobalStates.overviewOpen);
                if (!GlobalStates.overviewOpen) {
                    searchWidget.workspaceGrid?.clearSelection();
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    GlobalFocusGrab.dismiss();
                } else {
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
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

        Column {
            id: columnLayout
            visible: overviewController.surfaceVisible
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
                overviewOpen: overviewController.requestedOpen
                onCloseRequested: GlobalStates.overviewOpen = false

                // Leads the entry. Slides down from behind the top edge and
                // settles - emphasized decelerate, per elementMoveEnter.
                //
                // The offset goes through a Translate, not through `y`: this
                // is a child of a Column, which assigns `y` itself to lay its
                // children out. Setting `y` here fought the layout and left
                // the search field off-screen entirely.
                transformOrigin: Item.Top
                scale: 0.94 + 0.06 * overviewController.progress
                transform: Translate {
                    y: -searchWidget.height * (1 - overviewController.progress)
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
                scale: 0.94 + 0.06 * overviewController.progress
                transform: Translate {
                    y: -overviewLoader.height * (1 - overviewController.progress)
                }
                // Destroy previews and their graphics resources after exit.
                active: overviewController.contentNeeded && (Config?.options.overview.enable ?? true)
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                    captureActive: overviewController.requestedOpen
                    captureGeneration: overviewController.generation
                    visible: (panelWindow.searchingText == "")
                    onCloseRequested: GlobalStates.overviewOpen = false
                    onWorkspaceActivated: workspace => Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace} })`)
                    onWindowActivated: address => Hyprland.dispatch(`hl.dsp.focus({window = "address:${address}"})`)
                    onWindowCloseRequested: address => Hyprland.dispatch(`hl.dsp.window.close({window = "address:${address}"})`)
                    onWindowMoveToWorkspaceRequested: (address, workspace) => Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${workspace}, follow = false, window = "address:${address}" })`)
                    onWindowMoveToPositionRequested: (address, x, y) => Hyprland.dispatch(`hl.dsp.window.move({ x = "${x}", y = "${y}", window = "address:${address}" })`)
                }
                // Hand the grid to the search field so an empty query can
                // steer it with the arrow keys.
                onLoaded: searchWidget.workspaceGrid = item
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

    Component.onCompleted: overviewController.setOpen(GlobalStates.overviewOpen)

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
