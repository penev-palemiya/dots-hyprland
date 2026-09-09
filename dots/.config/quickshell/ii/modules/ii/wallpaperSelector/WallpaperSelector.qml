import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    SurfaceLifecycle {
        id: lifecycle
        enterDuration: Appearance.animation.elementMove.duration
        exitDuration: Appearance.animation.elementMoveSmall.duration
        enterCurve: Appearance.animation.elementMove.bezierCurve
        exitCurve: Appearance.animation.elementMoveSmall.bezierCurve
    }

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            lifecycle.setOpen(GlobalStates.wallpaperSelectorOpen);
        }
    }

    Component.onCompleted: lifecycle.setOpen(GlobalStates.wallpaperSelectorOpen)

    Loader {
        id: wallpaperSelectorLoader
        active: lifecycle.mounted

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: lifecycle.surfaceVisible
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: lifecycle.acceptsInput ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            anchors.top: true
            margins {
                top: Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: lifecycle.acceptsInput ? content : null
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            Component.onCompleted: {
                if (lifecycle.acceptsInput)
                    GlobalFocusGrab.addDismissable(panelWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: lifecycle
                function onOpeningStarted() {
                    Qt.callLater(() => {
                        if (lifecycle.acceptsInput)
                            GlobalFocusGrab.addDismissable(panelWindow);
                    });
                }
                function onClosingStarted() {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    fill: parent
                }
                transformOrigin: Item.Top
                scale: 0.96 + 0.04 * lifecycle.progress
                opacity: Math.max(0, Math.min(1, lifecycle.progress))
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
