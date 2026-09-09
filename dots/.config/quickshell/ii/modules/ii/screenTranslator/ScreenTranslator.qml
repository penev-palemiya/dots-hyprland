pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    SurfaceLifecycle {
        id: lifecycle
        enterDuration: 1
        exitDuration: 1
        enterCurve: [0, 0, 1, 1]
        exitCurve: [0, 0, 1, 1]
    }

    function dismiss() {
        GlobalStates.screenTranslatorOpen = false
    }

    readonly property var currentScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    
    Loader {
        id: translatorLoader
        property var lockedScreen
        active: lifecycle.mounted
        Connections {
            target: GlobalStates
            function onScreenTranslatorOpenChanged() {
                if (GlobalStates.screenTranslatorOpen)
                    translatorLoader.lockedScreen = root.currentScreen
                lifecycle.setOpen(GlobalStates.screenTranslatorOpen);
            }
        }

        sourceComponent: ScreenTranslatorPanel {
            screen: translatorLoader.lockedScreen
            lifecycleVisible: lifecycle.surfaceVisible
            acceptsInput: lifecycle.acceptsInput
            onDismiss: root.dismiss()
        }
    }

    Component.onCompleted: {
        if (GlobalStates.screenTranslatorOpen)
            translatorLoader.lockedScreen = root.currentScreen;
        lifecycle.setOpen(GlobalStates.screenTranslatorOpen);
    }

    function translate() {
        GlobalStates.screenTranslatorOpen = true
    }

    IpcHandler {
        target: "screenTranslator"

        function translate() {
            root.translate()
        }
    }

    GlobalShortcut {
        name: "screenTranslate"
        description: "Translates screen content"
        onPressed: root.translate()
    }
}
