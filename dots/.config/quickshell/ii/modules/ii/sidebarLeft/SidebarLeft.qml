import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool detach: false
    property bool pin: false
    property Component contentComponent: SidebarLeftContent {}
    property Item sidebarContent

    SurfaceLifecycle {
        id: lifecycle
        keepMounted: true
        enterDuration: Appearance.animation.elementMove.duration
        exitDuration: Appearance.animation.elementMoveSmall.duration
        enterCurve: Appearance.animation.elementMove.bezierCurve
        exitCurve: Appearance.animation.elementMoveSmall.bezierCurve
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            lifecycle.setOpen(GlobalStates.sidebarLeftOpen);
        }
    }

    function toggleDetach() {
        root.detach = !root.detach;
    }

    Process { // Dodge cursor away, pin, move cursor back
        id: pinWithFunnyHyprlandWorkaroundProc
        property var hook: null
        property int cursorX;
        property int cursorY;
        function doIt() {
            command = ["hyprctl", "cursorpos"]
            hook = (output) => {
                cursorX = parseInt(output.split(",")[0]);
                cursorY = parseInt(output.split(",")[1]);
                doIt2();
            }
            running = true;
        }
        function doIt2(output) {
            command = ["bash", "-c", "hyprctl dispatch 'hl.dsp.cursor.move({x=9999,y=9999})'"];
            hook = () => {
                doIt3();
            }
            running = true;
        }
        function doIt3(output) {
            root.pin = !root.pin;
            command = ["bash", "-c", `sleep 0.01; hyprctl dispatch 'hl.dsp.cursor.move({x=${cursorX},y=${cursorY}})'`];
            hook = null
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                pinWithFunnyHyprlandWorkaroundProc.hook(text);
            }
        }
    }

    function togglePin() {
        if (!root.pin) pinWithFunnyHyprlandWorkaroundProc.doIt()
        else root.pin = !root.pin;
    }

    Component.onCompleted: {
        lifecycle.setOpen(GlobalStates.sidebarLeftOpen);
        root.sidebarContent = contentComponent.createObject(null, {
            "scopeRoot": root,
        });
        sidebarLoader.item.contentParent.children = [root.sidebarContent];
    }

    onDetachChanged: {
        if (root.detach) {
            GlobalFocusGrab.removeDismissable(sidebarLoader.item) // Remove sidebar from the focus grab system
            sidebarContent.parent = null; // Detach content from sidebar
            sidebarLoader.active = false; // Unload sidebar
            detachedSidebarLoader.active = true; // Load detached window
            detachedSidebarLoader.item.contentParent.children = [sidebarContent];
        } else {
            sidebarContent.parent = null; // Detach content from window
            detachedSidebarLoader.active = false; // Unload detached window
            sidebarLoader.active = true; // Load sidebar
            sidebarLoader.item.contentParent.children = [sidebarContent];
        }
    }

    Loader {
        id: sidebarLoader
        active: true
        
        sourceComponent: PanelWindow { // Window
            id: panelWindow
            visible: lifecycle.surfaceVisible
            
            property bool extend: false
            property real sidebarWidth: panelWindow.extend ? Appearance.sizes.sidebarWidthExtended : Appearance.sizes.sidebarWidth
            property var contentParent: sidebarLeftBackground

            function hide() {
                GlobalStates.sidebarLeftOpen = false
            }

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.pin ? sidebarWidth : 0
            implicitWidth: Appearance.sizes.sidebarWidthExtended + Appearance.sizes.elevationMargin
            WlrLayershell.namespace: "quickshell:sidebarLeft"
            // Hyprland 0.49: OnDemand is Exclusive, Exclusive just breaks click-outside-to-close
            WlrLayershell.keyboardFocus: lifecycle.acceptsInput ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                left: true
                bottom: true
            }

            mask: Region {
                item: lifecycle.acceptsInput ? sidebarLeftBackground : null
            }

            Connections {
                target: lifecycle
                function onOpeningStarted() {
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
                function onClosingStarted() {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    panelWindow.hide();
                }
            }

            // Content
            Item {
                id: sidebarLeftContainer
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: Appearance.sizes.hyprlandGapsOut
                anchors.leftMargin: Appearance.sizes.hyprlandGapsOut
                width: panelWindow.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                height: parent.height - Appearance.sizes.hyprlandGapsOut * 2
                transform: Translate {
                    x: -sidebarLeftContainer.width * (1 - lifecycle.progress)
                }

                Behavior on width {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: sidebarLeftBackground
                    radius: sidebarLeftBackground.radius
                }
                Rectangle {
                    id: sidebarLeftBackground
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

                    Keys.onPressed: (event) => {
                        if (event.key === Qt.Key_Escape) {
                            panelWindow.hide();
                        }
                        if (event.modifiers === Qt.ControlModifier) {
                            if (event.key === Qt.Key_O) {
                                panelWindow.extend = !panelWindow.extend;
                            } else if (event.key === Qt.Key_D) {
                                root.toggleDetach();
                            } else if (event.key === Qt.Key_P) {
                                root.togglePin();
                            }
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: detachedSidebarLoader
        active: false

        sourceComponent: FloatingWindow {
            id: detachedSidebarRoot
            property var contentParent: detachedSidebarBackground
            color: "transparent"

            visible: GlobalStates.sidebarLeftOpen
            onVisibleChanged: {
                if (!visible) GlobalStates.sidebarLeftOpen = false;
            }
            
            Rectangle {
                id: detachedSidebarBackground
                anchors.fill: parent
                color: Appearance.colors.colLayer0

                Keys.onPressed: (event) => {
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle() {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
        }

        function close() {
            GlobalStates.sidebarLeftOpen = false
        }

        function open() {
            GlobalStates.sidebarLeftOpen = true
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = false;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggleDetach"
        description: "Detach left sidebar into a window/Attach it back"

        onPressed: {
            root.detach = !root.detach;
        }
    }

}
