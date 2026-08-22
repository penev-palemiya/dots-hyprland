import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components
import "../ii/sidebarRight/volumeMixer"

SettingsSubPage {
    id: root

    readonly property var outputDevices: Audio.outputDevices
    readonly property var inputDevices: Audio.inputDevices
    readonly property var playbackStreams: Audio.outputAppNodes
    readonly property bool hasOutput: Audio.sink !== null
    readonly property bool hasInput: Audio.source !== null

    function deviceLabel(node) {
        if (!node)
            return Translation.tr("No device available");
        return Audio.friendlyDeviceName(node);
    }

    // This monitor follows only the selected/default input. Assigning node is
    // enough to detach from the previous node; no polling or extra timer is
    // needed because PwNodePeakMonitor is event-driven.
    PwNodePeakMonitor {
        id: inputPeakMonitor
        node: Audio.source
        enabled: root.hasInput
    }

    SettingsGroup {
        title: Translation.tr("Output")

        SettingsRow {
            icon: "speaker"
            title: Translation.tr("Output device")
            description: root.hasOutput ? root.deviceLabel(Audio.sink) : Translation.tr("No output device available")

            StyledComboBox {
                width: 280
                model: root.outputDevices.map(node => root.deviceLabel(node))
                currentIndex: root.outputDevices.findIndex(node => node.id === Audio.sink?.id)
                enabled: root.outputDevices.length > 0
                onActivated: index => {
                    const node = root.outputDevices[index];
                    if (node)
                        Audio.setDefaultSink(node);
                }
            }
        }

        SettingsRow {
            icon: "volume_up"
            title: Translation.tr("Volume")
            description: root.hasOutput ? `${Math.round((Audio.sink.audio.volume ?? 0) * 100)}%` : Translation.tr("No output device available")

            RowLayout {
                width: 280
                spacing: 10

                StyledSlider {
                    Layout.fillWidth: true
                    value: Audio.sink?.audio?.volume ?? 0
                    enabled: root.hasOutput
                    onMoved: if (Audio.sink?.audio) Audio.sink.audio.volume = value
                    configuration: StyledSlider.Configuration.S
                }

                StyledText {
                    Layout.preferredWidth: 42
                    text: `${Math.round((Audio.sink?.audio?.volume ?? 0) * 100)}%`
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        SettingsRow {
            icon: "volume_off"
            title: Translation.tr("Mute output")
            description: Translation.tr("Mute the selected output device.")

            StyledSwitch {
                checked: Audio.sink?.audio?.muted ?? false
                enabled: root.hasOutput
                onToggled: if (Audio.sink?.audio) Audio.sink.audio.muted = checked
            }
        }

        SettingsRow {
            icon: "music_note"
            title: Translation.tr("Test sound")
            description: Translation.tr("Play a short system sound through the selected output.")
            clickable: root.hasOutput
            enabled: root.hasOutput
            onClicked: Audio.playSystemSound("complete")
        }
    }

    SettingsGroup {
        title: Translation.tr("Input")

        SettingsRow {
            icon: "mic"
            title: Translation.tr("Input device")
            description: root.hasInput ? root.deviceLabel(Audio.source) : Translation.tr("No input device available")

            StyledComboBox {
                width: 280
                model: root.inputDevices.map(node => root.deviceLabel(node))
                currentIndex: root.inputDevices.findIndex(node => node.id === Audio.source?.id)
                enabled: root.inputDevices.length > 0
                onActivated: index => {
                    const node = root.inputDevices[index];
                    if (node)
                        Audio.setDefaultSource(node);
                }
            }
        }

        SettingsRow {
            icon: "mic"
            title: Translation.tr("Microphone volume")
            description: root.hasInput ? `${Math.round((Audio.source.audio.volume ?? 0) * 100)}%` : Translation.tr("No input device available")

            RowLayout {
                width: 280
                spacing: 10

                StyledSlider {
                    Layout.fillWidth: true
                    value: Audio.source?.audio?.volume ?? 0
                    enabled: root.hasInput
                    onMoved: if (Audio.source?.audio) Audio.source.audio.volume = value
                    configuration: StyledSlider.Configuration.S
                }

                StyledText {
                    Layout.preferredWidth: 42
                    text: `${Math.round((Audio.source?.audio?.volume ?? 0) * 100)}%`
                    horizontalAlignment: Text.AlignRight
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        SettingsRow {
            icon: "mic_off"
            title: Translation.tr("Mute microphone")
            description: Translation.tr("Mute the selected input device.")

            StyledSwitch {
                checked: Audio.source?.audio?.muted ?? false
                enabled: root.hasInput
                onToggled: if (Audio.source?.audio) Audio.source.audio.muted = checked
            }
        }

        SettingsRow {
            icon: "graphic_eq"
            title: Translation.tr("Input level")
            description: root.hasInput ? Translation.tr("Live microphone activity") : Translation.tr("No input device available")

            Item {
                width: 280
                height: 36
                opacity: root.hasInput ? 1 : 0.4

                Row {
                    anchors.fill: parent
                    spacing: 3

                    Repeater {
                        model: 18

                        Rectangle {
                            required property int index
                            width: (parent.width - (17 * 3)) / 18
                            height: Math.max(3, parent.height * Math.min(1, (inputPeakMonitor.peak ?? 0) * (0.55 + index / 30)))
                            anchors.bottom: parent.bottom
                            radius: 2
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Applications")

        SettingsRow {
            icon: "apps"
            title: root.playbackStreams.length > 0 ? Translation.tr("Active playback streams") : Translation.tr("No applications are currently playing audio")
            description: root.playbackStreams.length > 0 ? Translation.tr("Adjust volume or mute an application.") : ""
            minimumHeight: root.playbackStreams.length > 0 ? Math.max(72, 28 + root.playbackStreams.length * 64) : 60

            Column {
                width: 280
                spacing: 12

                Repeater {
                    model: root.playbackStreams

                    VolumeMixerEntry {
                        required property var modelData
                        width: parent.width
                        node: modelData
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Volume Safety")

        SettingsToggleRow {
            icon: "hearing"
            title: Translation.tr("Earbang protection")
            description: Translation.tr("Blocks sudden volume jumps and caps how loud the output can go.")
            keywords: "volume loud hearing"
            checked: Config.options.audio.protection.enable
            onToggled: checked => Config.options.audio.protection.enable = checked
        }

        SettingsSubRow {
            title: Translation.tr("Maximum volume increase")
            description: Translation.tr("Limits one shortcut or scroll volume jump.")
            enabled: Config.options.audio.protection.enable

            StyledSpinBox {
                value: Config.options.audio.protection.maxAllowedIncrease
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: Config.options.audio.protection.maxAllowedIncrease = value
            }
        }

        SettingsSubRow {
            title: Translation.tr("Volume limit")
            description: Translation.tr("Prevents output volume going above this level.")
            enabled: Config.options.audio.protection.enable

            StyledSpinBox {
                value: Config.options.audio.protection.maxAllowed
                from: 0
                to: 154
                stepSize: 2
                onValueChanged: Config.options.audio.protection.maxAllowed = value
            }
        }
    }

    // These existing shell sound preferences stay available while the device
    // controls move into this page; they do not add another audio backend.
    SettingsGroup {
        title: Translation.tr("System sounds")

        SettingsToggleRow {
            icon: "battery_android_full"
            title: Translation.tr("Battery sounds")
            description: Translation.tr("Play a sound for battery warnings.")
            checked: Config.options.sounds.battery
            onToggled: checked => Config.options.sounds.battery = checked
        }

        SettingsToggleRow {
            icon: "av_timer"
            title: Translation.tr("Pomodoro sounds")
            description: Translation.tr("Play a sound when a Pomodoro interval ends.")
            checked: Config.options.sounds.pomodoro
            onToggled: checked => Config.options.sounds.pomodoro = checked
        }

        SettingsToggleRow {
            icon: "hourglass_bottom"
            title: Translation.tr("Countdown timer sounds")
            description: Translation.tr("Play a sound when a countdown timer finishes.")
            checked: Config.options.sounds.countdownTimer
            onToggled: checked => Config.options.sounds.countdownTimer = checked
        }
    }
}
