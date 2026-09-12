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
    readonly property int flyDuration: 300
    readonly property int staggerDelay: 90

    property real searchMotion: overviewController.requestedOpen ? 1 : 0
    property real searchOpacity: overviewController.requestedOpen ? 1 : 0
    property real gridMotion: overviewController.requestedOpen ? 1 : 0
    property real gridOpacity: overviewController.requestedOpen ? 1 : 0

    Behavior on searchMotion {
        SequentialAnimation {
            PauseAnimation {
                duration: overviewController.requestedOpen ? overviewScope.staggerDelay : 0
            }
            NumberAnimation {
                duration: overviewScope.flyDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    Behavior on searchOpacity {
        SequentialAnimation {
            PauseAnimation {
                duration: overviewController.requestedOpen ? overviewScope.staggerDelay : 0
            }
            NumberAnimation {
                duration: overviewScope.flyDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    Behavior on gridMotion {
        SequentialAnimation {
            PauseAnimation {
                duration: overviewController.requestedOpen ? 0 : overviewScope.staggerDelay
            }
            NumberAnimation {
                duration: overviewScope.flyDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
    }

    Behavior on gridOpacity {
        SequentialAnimation {
            PauseAnimation {
                duration: overviewController.requestedOpen ? 0 : overviewScope.staggerDelay
            }
            NumberAnimation {
                duration: overviewScope.flyDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
    }

    SurfaceLifecycle {
        id: overviewController
        enterDuration: overviewScope.staggerDelay + overviewScope.flyDuration
        exitDuration: overviewScope.staggerDelay + overviewScope.flyDuration
        enterCurve: Appearance.animationCurves.expressiveFastSpatial
        exitCurve: Appearance.animationCurves.expressiveFastSpatial
        deferOpening: false
    }

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor && monitor) ? (Hyprland.focusedMonitor.id == monitor.id) : false

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
                    if (searchWidget.workspaceGrid)
                        searchWidget.workspaceGrid.clearSelection();
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

        // Keep the Wayland surface at its final geometry. Only the QML shape
        // below grows, avoiding a layer-shell reconfiguration on every frame.
        implicitWidth: Math.max(searchWidget.implicitWidth, overviewLoader.implicitWidth)
        implicitHeight: searchWidget.implicitHeight + columnLayout.spacing + overviewLoader.implicitHeight

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
            }
            spacing: -8

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
                opacity: overviewScope.searchOpacity
                transformOrigin: Item.Center
                scale: 0.85 + 0.15 * overviewScope.searchMotion
                transform: Translate {
                    y: -16 * (1 - overviewScope.searchMotion)
                }
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Item {
                id: gridReveal
                anchors.horizontalCenter: parent.horizontalCenter
                width: overviewLoader.implicitWidth
                height: overviewLoader.implicitHeight

                Loader {
                    id: overviewLoader
                    opacity: overviewScope.gridOpacity
                    transformOrigin: Item.Center
                    scale: 0.85 + 0.15 * overviewScope.gridMotion
                    transform: Translate {
                        y: -16 * (1 - overviewScope.gridMotion)
                    }
                    anchors {
                        top: parent.top
                        horizontalCenter: parent.horizontalCenter
                    }
                    // Keep the QML grid warm between invocations; recreating all
                    // delegates during entry causes a visible frame stall. Capture
                    // sources still detach after exit, releasing their buffers.
                    active: !Config || !Config.options || !Config.options.overview || (Config.options.overview.enable !== false)
                    sourceComponent: OverviewWidget {
                        screen: panelWindow.screen
                        // Keep snapshots for the entire mapped lifetime: prepare
                        // them during entry and release them only after exit.
                        captureActive: overviewController.mounted
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
