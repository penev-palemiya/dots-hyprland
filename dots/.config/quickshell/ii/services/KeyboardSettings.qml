pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

/** Authoritative Hyprland keyboard policy for Devices → Keyboard. */
Singleton {
    id: root

    readonly property string helperPath: FileUtils.trimFileProtocol(`${Directories.config}/quickshell/ii/scripts/hyprland/keyboard_settings.py`)
    readonly property list<var> switchChoices: [
        { label: "Alt + Space", option: "grp:alt_space_toggle" },
        { label: "Super + Space", option: "grp:win_space_toggle" },
        { label: "Ctrl + Space", option: "grp:ctrl_space_toggle" },
        { label: "Alt + Shift", option: "grp:alt_shift_toggle" },
        { label: "Ctrl + Shift", option: "grp:ctrl_shift_toggle" },
        { label: "Caps Lock", option: "grp:caps_toggle" }
    ]

    property list<var> layoutCatalog: []
    property list<var> keyboards: []
    property var state: ({})
    property bool ready: false
    property bool applying: false
    property string error: ""
    signal applied(bool success)

    readonly property string layoutString: String(root.state.kb_layout || "")
    readonly property string variantString: String(root.state.kb_variant || "")
    readonly property string optionsString: String(root.state.kb_options || "")
    readonly property int repeatDelay: Number(root.state.repeat_delay || 250)
    readonly property int repeatRate: Number(root.state.repeat_rate || 35)
    readonly property bool numlockByDefault: Boolean(root.state.numlock_by_default)
    readonly property var mainKeyboard: root.keyboards.find(keyboard => keyboard.main) || root.keyboards[0] || null
    readonly property string mainKeyboardName: root.mainKeyboard?.name || ""
    readonly property string mainKeyboardLayout: root.mainKeyboard?.active_keymap || ""

    function layoutEntries() {
        const layouts = root.layoutString.split(",");
        const variants = root.variantString.split(",");
        return layouts.filter(layout => layout.length > 0).map((layout, index) => {
            const variant = variants[index] || "";
            const found = root.layoutCatalog.find(item => item.layout === layout);
            return { layout, variant, displayName: found?.displayName || layout };
        });
    }

    function groupOption(options = root.optionsString) {
        return String(options || "").split(",").map(value => value.trim()).find(value => value.startsWith("grp:")) || "";
    }

    function switchLabel(options = root.optionsString) {
        const option = root.groupOption(options);
        return root.switchChoices.find(choice => choice.option === option)?.label || (option ? "Custom" : "Not set");
    }

    function nonGroupOptions(options) {
        return String(options || "").split(",").map(value => value.trim()).filter(value => value.length > 0 && !value.startsWith("grp:"));
    }

    function composeOptions(nonGroups, group) {
        const values = (nonGroups || []).filter(value => value && !String(value).startsWith("grp:"));
        if (group) values.push(group);
        return values.join(",");
    }

    function refresh() {
        if (!stateProc.running) stateProc.running = true;
        if (!catalogProc.running && root.layoutCatalog.length === 0) catalogProc.running = true;
        if (!deviceProc.running) deviceProc.running = true;
    }

    function applyState(nextState) {
        if (root.applying) return false;
        root.error = "";
        root.applying = true;
        applyProc.command = ["python3", root.helperPath, "--apply", JSON.stringify(nextState)];
        applyProc.running = true;
        return true;
    }

    Process {
        id: stateProc
        command: ["python3", root.helperPath, "--state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); root.ready = true; }
                catch (exception) { root.error = "Could not read Hyprland keyboard settings."; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) root.error = text.trim() }
        onExited: code => { if (code !== 0) root.error = root.error || "Could not read Hyprland keyboard settings."; }
    }

    Process {
        id: catalogProc
        command: ["python3", root.helperPath, "--catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.layoutCatalog = JSON.parse(text); }
                catch (exception) { root.error = "Could not load XKB layouts."; }
            }
        }
    }

    Process {
        id: deviceProc
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.keyboards = JSON.parse(text).keyboards || []; }
                catch (exception) { root.keyboards = []; }
            }
        }
    }

    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.state = JSON.parse(text); }
                catch (exception) { if (text.trim().length > 0) root.error = text.trim(); }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim().length > 0) root.error = text.trim() }
        onExited: code => {
            root.applying = false;
            if (code !== 0 && root.error.length === 0) root.error = "Hyprland rejected the keyboard settings.";
            root.applied(code === 0);
            if (code === 0) root.refresh();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") root.deviceProc.running = true;
            else if (event.name === "configreloaded") root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
