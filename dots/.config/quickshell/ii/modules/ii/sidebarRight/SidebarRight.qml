import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth

    SurfaceLifecycle {
        id: lifecycle
        keepMounted: Config?.options.sidebar.keepRightSidebarLoaded ?? false
        enterDuration: Appearance.animation.elementMove.duration
        exitDuration: Appearance.animation.elementMoveSmall.duration
        enterCurve: Appearance.animation.elementMove.bezierCurve
        exitCurve: Appearance.animation.elementMoveSmall.bezierCurve
    }

    Connections {
        target: GlobalStates
        function onSidebarRightOpenChanged() {
            lifecycle.setOpen(GlobalStates.sidebarRightOpen);
        }
    }

    Component.onCompleted: lifecycle.setOpen(GlobalStates.sidebarRightOpen)

    PanelWindow {
        id: panelWindow
        visible: lifecycle.surfaceVisible

        function hide() {
            GlobalStates.sidebarRightOpen = false;
        }

        exclusiveZone: 0
        implicitWidth: sidebarWidth
        WlrLayershell.namespace: "quickshell:sidebarRight"
        WlrLayershell.keyboardFocus: lifecycle.acceptsInput ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
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

        Loader {
            id: sidebarContentLoader
            active: lifecycle.mounted
            anchors {
                fill: parent
                margins: Appearance.sizes.hyprlandGapsOut
                leftMargin: Appearance.sizes.elevationMargin
            }
            width: sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
            height: parent.height - Appearance.sizes.hyprlandGapsOut * 2

            focus: lifecycle.acceptsInput
            transform: Translate {
                x: sidebarContentLoader.width * (1 - lifecycle.progress)
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    panelWindow.hide();
                }
            }

            sourceComponent: SidebarRightContent {}
        }
    }

    IpcHandler {
        target: "sidebarRight"

        function toggle(): void {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }

        function close(): void {
            GlobalStates.sidebarRightOpen = false;
        }

        function open(): void {
            GlobalStates.sidebarRightOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarRightToggle"
        description: "Toggles right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }
    GlobalShortcut {
        name: "sidebarRightOpen"
        description: "Opens right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = true;
        }
    }
    GlobalShortcut {
        name: "sidebarRightClose"
        description: "Closes right sidebar on press"

        onPressed: {
            GlobalStates.sidebarRightOpen = false;
        }
    }
}
