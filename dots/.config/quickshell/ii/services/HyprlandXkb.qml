pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

/**
 * Exposes the active Hyprland Xkb keyboard layout name and code for indicators.
 */
Singleton {
    id: root
    // You can read these
    property list<string> layoutCodes: []
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    // For the service
    property var baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"
    property bool needsLayoutRefresh: false

    // Caps/Num Lock: Hyprland has no IPC event for these. Both inotify
    // (FileView watchChanges) and udev (confirmed by hand: no event at all,
    // even for a plain userspace write to this exact LED node) are
    // unreliable here, and periodic sysfs polling — even at 1s — adds a
    // real, perceptible delay before the indicator reflects the key you
    // just pressed. What actually fires immediately and unconditionally is
    // the kernel's own input-core LED event (EV_LED on the keyboard's
    // /dev/input/eventN) — that's the same primitive `xset led` / any DE's
    // caps lock indicator relies on, sub-millisecond, and zero-cost while
    // idle since reading it is a blocking read, not a timer. Falls back to
    // polling hyprctl only if no such device is found at all (e.g. a
    // Bluetooth keyboard with no exposed LED device node).
    property bool capsLockOn: false
    property bool numLockOn: false

    property var capsLockLedPaths: []
    property var numLockLedPaths: []
    property var capsLockLedStates: ({}) // key -> bool, OR'd together
    property var numLockLedStates: ({})
    property list<string> ledEventDevices: [] // deduped /dev/input/eventN paths to listen on

    function recomputeCapsLock() {
        root.capsLockOn = Object.values(root.capsLockLedStates).some(v => v);
    }
    function recomputeNumLock() {
        root.numLockOn = Object.values(root.numLockLedStates).some(v => v);
    }

    Process {
        id: findLedNodesProc
        running: true
        // For each capslock/numlock LED sysfs node, also resolve the
        // /dev/input/eventN that owns it (the LED's realpath is
        // .../inputN/inputN::capslock, and eventN sits right alongside it
        // under .../inputN/) - that's the device we can read EV_LED events
        // from directly, instead of polling the LED brightness file itself.
        command: ["bash", "-c", `
            for p in /sys/class/leds/*capslock*/brightness /sys/class/leds/*numlock*/brightness; do
                [ -f "$p" ] || continue
                d=$(dirname "$(readlink -f "$(dirname "$p")")")
                ev=$(ls "$d" 2>/dev/null | grep -m1 '^event')
                [ -n "$ev" ] && echo "$p|/dev/input/$ev"
            done
        `]

        stdout: StdioCollector {
            id: ledNodesCollector
            onStreamFinished: {
                const lines = ledNodesCollector.text.trim().split("\n").filter(l => l.length > 0);
                const capsPaths = [], numPaths = [], devices = {};
                for (const line of lines) {
                    const [ledPath, evDevice] = line.split("|");
                    if (/capslock/i.test(ledPath)) capsPaths.push(ledPath);
                    if (/numlock/i.test(ledPath)) numPaths.push(ledPath);
                    if (evDevice) devices[evDevice] = true;
                }
                root.capsLockLedPaths = capsPaths;
                root.numLockLedPaths = numPaths;
                root.ledEventDevices = Object.keys(devices);

                // No sysfs LED (and so no event device) found at all - fall back to polling hyprctl.
                if (root.ledEventDevices.length === 0) {
                    lockStatePollTimer.running = true;
                }
            }
        }
    }

    // One persistent, blocking reader per physical/virtual keyboard device -
    // evtest prints the device's current LED state immediately on startup
    // ("... state 1"), then one line per subsequent real change ("Event: ...
    // type 17 (EV_LED), code N (LED_X), value V"). Both forms match the
    // same regex below, so this alone provides the initial state AND every
    // live change - no separate poll or file read needed either way.
    // grep filters server-side: this device also reports every ordinary
    // keystroke (evtest dumps ALL of that device's events, not just LEDs),
    // and without the filter every key the user types anywhere would still
    // reach QML only to be discarded there - cheap per line, but needless
    // when a single `grep` avoids ever crossing the process boundary for it.
    Instantiator {
        id: ledEventReaders
        model: root.ledEventDevices
        delegate: Process {
            id: ledEventReader
            required property string modelData
            running: true
            command: ["bash", "-c", `evtest ${StringUtils.shellSingleQuoteEscape(modelData)} | grep --line-buffered -E 'LED_(CAPSL|NUML)'`]
            stdout: SplitParser {
                onRead: line => {
                    const m = line.match(/\(LED_(CAPSL|NUML)\).*?(?:state|value) (\d+)/);
                    if (!m) return;
                    const value = m[2] === "1";
                    if (m[1] === "CAPSL") {
                        root.capsLockLedStates[ledEventReader.modelData] = value;
                        root.recomputeCapsLock();
                    } else {
                        root.numLockLedStates[ledEventReader.modelData] = value;
                        root.recomputeNumLock();
                    }
                }
            }
        }
    }

    // Fallback only — started when sysfs discovery above finds nothing to watch.
    Timer {
        id: lockStatePollTimer
        interval: 500
        running: false
        repeat: true
        onTriggered: pollLockStateProc.running = true
    }

    Process {
        id: pollLockStateProc
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: lockStateCollector
            onStreamFinished: {
                const parsedOutput = JSON.parse(lockStateCollector.text);
                const hyprlandKeyboard = parsedOutput["keyboards"]?.find(kb => kb.main === true);
                if (hyprlandKeyboard) {
                    root.capsLockOn = !!hyprlandKeyboard.capsLock;
                    root.numLockOn = !!hyprlandKeyboard.numLock;
                }
            }
        }
    }

    // Update the layout code according to the layout name (Hyprland gives the name not the code)
    onCurrentLayoutNameChanged: root.updateLayoutCode()
    function updateLayoutCode() {
        if (cachedLayoutCodes.hasOwnProperty(currentLayoutName)) {
            root.currentLayoutCode = cachedLayoutCodes[currentLayoutName];
        } else {
            getLayoutProc.running = true;
        }
    }

    // Get the layout code from the base.lst file by grabbing the line with the current layout name
    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector

            onStreamFinished: {
                const lines = layoutCollector.text.split("\n");
                const targetDescription = root.currentLayoutName;
                const foundLine = lines.find(line => {
                    // Skip comment lines and empty lines
                    if (!line.trim() || line.trim().startsWith('!'))
                        return false;

                    // Match layout: (whitespace + ) key + whitespace + description
                    const matchLayout = line.match(/^\s*(\S+)\s+(.+)$/);
                    if (matchLayout && matchLayout[2] === targetDescription) {
                        root.cachedLayoutCodes[matchLayout[2]] = matchLayout[1];
                        root.currentLayoutCode = matchLayout[1];
                        return true;
                    }

                    // Match variant: (whitespace + ) variant + whitespace + key + whitespace + description
                    const matchVariant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/);
                    if (matchVariant && matchVariant[3] === targetDescription) {
                        const complexLayout = matchVariant[2] + matchVariant[1];
                        root.cachedLayoutCodes[matchVariant[3]] = complexLayout;
                        root.currentLayoutCode = complexLayout;
                        return true;
                    }
                    
                    return false;
                });
                // console.log("[HyprlandXkb] Found line:", foundLine);
                // console.log("[HyprlandXkb] Layout:", root.currentLayoutName, "| Code:", root.currentLayoutCode);
                // console.log("[HyprlandXkb] Cached layout codes:", JSON.stringify(root.cachedLayoutCodes, null, 2));
            }
        }
    }

    // Find out available layouts and current active layout. Should only be necessary on init
    Process {
        id: fetchLayoutsProc
        running: true
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: devicesCollector
            onStreamFinished: {
                const parsedOutput = JSON.parse(devicesCollector.text);
                const hyprlandKeyboard = parsedOutput["keyboards"].find(kb => kb.main === true);
                root.layoutCodes = hyprlandKeyboard["layout"].split(",");
                root.currentLayoutName = hyprlandKeyboard["active_keymap"];
                // console.log("[HyprlandXkb] Fetched | Layouts (multiple: " + (root.layoutCodes.length > 1) + "): "
                //     + root.layoutCodes.join(", ") + " | Active: " + root.currentLayoutName);
            }
        }
    }

    // Update the layout name when it changes
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout") {
                if (root.needsLayoutRefresh) {
                    root.needsLayoutRefresh = false;
                    fetchLayoutsProc.running = true;
                }

                // If there's only one layout, the updated layout is always the same
                if (root.layoutCodes.length <= 1) return;

                // Update when layout might have changed
                const dataString = event.data;
                root.currentLayoutName = dataString.substring(dataString.indexOf(",") + 1);

                // Update layout for on-screen keyboard (osk)
                Config.options.osk.layout = root.currentLayoutName.split(" (")[0];
            } else if (event.name == "configreloaded") {
                // Mark layout code list to be updated when config is reloaded
                root.needsLayoutRefresh = true;
            }
        }
    }
}
