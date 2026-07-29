import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarRight.quickToggles.classicStyle
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        ButtonGroup {
            Layout.alignment: Qt.AlignHCenter
            spacing: 5
            padding: 5
            color: Appearance.colors.colLayer1

            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showScreenSnip
                buttonIcon: "screenshot_region"
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"])
                StyledToolTip {
                    text: Translation.tr("Screen snip")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showScreenRecord
                buttonIcon: "videocam"
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                StyledToolTip {
                    text: Translation.tr("Screen record")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showColorPicker
                buttonIcon: "colorize"
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                StyledToolTip {
                    text: Translation.tr("Color picker")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showKeyboardToggle
                toggled: GlobalStates.oskOpen
                buttonIcon: "keyboard"
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                StyledToolTip {
                    text: Translation.tr("Keyboard toggle")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showMicToggle
                toggled: !(Pipewire.defaultAudioSource?.audio?.muted ?? true)
                buttonIcon: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                StyledToolTip {
                    text: Translation.tr("Mic toggle")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showDarkModeToggle
                toggled: Appearance.m3colors.darkmode
                buttonIcon: Appearance.m3colors.darkmode ? "dark_mode" : "light_mode"
                onClicked: {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`])
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`])
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Dark/Light toggle")
                }
            }
            QuickToggleButton {
                visible: Config.options.bar.utilButtons.showPerformanceProfileToggle
                toggled: PowerProfiles.profile === PowerProfile.Performance
                buttonIcon: {
                    switch (PowerProfiles.profile) {
                    case PowerProfile.PowerSaver:
                        return "energy_savings_leaf";
                    case PowerProfile.Balanced:
                        return "airwave";
                    case PowerProfile.Performance:
                        return "local_fire_department";
                    }
                }
                onClicked: {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch (PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:
                            PowerProfiles.profile = PowerProfile.Balanced;
                            break;
                        case PowerProfile.Balanced:
                            PowerProfiles.profile = PowerProfile.Performance;
                            break;
                        case PowerProfile.Performance:
                            PowerProfiles.profile = PowerProfile.PowerSaver;
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced;
                    }
                }
                StyledToolTip {
                    text: Translation.tr("Performance Profile toggle")
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            StyledText {
                anchors.centerIn: parent
                text: Translation.tr("Enjoy your empty sidebar...")
                color: Appearance.colors.colSubtext
            }
        }
    }
}
