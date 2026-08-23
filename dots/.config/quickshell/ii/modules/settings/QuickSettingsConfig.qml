import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.quickToggles
import qs.modules.settings.components

SettingsSubPage {
    id: root

    readonly property bool androidStyle: Config.options.sidebar.quickToggles.style === "android"
    readonly property var configuredToggles: Config.options.sidebar.quickToggles.android.toggles ?? []
    readonly property var knownEntries: QuickToggleCatalog.entries

    function entryFor(type) {
        return QuickToggleCatalog.entry(type);
    }

    function labelFor(type) {
        const entry = entryFor(type);
        return entry ? Translation.tr(entry.labelKey) : type;
    }

    function setToggles(value) {
        Config.options.sidebar.quickToggles.android.toggles = value;
    }

    function move(index, offset) {
        const target = index + offset;
        if (target < 0 || target >= configuredToggles.length)
            return;
        const next = configuredToggles.slice();
        const item = next[index];
        next[index] = next[target];
        next[target] = item;
        setToggles(next);
    }

    function remove(index) {
        const next = configuredToggles.slice();
        next.splice(index, 1);
        setToggles(next);
    }

    function add(type) {
        if (configuredToggles.some(item => item?.type === type))
            return;
        setToggles(configuredToggles.concat([{ type: type, size: 1 }]));
    }

    function toggleSize(index) {
        const next = configuredToggles.slice();
        next[index] = { type: next[index].type, size: next[index].size === 2 ? 1 : 2 };
        setToggles(next);
    }

    SettingsGroup {
        title: Translation.tr("LAYOUT")

        SettingsRow {
            icon: "dashboard"
            title: Translation.tr("Style")
            description: Translation.tr("Choose the Quick Settings layout.")

            StyledComboBox {
                model: [Translation.tr("Classic"), Translation.tr("Android")]
                currentIndex: root.androidStyle ? 1 : 0
                onActivated: index => Config.options.sidebar.quickToggles.style = index === 1 ? "android" : "classic"
            }
        }

        SettingsRow {
            visible: root.androidStyle
            icon: "splitscreen_left"
            title: Translation.tr("Columns")
            description: Translation.tr("Number of tile columns in the Android layout.")

            RowLayout {
                spacing: 4
                RippleButton {
                    text: "−"
                    enabled: Config.options.sidebar.quickToggles.android.columns > 1
                        && (Config.options.sidebar.quickToggles.android.columns > 2
                            || !root.configuredToggles.some(item => item?.size === 2))
                    onClicked: Config.options.sidebar.quickToggles.android.columns = Config.options.sidebar.quickToggles.android.columns - 1
                }
                StyledText {
                    text: Config.options.sidebar.quickToggles.android.columns
                    Layout.minimumWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }
                RippleButton {
                    text: "+"
                    enabled: Config.options.sidebar.quickToggles.android.columns < 8
                    onClicked: Config.options.sidebar.quickToggles.android.columns = Config.options.sidebar.quickToggles.android.columns + 1
                }
            }
        }
    }

    SettingsGroup {
        visible: root.androidStyle
        title: Translation.tr("TILES")

        Repeater {
            model: root.configuredToggles

            SettingsRow {
                required property var modelData
                required property int index
                property var metadata: root.entryFor(modelData?.type)
                property bool duplicate: root.configuredToggles.findIndex(item => item?.type === modelData?.type) !== index

                icon: metadata?.icon ?? "help"
                title: metadata ? root.labelFor(modelData.type) : modelData?.type ?? Translation.tr("Unknown tile")
                description: duplicate
                    ? Translation.tr("Duplicate tile")
                    : !metadata
                        ? Translation.tr("Unknown tile")
                        : QuickToggleCatalog.isAvailable(modelData.type)
                            ? Translation.tr("Visible")
                            : Translation.tr("Currently unavailable")
                registerInSearch: false

                RowLayout {
                    spacing: 4
                    RippleButton {
                        text: "↑"
                        enabled: index > 0
                        onClicked: root.move(index, -1)
                    }
                    RippleButton {
                        text: "↓"
                        enabled: index < root.configuredToggles.length - 1
                        onClicked: root.move(index, 1)
                    }
                    RippleButton {
                        visible: !!metadata
                        enabled: Config.options.sidebar.quickToggles.android.columns > 1
                        text: modelData?.size === 2 ? Translation.tr("Wide") : Translation.tr("Compact")
                        onClicked: root.toggleSize(index)
                    }
                    RippleButton {
                        text: Translation.tr("Hide")
                        onClicked: root.remove(index)
                    }
                }
            }
        }

        Repeater {
            model: root.knownEntries.filter(entry => !root.configuredToggles.some(item => item?.type === entry.type))

            SettingsRow {
                required property var modelData
                icon: modelData.icon
                title: Translation.tr(modelData.labelKey)
                description: Translation.tr("Available")
                registerInSearch: false

                RippleButton {
                    text: Translation.tr("Add")
                    onClicked: root.add(modelData.type)
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("SLIDERS")

        SettingsToggleRow {
            icon: "tune"
            title: Translation.tr("Show quick sliders")
            description: Translation.tr("Show volume, microphone, and brightness controls in Quick Settings.")
            checked: Config.options.sidebar.quickSliders.enable
            onToggled: checked => Config.options.sidebar.quickSliders.enable = checked
        }

        SettingsToggleRow {
            icon: "brightness_6"
            title: Translation.tr("Brightness")
            description: Translation.tr("Show the brightness slider.")
            enabled: Config.options.sidebar.quickSliders.enable
            checked: Config.options.sidebar.quickSliders.showBrightness
            onToggled: checked => Config.options.sidebar.quickSliders.showBrightness = checked
        }
        SettingsToggleRow {
            icon: "volume_up"
            title: Translation.tr("Volume")
            description: Translation.tr("Show the output volume slider.")
            enabled: Config.options.sidebar.quickSliders.enable
            checked: Config.options.sidebar.quickSliders.showVolume
            onToggled: checked => Config.options.sidebar.quickSliders.showVolume = checked
        }
        SettingsToggleRow {
            icon: "mic"
            title: Translation.tr("Microphone")
            description: Translation.tr("Show the microphone volume slider.")
            enabled: Config.options.sidebar.quickSliders.enable
            checked: Config.options.sidebar.quickSliders.showMic
            onToggled: checked => Config.options.sidebar.quickSliders.showMic = checked
        }
    }
}
