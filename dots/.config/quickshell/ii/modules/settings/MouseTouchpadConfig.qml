import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property real sensitivityDraft: PointerSettings.sensitivity
    property real scrollFactorDraft: PointerSettings.touchpadScrollFactor
    property bool sensitivityPending: false
    property bool scrollFactorPending: false
    property bool sensitivityDragging: false
    property bool scrollFactorDragging: false

    // Dragging only edits a local draft. Commit once on release, not after a
    // brief pause mid-drag. Keyboard steps have no pressed state, so they are
    // committed immediately from onMoved below.
    function commitSensitivity() {
        root.sensitivityPending = true;
        root.flushPendingChanges();
    }
    function commitScrollFactor() {
        root.scrollFactorPending = true;
        root.flushPendingChanges();
    }
    function flushPendingChanges() {
        if (PointerSettings.applying)
            return;
        if (root.sensitivityPending) {
            root.sensitivityPending = false;
            PointerSettings.applyField("sensitivity", Math.round(root.sensitivityDraft * 20) / 20);
            return;
        }
        if (root.scrollFactorPending) {
            root.scrollFactorPending = false;
            PointerSettings.applyField("touchpad_scroll_factor", Math.round(root.scrollFactorDraft * 20) / 20);
        }
    }

    Connections {
        target: PointerSettings
        function onStateChanged() {
            if (!root.sensitivityPending) root.sensitivityDraft = PointerSettings.sensitivity;
            if (!root.scrollFactorPending) root.scrollFactorDraft = PointerSettings.touchpadScrollFactor;
        }
        function onApplyingChanged() {
            if (!PointerSettings.applying)
                root.flushPendingChanges();
        }
    }

    SettingsGroup {
        title: Translation.tr("Pointer")

        SettingsRow {
            icon: "speed"
            title: Translation.tr("Pointer speed")
            description: `${root.sensitivityDraft.toFixed(2)}`

            RowLayout {
                width: 300
                StyledSlider {
                    Layout.fillWidth: true
                    // Disabling a focused Slider clears its focus. Writes are
                    // committed below, so keep it usable while they complete.
                    enabled: PointerSettings.ready
                    from: -1
                    to: 1
                    stepSize: 0.05
                    value: root.sensitivityDraft
                    usePercentTooltip: false
                    tooltipDecimalPlaces: 2
                    onMoved: {
                        root.sensitivityDraft = Math.max(-1, Math.min(1, Math.round(value * 20) / 20));
                        if (!pressed) root.commitSensitivity();
                    }
                    onPressedChanged: {
                        if (pressed)
                            root.sensitivityDragging = true;
                        else if (root.sensitivityDragging) {
                            root.sensitivityDragging = false;
                            root.commitSensitivity();
                        }
                    }
                }
            }
        }

        SettingsRow {
            icon: "tune"
            title: Translation.tr("Acceleration")
            description: PointerSettings.accelProfile === "flat" ? Translation.tr("Flat") : Translation.tr("Adaptive")

            StyledComboBox {
                width: 180
                model: [Translation.tr("Adaptive"), Translation.tr("Flat")]
                currentIndex: PointerSettings.accelProfile === "flat" ? 1 : 0
                enabled: PointerSettings.ready && !PointerSettings.applying
                onActivated: index => PointerSettings.applyField("accel_profile", index === 1 ? "flat" : "adaptive")
            }
        }

        SettingsToggleRow {
            icon: "swap_vert"
            title: Translation.tr("Natural scrolling")
            description: Translation.tr("Reverse scrolling direction for pointer devices.")
            checked: PointerSettings.naturalScroll
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("natural_scroll", checked)
        }
    }

    SettingsGroup {
        visible: PointerSettings.hasTouchpad
        title: Translation.tr("Touchpad")

        SettingsToggleRow {
            icon: "swap_vert"
            title: Translation.tr("Natural scrolling")
            checked: PointerSettings.touchpadNaturalScroll
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("touchpad_natural_scroll", checked)
        }
        SettingsToggleRow {
            icon: "touch_app"
            title: Translation.tr("Tap to click")
            checked: PointerSettings.touchpadTapToClick
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("touchpad_tap_to_click", checked)
        }
        SettingsToggleRow {
            icon: "pan_tool"
            title: Translation.tr("Tap and drag")
            checked: PointerSettings.touchpadTapAndDrag
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("touchpad_tap_and_drag", checked)
        }
        SettingsToggleRow {
            icon: "back_hand"
            title: Translation.tr("Disable while typing")
            checked: PointerSettings.touchpadDisableWhileTyping
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("touchpad_disable_while_typing", checked)
        }
        SettingsRow {
            icon: "ads_click"
            title: Translation.tr("Click method")
            description: PointerSettings.touchpadClickfingerBehavior ? Translation.tr("Finger position") : Translation.tr("Button areas")
            StyledComboBox {
                width: 190
                model: [Translation.tr("Finger position"), Translation.tr("Button areas")]
                currentIndex: PointerSettings.touchpadClickfingerBehavior ? 0 : 1
                enabled: PointerSettings.ready && !PointerSettings.applying
                onActivated: index => PointerSettings.applyField("touchpad_clickfinger_behavior", index === 0)
            }
        }
        SettingsToggleRow {
            icon: "mouse"
            title: Translation.tr("Middle-button emulation")
            checked: PointerSettings.touchpadMiddleButtonEmulation
            enabled: PointerSettings.ready && !PointerSettings.applying
            onToggled: checked => PointerSettings.applyField("touchpad_middle_button_emulation", checked)
        }
        SettingsRow {
            icon: "unfold_more"
            title: Translation.tr("Scroll speed")
            description: `${root.scrollFactorDraft.toFixed(2)}`
            RowLayout {
                width: 300
                StyledSlider {
                    Layout.fillWidth: true
                    enabled: PointerSettings.ready
                    from: 0.2
                    to: 2
                    stepSize: 0.05
                    value: root.scrollFactorDraft
                    usePercentTooltip: false
                    tooltipDecimalPlaces: 2
                    onMoved: {
                        root.scrollFactorDraft = Math.max(0.2, Math.min(2, Math.round(value * 20) / 20));
                        if (!pressed) root.commitScrollFactor();
                    }
                    onPressedChanged: {
                        if (pressed)
                            root.scrollFactorDragging = true;
                        else if (root.scrollFactorDragging) {
                            root.scrollFactorDragging = false;
                            root.commitScrollFactor();
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: Translation.tr("Devices")
        Repeater {
            model: PointerSettings.userDevices
            SettingsRow {
                required property var modelData
                icon: modelData.type === "Touchpad" ? "touchpad_mouse" : "mouse"
                title: modelData.name
                description: modelData.type
                registerInSearch: false
            }
        }
        SettingsRow {
            visible: PointerSettings.error.length > 0
            icon: "error"
            title: Translation.tr("Pointer settings unavailable")
            description: PointerSettings.error
            registerInSearch: false
        }
    }
}
