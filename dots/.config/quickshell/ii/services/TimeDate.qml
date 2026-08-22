pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Event-driven, small wrapper around systemd-timedated.
 *
 * Quickshell does not expose a generic timedated DBus client. The monitor is
 * a single gdbus signal stream (not a polling loop); point-in-time reads and
 * writes are performed only when the service starts or an operation occurs.
 */
Singleton {
    id: root

    readonly property string service: "org.freedesktop.timedate1"
    readonly property string objectPath: "/org/freedesktop/timedate1"
    readonly property string interfaceName: "org.freedesktop.timedate1"

    property string timezone: ""
    property bool ntpEnabled: false
    property bool ntpSynchronized: false
    property list<string> availableTimezones: []
    property bool ready: false
    property bool operationPending: false
    property string error: ""
    property bool timezonesLoaded: false

    signal operationFailed(string reason)

    function parseProperty(text, type) {
        const match = String(text ?? "").match(/\s(?:s|b)\s+(?:"([^"]*)"|(true|false))/);
        if (!match) return null;
        return type === "bool" ? match[2] === "true" : match[1] ?? "";
    }

    function refreshState() {
        timezoneProc.running = true;
        ntpProc.running = true;
        syncProc.running = true;
    }

    function fail(message) {
        root.error = message;
        root.operationPending = false;
        root.operationFailed(message);
    }

    function startOperation(command) {
        if (operationProc.running) return false;
        root.error = "";
        root.operationPending = true;
        operationProc.command = command;
        operationProc.running = true;
        return true;
    }

    function setNtp(enabled) {
        return startOperation(["busctl", "--system", "call", service, objectPath, interfaceName,
            "SetNTP", "bb", enabled ? "true" : "false", "true"]);
    }

    function setTimezone(name) {
        if (!availableTimezones.includes(name)) {
            fail("That timezone is not available.");
            return false;
        }
        return startOperation(["busctl", "--system", "call", service, objectPath, interfaceName,
            "SetTimezone", "sb", name, "true"]);
    }

    // epochMilliseconds is a local-time Date converted by JavaScript to UTC;
    // timedated expects absolute UTC microseconds when relative=false.
    function setDateTime(epochMilliseconds) {
        if (!Number.isFinite(epochMilliseconds)) {
            fail("The selected date and time are invalid.");
            return false;
        }
        return startOperation(["busctl", "--system", "call", service, objectPath, interfaceName,
            "SetTime", "xbb", String(Math.round(epochMilliseconds * 1000)), "false", "true"]);
    }

    Process {
        id: timezoneProc
        command: ["busctl", "--system", "get-property", root.service, root.objectPath, root.interfaceName, "Timezone"]
        stdout: StdioCollector { onStreamFinished: root.timezone = root.parseProperty(text, "string") ?? root.timezone }
        onExited: (code) => { if (code !== 0) root.fail("Could not read the system timezone."); }
    }

    Process {
        id: ntpProc
        command: ["busctl", "--system", "get-property", root.service, root.objectPath, root.interfaceName, "NTP"]
        stdout: StdioCollector { onStreamFinished: root.ntpEnabled = root.parseProperty(text, "bool") ?? root.ntpEnabled }
        onExited: (code) => { if (code !== 0) root.fail("Could not read automatic time state."); }
    }

    Process {
        id: syncProc
        command: ["busctl", "--system", "get-property", root.service, root.objectPath, root.interfaceName, "NTPSynchronized"]
        stdout: StdioCollector { onStreamFinished: root.ntpSynchronized = root.parseProperty(text, "bool") ?? root.ntpSynchronized }
        onExited: (code) => { if (code === 0) root.ready = true; else root.fail("Could not read synchronization state."); }
    }

    Process {
        id: timezoneListProc
        command: ["busctl", "--system", "call", root.service, root.objectPath, root.interfaceName, "ListTimezones"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = [];
                const expression = /"([^"]+)"/g;
                let match;
                while ((match = expression.exec(text)) !== null)
                    values.push(match[1]);
                root.availableTimezones = values;
                root.timezonesLoaded = values.length > 0;
            }
        }
        onExited: (code) => { if (code !== 0) root.fail("Could not load available timezones."); }
    }

    Process {
        id: operationProc
        property string operationOutput: ""
        stdout: StdioCollector { onStreamFinished: operationProc.operationOutput = text }
        onExited: (code) => {
            root.operationPending = false;
            if (code !== 0) {
                root.fail(operationProc.operationOutput.trim() || "The system time operation was denied or failed.");
                root.refreshState();
                return;
            }
            root.error = "";
            root.refreshState();
        }
    }

    // gdbus monitor is a single signal subscription, not a polling process.
    Process {
        id: signalMonitor
        command: ["gdbus", "monitor", "--system", "--dest", root.service, "--object-path", root.objectPath]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PropertiesChanged"))
                    root.refreshState();
            }
        }
        stderr: SplitParser { onRead: line => {} }
        running: true
    }

    Component.onCompleted: {
        refreshState();
        timezoneListProc.running = true;
    }
}
