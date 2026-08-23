import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.components

SettingsSubPage {
    id: root

    property string query: ""
    property string category: "All"

    readonly property var categoryOrder: ["Shell", "Utilities", "Screen", "Media", "Window", "Workspace", "Session", "App", "Other"]
    readonly property var categoryLabels: ({
        "Shell": Translation.tr("Shell"),
        "Utilities": Translation.tr("Utilities"),
        "Screen": Translation.tr("Screen"),
        "Media": Translation.tr("Media"),
        "Window": Translation.tr("Windows"),
        "Workspace": Translation.tr("Workspaces"),
        "Session": Translation.tr("Session"),
        "App": Translation.tr("Applications"),
        "Other": Translation.tr("Other")
    })

    function categoryFor(bind) {
        const description = String(bind?.description ?? "");
        const prefix = description.split(":")[0];
        return categoryOrder.includes(prefix) ? prefix : "Other";
    }

    function displayDescription(bind) {
        const description = String(bind?.description ?? "");
        const prefix = description.split(":")[0];
        return categoryOrder.includes(prefix) ? description.slice(prefix.length + 1).trim() : (description || Translation.tr("Uncategorized binding"));
    }

    function keyLabel(key, keycode) {
        const labels = {
            "XF86AudioRaiseVolume": Translation.tr("Volume Up"),
            "XF86AudioLowerVolume": Translation.tr("Volume Down"),
            "XF86AudioMute": Translation.tr("Mute"),
            "XF86AudioMicMute": Translation.tr("Microphone Mute"),
            "XF86AudioPlay": Translation.tr("Play/Pause"),
            "XF86AudioPause": Translation.tr("Play/Pause"),
            "XF86AudioNext": Translation.tr("Next Track"),
            "XF86AudioPrev": Translation.tr("Previous Track"),
            "XF86MonBrightnessUp": Translation.tr("Brightness Up"),
            "XF86MonBrightnessDown": Translation.tr("Brightness Down"),
            "Print": Translation.tr("Print Screen"),
            "Return": Translation.tr("Enter"),
            "Slash": "/",
            "Period": ".",
            "Space": Translation.tr("Space"),
            "mouse:272": Translation.tr("Mouse Left"),
            "mouse:273": Translation.tr("Mouse Right"),
            "mouse:274": Translation.tr("Mouse Middle"),
            "mouse:275": Translation.tr("Mouse Back"),
            "mouse:276": Translation.tr("Mouse Forward"),
            // Hyprland reports these names opposite to the physical wheel
            // direction; keep the established Cheatsheet presentation.
            "mouse_up": Translation.tr("Scroll Down"),
            "mouse_down": Translation.tr("Scroll Up")
        };
        if (labels[key] !== undefined) return labels[key];
        if (String(key).startsWith("code:")) return Translation.tr("Keycode %1").arg(String(key).slice(5));
        return key || (keycode ? Translation.tr("Keycode %1").arg(keycode) : Translation.tr("Unspecified key"));
    }

    function chordFor(bind) {
        const modifiers = [];
        const mask = Number(bind?.modmask ?? 0);
        if (mask & (1 << 2)) modifiers.push(Translation.tr("Ctrl"));
        if (mask & (1 << 6)) modifiers.push(Translation.tr("Super"));
        if (mask & (1 << 0)) modifiers.push(Translation.tr("Shift"));
        if (mask & (1 << 3)) modifiers.push(Translation.tr("Alt"));
        if (mask & (1 << 1)) modifiers.push(Translation.tr("Caps"));
        const key = keyLabel(bind?.key, bind?.keycode);
        return modifiers.concat([key]).join(" + ");
    }

    function flagsFor(bind) {
        const flags = [];
        if (bind?.mouse) flags.push(Translation.tr("Mouse"));
        if (bind?.release) flags.push(Translation.tr("Release"));
        if (bind?.repeat) flags.push(Translation.tr("Repeat"));
        if (bind?.locked) flags.push(Translation.tr("Locked"));
        if (bind?.submap) flags.push(Translation.tr("Submap: %1").arg(bind.submap));
        return flags.join(" · ");
    }

    function normalizeSearch(value) {
        return String(value ?? "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
    }

    function matches(bind) {
        if (root.category !== "All" && categoryFor(bind) !== root.category) return false;
        const needle = root.normalizeSearch(root.query);
        if (!needle) return true;
        return root.normalizeSearch([displayDescription(bind), categoryLabels[categoryFor(bind)], chordFor(bind), bind?.key ?? ""]
            .join(" ")).includes(needle);
    }

    function filteredBinds() {
        return (HyprlandKeybinds.keybinds ?? []).filter(bind => root.matches(bind));
    }

    function categoriesForDisplay() {
        if (root.category !== "All") return [root.category];
        return root.categoryOrder.filter(category => filteredBinds().some(bind => categoryFor(bind) === category));
    }

    SettingsGroup {
        title: Translation.tr("SHORTCUTS")

        MaterialTextField {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Search shortcuts…")
            text: root.query
            onTextChanged: root.query = text
            onAccepted: focus = false
        }

        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: ["All"].concat(root.categoryOrder)
                RippleButton {
                    required property string modelData
                    text: modelData === "All" ? Translation.tr("All") : root.categoryLabels[modelData]
                    toggled: root.category === modelData
                    onClicked: root.category = modelData
                }
            }
        }

        StyledText {
            text: Translation.tr("Current keyboard and system shortcuts active in Hyprland.")
            color: Appearance.colors.colSubtext
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: root.categoriesForDisplay()
        SettingsGroup {
            required property string modelData
            title: root.categoryLabels[modelData]

            Repeater {
                model: (HyprlandKeybinds.keybinds ?? []).filter(bind => root.matches(bind) && root.categoryFor(bind) === modelData)
                SettingsRow {
                    required property var modelData
                    icon: "keyboard_command_key"
                    title: root.displayDescription(modelData)
                    description: root.flagsFor(modelData)
                    registerInSearch: false

                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: root.chordFor(modelData).split(" + ")
                            Rectangle {
                                required property string modelData
                                radius: 5
                                color: Appearance.colors.colLayer2
                                border.width: 1
                                border.color: Appearance.colors.colOutlineVariant
                                implicitWidth: keyText.implicitWidth + 14
                                implicitHeight: keyText.implicitHeight + 8
                                StyledText {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: Appearance.colors.colOnLayer2
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SettingsRow {
        visible: root.filteredBinds().length === 0
        icon: "search_off"
        title: Translation.tr("No shortcuts found")
        description: Translation.tr("Try another search or category.")
        registerInSearch: false
    }
}
