import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property var draftLayouts: []
    property string draftGroupOption: ""
    property var draftNonGroupOptions: []
    property bool draftDirty: false
    property bool syncing: false
    property bool repeatPending: false

    function loadDraft() {
        if (!KeyboardSettings.ready) return;
        syncing = true;
        draftLayouts = KeyboardSettings.layoutEntries().map(item => Object.assign({}, item));
        draftGroupOption = KeyboardSettings.groupOption();
        draftNonGroupOptions = KeyboardSettings.nonGroupOptions(KeyboardSettings.optionsString);
        draftDirty = false;
        syncing = false;
    }

    function markDirty() { if (!syncing) draftDirty = true; }

    function draftState() {
        return Object.assign({}, KeyboardSettings.state, {
            kb_layout: draftLayouts.map(item => item.layout).join(","),
            kb_variant: draftLayouts.some(item => item.variant) ? draftLayouts.map(item => item.variant || "").join(",") : "",
            kb_options: KeyboardSettings.composeOptions(draftNonGroupOptions, draftGroupOption)
        });
    }

    function applyLayouts() {
        if (!draftDirty || draftLayouts.length === 0) return;
        KeyboardSettings.applyState(root.draftState());
    }

    function updateRepeat(key, value) {
        root.repeatPending = true;
        repeatTimer.restart();
    }

    function applyRepeat() {
        root.repeatPending = false;
        if (!KeyboardSettings.ready) return;
        const state = Object.assign({}, KeyboardSettings.state, {
            repeat_delay: root.repeatDelayDraft,
            repeat_rate: root.repeatRateDraft
        });
        KeyboardSettings.applyState(state);
    }

    property int repeatDelayDraft: KeyboardSettings.repeatDelay
    property int repeatRateDraft: KeyboardSettings.repeatRate

    Component.onCompleted: root.loadDraft()

    Connections {
        target: KeyboardSettings
        function onReadyChanged() { if (KeyboardSettings.ready && !root.draftDirty) root.loadDraft(); }
        function onStateChanged() {
            if (!root.draftDirty) root.loadDraft();
            root.repeatDelayDraft = KeyboardSettings.repeatDelay;
            root.repeatRateDraft = KeyboardSettings.repeatRate;
        }
        function onApplied(success) {
            if (success && !root.repeatPending) root.loadDraft();
        }
    }

    Timer {
        id: repeatTimer
        interval: 300
        repeat: false
        onTriggered: root.applyRepeat()
    }

    SettingsGroup {
        title: Translation.tr("Keyboard")

        SettingsRow {
            icon: "timer"
            title: Translation.tr("Repeat delay")
            description: `${root.repeatDelayDraft} ms`

            RowLayout {
                width: 280
                spacing: 10
                StyledSlider {
                    Layout.fillWidth: true
                    enabled: !KeyboardSettings.applying
                    from: 100
                    to: 1000
                    stepSize: 25
                    value: root.repeatDelayDraft
                    usePercentTooltip: false
                    onMoved: {
                        root.repeatDelayDraft = Math.round(value / 25) * 25;
                        root.updateRepeat("repeat_delay", root.repeatDelayDraft);
                    }
                }
                StyledText {
                    Layout.preferredWidth: 52
                    text: `${root.repeatDelayDraft} ms`
                    color: Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        SettingsRow {
            icon: "keyboard"
            title: Translation.tr("Repeat speed")
            description: `${root.repeatRateDraft} ${Translation.tr("per second")}`

            RowLayout {
                width: 280
                spacing: 10
                StyledSlider {
                    Layout.fillWidth: true
                    enabled: !KeyboardSettings.applying
                    from: 1
                    to: 100
                    stepSize: 1
                    value: root.repeatRateDraft
                    usePercentTooltip: false
                    onMoved: {
                        root.repeatRateDraft = Math.round(value);
                        root.updateRepeat("repeat_rate", root.repeatRateDraft);
                    }
                }
                StyledText {
                    Layout.preferredWidth: 74
                    text: `${root.repeatRateDraft}/s`
                    color: Appearance.colors.colOnSurfaceVariant
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        SettingsToggleRow {
            icon: "dialpad"
            title: Translation.tr("Num Lock on startup")
            description: Translation.tr("Applies when keyboards are initialized.")
            checked: KeyboardSettings.numlockByDefault
            enabled: !KeyboardSettings.applying
            onToggled: checked => KeyboardSettings.applyState(Object.assign({}, KeyboardSettings.state, { numlock_by_default: checked }))
        }
    }

    SettingsGroup {
        title: Translation.tr("Layouts")

        Repeater {
            model: root.draftLayouts

            SettingsRow {
                required property var modelData
                required property int index
                icon: "language"
                title: modelData.displayName
                description: modelData.variant ? `${modelData.layout} · ${modelData.variant}` : modelData.layout
                registerInSearch: false

                RowLayout {
                    spacing: 4
                    DialogButton {
                        buttonText: "↑"
                        enabled: index > 0
                        onClicked: {
                            const copy = root.draftLayouts.slice();
                            const item = copy.splice(index, 1)[0];
                            copy.splice(index - 1, 0, item);
                            root.draftLayouts = copy;
                            root.markDirty();
                        }
                    }
                    DialogButton {
                        buttonText: "↓"
                        enabled: index < root.draftLayouts.length - 1
                        onClicked: {
                            const copy = root.draftLayouts.slice();
                            const item = copy.splice(index, 1)[0];
                            copy.splice(index + 1, 0, item);
                            root.draftLayouts = copy;
                            root.markDirty();
                        }
                    }
                    DialogButton {
                        buttonText: Translation.tr("Remove")
                        enabled: root.draftLayouts.length > 1
                        onClicked: {
                            const copy = root.draftLayouts.slice();
                            copy.splice(index, 1);
                            root.draftLayouts = copy;
                            root.markDirty();
                        }
                    }
                }

                SettingsRow {
                    visible: KeyboardSettings.mainKeyboardLayout === modelData.displayName
                    leftPadding: 70
                    icon: "keyboard"
                    title: Translation.tr("Active on main keyboard")
                    description: KeyboardSettings.mainKeyboardName
                    registerInSearch: false
                }
            }
        }

        SettingsRow {
            icon: "add"
            title: Translation.tr("Add layout")
            description: Translation.tr("Search installed XKB layouts")
            registerInSearch: false

            SearchableSelection {
                width: 300
                currentValue: ""
                placeholder: Translation.tr("Add layout")
                searchPlaceholder: Translation.tr("Search layouts")
                options: KeyboardSettings.layoutCatalog.map(item => `${item.displayName} (${item.layout})`)
                onSelected: value => {
                    const match = KeyboardSettings.layoutCatalog.find(item => `${item.displayName} (${item.layout})` === value);
                    if (!match || root.draftLayouts.some(item => item.layout === match.layout && (item.variant || "") === (match.variant || ""))) return;
                    root.draftLayouts = root.draftLayouts.concat([{ layout: match.layout, variant: match.variant || "", displayName: match.displayName }]);
                    root.markDirty();
                }
            }
        }

        SettingsRow {
            visible: root.draftDirty
            icon: KeyboardSettings.applying ? "sync" : "save"
            title: KeyboardSettings.error.length > 0 ? Translation.tr("Keyboard settings failed") : Translation.tr("Apply layout changes")
            description: KeyboardSettings.error.length > 0 ? KeyboardSettings.error : Translation.tr("Applies the ordered layouts and switching shortcut.")
            registerInSearch: false

            DialogButton {
                buttonText: KeyboardSettings.applying ? Translation.tr("Applying…") : Translation.tr("Apply")
                enabled: !KeyboardSettings.applying && root.draftLayouts.length > 0
                colBackground: Appearance.colors.colPrimary
                colText: Appearance.colors.colOnPrimary
                onClicked: root.applyLayouts()
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Layout switching")

        SettingsRow {
            icon: "swap_horiz"
            title: Translation.tr("Shortcut")
            description: KeyboardSettings.switchLabel(root.draftGroupOption ? root.draftGroupOption : KeyboardSettings.optionsString)

            StyledComboBox {
                textRole: "label"
                model: [{ label: Translation.tr("Custom"), option: "" }].concat(KeyboardSettings.switchChoices)
                currentIndex: {
                    const option = root.draftGroupOption;
                    const index = model.findIndex(item => item.option === option);
                    return index >= 0 ? index : 0;
                }
                onActivated: index => {
                    root.draftGroupOption = model[index].option;
                    root.markDirty();
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Keyboards")
        visible: KeyboardSettings.keyboards.filter(keyboard => keyboard.main || !/^(video-bus|power-button|asus-wmi-hotkeys|keyd|ydotoold|.*avrcp)/i.test(keyboard.name)).length > 0

        Repeater {
            model: KeyboardSettings.keyboards.filter(keyboard => keyboard.main || !/^(video-bus|power-button|asus-wmi-hotkeys|keyd|ydotoold|.*avrcp)/i.test(keyboard.name))
            SettingsRow {
                required property var modelData
                icon: "keyboard"
                title: modelData.name
                description: modelData.main ? Translation.tr("Main keyboard") : Translation.tr("Keyboard device")
                registerInSearch: false
            }
        }
    }
}
