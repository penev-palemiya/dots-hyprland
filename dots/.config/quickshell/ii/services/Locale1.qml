pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/** Event-driven wrapper for systemd-localed's org.freedesktop.locale1. */
Singleton {
    id: root

    readonly property string service: "org.freedesktop.locale1"
    readonly property string objectPath: "/org/freedesktop/locale1"
    readonly property string interfaceName: "org.freedesktop.locale1"

    property list<string> locale: []
    property list<string> availableLocales: []
    readonly property string languageLocale: root.locale.find(entry => entry.startsWith("LANG="))?.substring(5) ?? ""
    readonly property string messageLocale: root.locale.find(entry => entry.startsWith("LC_MESSAGES="))?.substring(12) ?? ""
    property bool ready: false
    property bool operationPending: false
    property string error: ""

    signal operationFailed(string reason)

    function normalizeLocale(value) {
        return String(value ?? "").replace(/\.utf8$/i, ".UTF-8");
    }

    function friendlyName(value) {
        const normalized = normalizeLocale(value);
        if (normalized === "C" || normalized === "C.UTF-8" || normalized === "POSIX")
            return "C / POSIX";
        const locale = Qt.locale(normalized.replace("-", "_"));
        if (!locale || locale.name === "C") return normalized;
        const language = locale.nativeLanguageName || normalized;
        const territory = locale.nativeTerritoryName;
        return territory ? `${language} (${territory})` : language;
    }

    function refresh() {
        localeProc.running = true;
    }

    function fail(message) {
        root.error = message;
        root.operationPending = false;
        root.operationFailed(message);
    }

    function setLocale(value) {
        const normalized = normalizeLocale(value);
        if (!root.availableLocales.includes(normalized)) {
            fail("That locale is not installed.");
            return false;
        }

        // Change LANG while preserving explicit category overrides such as
        // LC_MESSAGES=en_US.UTF-8. Never introduce LC_ALL here.
        const entries = root.locale.filter(entry => !entry.startsWith("LANG="));
        entries.unshift(`LANG=${normalized}`);
        root.error = "";
        root.operationPending = true;
        operationProc.command = ["busctl", "--system", "call", root.service, root.objectPath,
            root.interfaceName, "SetLocale", "asb", String(entries.length), ...entries, "true"];
        operationProc.running = true;
        return true;
    }

    Process {
        id: localeProc
        command: ["busctl", "--system", "get-property", root.service, root.objectPath, root.interfaceName, "Locale"]
        stdout: StdioCollector {
            onStreamFinished: {
                const values = [];
                const expression = /"([^"]*)"/g;
                let match;
                while ((match = expression.exec(text)) !== null)
                    values.push(match[1]);
                root.locale = values;
                root.ready = true;
            }
        }
        onExited: code => { if (code !== 0) root.fail("Could not read the system locale."); }
    }

    Process {
        id: installedLocalesProc
        command: ["locale", "-a"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.availableLocales = text.split("\\n")
                    .map(value => root.normalizeLocale(value.trim()))
                    .filter(value => value.length > 0);
            }
        }
        onExited: code => { if (code !== 0) root.fail("Could not enumerate installed locales."); }
    }

    Process {
        id: operationProc
        property string operationOutput: ""
        stdout: StdioCollector { onStreamFinished: operationProc.operationOutput = text }
        onExited: code => {
            root.operationPending = false;
            if (code !== 0) {
                root.fail(operationProc.operationOutput.trim() || "The system locale operation was denied or failed.");
                root.refresh();
                return;
            }
            root.error = "";
            root.refresh();
        }
    }

    Process {
        id: signalMonitor
        command: ["gdbus", "monitor", "--system", "--dest", root.service, "--object-path", root.objectPath]
        stdout: SplitParser {
            onRead: line => {
                if (line.includes("PropertiesChanged"))
                    root.refresh();
            }
        }
        stderr: SplitParser { onRead: line => {} }
        running: true
    }

    Component.onCompleted: {
        refresh();
        installedLocalesProc.running = true;
    }
}
