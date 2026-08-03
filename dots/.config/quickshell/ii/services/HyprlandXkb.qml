pragma Singleton

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common

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

    // Caps/Num Lock: Hyprland has no IPC event for these, but the kernel
    // exposes the keyboard LED state under sysfs, which FileView can watch
    // via inotify (watchChanges: true) — genuinely event-driven, no polling.
    // Some machines (no physical LED, some Bluetooth keyboards) don't expose
    // this node at all, so a `hyprctl -j devices` polling Timer is kept as a
    // fallback, only ever started if the sysfs discovery comes up empty.
    property bool capsLockOn: false
    property bool numLockOn: false

    property var capsLockLedPaths: []
    property var numLockLedPaths: []
    property var capsLockLedStates: ({}) // path -> bool, OR'd together
    property var numLockLedStates: ({})

    function recomputeCapsLock() {
        root.capsLockOn = Object.values(root.capsLockLedStates).some(v => v);
    }
    function recomputeNumLock() {
        root.numLockOn = Object.values(root.numLockLedStates).some(v => v);
    }

    Process {
        id: findLedNodesProc
        running: true
        // Plain bash globbing instead of `find -iname` — simpler, nothing to escape.
        // Unmatched patterns just print a suppressed "no such file" to stderr.
        command: ["bash", "-c", "ls -d /sys/class/leds/*capslock*/brightness /sys/class/leds/*numlock*/brightness 2>/dev/null"]

        stdout: StdioCollector {
            id: ledNodesCollector
            onStreamFinished: {
                const paths = ledNodesCollector.text.trim().split("\n").filter(l => l.length > 0);
                root.capsLockLedPaths = paths.filter(p => /capslock/i.test(p));
                root.numLockLedPaths = paths.filter(p => /numlock/i.test(p));

                // No sysfs LED exposed on this machine at all — fall back to polling hyprctl.
                if (root.capsLockLedPaths.length === 0 && root.numLockLedPaths.length === 0) {
                    lockStatePollTimer.running = true;
                }
            }
        }
    }

    Instantiator {
        id: capsLockInstantiator
        model: root.capsLockLedPaths
        delegate: FileView {
            id: capsLedFile
            required property string modelData
            path: modelData
            watchChanges: true // may not fire for kernel-driven LED changes on every driver — see sysfsPollTimer below
            onFileChanged: capsLedFile.refresh()
            Component.onCompleted: capsLedFile.refresh()
            function refresh() {
                reload();
                root.capsLockLedStates[modelData] = text().trim() === "1";
                root.recomputeCapsLock();
            }
        }
    }
    Instantiator {
        id: numLockInstantiator
        model: root.numLockLedPaths
        delegate: FileView {
            id: numLedFile
            required property string modelData
            path: modelData
            watchChanges: true
            onFileChanged: numLedFile.refresh()
            Component.onCompleted: numLedFile.refresh()
            function refresh() {
                reload();
                root.numLockLedStates[modelData] = text().trim() === "1";
                root.recomputeNumLock();
            }
        }
    }

    // Belt-and-suspenders: some LED drivers update the sysfs value without
    // calling sysfs_notify(), so inotify (watchChanges above) never fires
    // even though the file's content is correct if you just read it. This
    // re-reads the already-open sysfs files directly — no subprocess spawn.
    // Caps/Num Lock toggling from the keyboard itself normally does fire
    // inotify (or gets caught on the next keystroke either way), and no
    // udev event fires for this device on a plain write either - so this is
    // purely a periodic resync for the rare driver that skips sysfs_notify,
    // not a latency-sensitive path. 1s keeps correctness while cutting
    // wakeups ~5x versus the previous 200ms.
    Timer {
        interval: 1000
        running: root.capsLockLedPaths.length > 0 || root.numLockLedPaths.length > 0
        repeat: true
        onTriggered: {
            for (let i = 0; i < capsLockInstantiator.count; i++)
                capsLockInstantiator.objectAt(i).refresh();
            for (let i = 0; i < numLockInstantiator.count; i++)
                numLockInstantiator.objectAt(i).refresh();
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
