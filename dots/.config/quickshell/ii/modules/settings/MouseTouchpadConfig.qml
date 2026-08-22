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

    function scheduleSensitivity() { sensitivityPending = true; sensitivityTimer.restart(); }
    function scheduleScrollFactor() { scrollFactorPending = true; scrollFactorTimer.restart(); }

    Timer {
        id: sensitivityTimer
        interval: 300
        onTriggered: {
            root.sensitivityPending = false;
            PointerSettings.applyField("sensitivity", Math.round(root.sensitivityDraft * 20) / 20);
        }
    }
    Timer {
        id: scrollFactorTimer
        interval: 300
        onTriggered: {
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
                    enabled: PointerSettings.ready && !PointerSettings.applying
                    from: -1
                    to: 1
                    stepSize: 0.05
                    value: root.sensitivityDraft
                    usePercentTooltip: false
                    onMoved: {
                        root.sensitivityDraft = Math.max(-1, Math.min(1, Math.round(value * 20) / 20));
                        root.scheduleSensitivity();
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
                    enabled: PointerSettings.ready && !PointerSettings.applying
                    from: 0.2
                    to: 2
                    stepSize: 0.05
                    value: root.scrollFactorDraft
                    usePercentTooltip: false
                    onMoved: {
                        root.scrollFactorDraft = Math.max(0.2, Math.min(2, Math.round(value * 20) / 20));
                        root.scheduleScrollFactor();
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
