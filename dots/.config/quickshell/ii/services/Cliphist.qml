pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // property string cliphistBinary: FileUtils.trimFileProtocol(`${Directories.home}/.cargo/bin/stash`)
    property string cliphistBinary: "cliphist"
    property real pasteDelay: 0.05
    property string pressPasteCommand: "ydotool key -d 1 29:1 47:1 47:0 29:0"
    property bool sloppySearch: Config.options?.search.sloppy ?? false
    property real scoreThreshold: 0.2
    property list<string> entries: []
    // cliphist's default follows its own XDG resolution; on this setup it is
    // the conventional user cache rather than the shell's redirected cache.
    readonly property string databasePath: FileUtils.trimFileProtocol(`${Directories.home}/.cache/cliphist/db`)
    property bool available: true
    property string error: ""
    property int revision: 0
    property bool refreshPending: false
    readonly property var preparedEntries: entries.map(a => ({
        name: Fuzzy.prepare(`${a.replace(/^\s*\S+\s+/, "")}`),
        entry: a
    }))
    function fuzzyQuery(search: string): var {
        if (search.trim() === "") {
            return entries;
        }
        if (root.sloppySearch) {
            const results = entries.slice(0, 100).map(str => ({
                entry: str,
                score: Levendist.computeTextMatchScore(str.toLowerCase(), search.toLowerCase())
            })).filter(item => item.score > root.scoreThreshold)
                .sort((a, b) => b.score - a.score)
            return results
                .map(item => item.entry)
        }

        return Fuzzy.go(search, preparedEntries, {
            all: true,
            key: "name"
        }).map(r => {
            return r.obj.entry
        });
    }

    function entryIsImage(entry) {
        return !!(/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(entry))
    }

    function refresh() {
        if (readProc.running) {
            root.refreshPending = true;
            return;
        }
        readProc.buffer = []
        readProc.running = true
    }

    function copy(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy`]);
        }
    }

    function paste(entry) {
        if (root.cliphistBinary.includes("cliphist")) // Classic cliphist
            Quickshell.execDetached(["bash", "-c", `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && wl-paste`]);
        else { // Stash
            const entryNumber = entry.split("\t")[0];
            Quickshell.execDetached(["bash", "-c", `${root.cliphistBinary} decode ${entryNumber} | wl-copy; ${root.pressPasteCommand}`]);
        }
    }

    function superpaste(count, isImage = false) {
        // Find entries
        const targetEntries = entries.filter(entry => {
            if (!isImage) return true;
            return entryIsImage(entry);
        }).slice(0, count)
        const pasteCommands = [...targetEntries].reverse().map(entry => `printf '${StringUtils.shellSingleQuoteEscape(entry)}' | ${root.cliphistBinary} decode | wl-copy && sleep ${root.pasteDelay} && ${root.pressPasteCommand}`)
        // Act
        Quickshell.execDetached(["bash", "-c", pasteCommands.join(` && sleep ${root.pasteDelay} && `)]);
    }

    Process {
        id: deleteProc
        property string commandEntry: ""
        command: [root.cliphistBinary, "delete"]
        stdinEnabled: false
        function deleteEntry(entry) {
            deleteProc.commandEntry = entry;
            deleteProc.stdinEnabled = true;
            deleteProc.running = true;
        }
        onRunningChanged: {
            if (deleteProc.running) {
                deleteProc.write(`${deleteProc.commandEntry}\n`);
                deleteProc.stdinEnabled = false;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.error = "";
                root.refresh();
            } else {
                root.error = "Could not delete that clipboard item.";
            }
            deleteProc.commandEntry = "";
        }
    }

    function deleteEntry(entry) {
        deleteProc.deleteEntry(entry);
    }

    // UI callers use the numeric cliphist id; serialized entries stay inside
    // the canonical backend rather than becoming a second page-local model.
    function deleteById(id) {
        const entry = root.entries.find(value => String(value).split("\t")[0] === String(id));
        if (entry === undefined) {
            root.error = "Clipboard item is no longer available.";
            return false;
        }
        deleteProc.deleteEntry(entry);
        return true;
    }

    Process {
        id: wipeProc
        command: [root.cliphistBinary, "wipe"]
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.error = "";
                root.refresh();
            } else {
                root.error = "Could not clear clipboard history.";
            }
        }
    }

    function wipe() {
        wipeProc.running = true;
    }

    Connections {
        target: Quickshell
        function onClipboardTextChanged() {
            delayedUpdateTimer.restart()
        }
    }

    Timer {
        id: delayedUpdateTimer
        interval: Config.options.hacks.arbitraryRaceConditionDelay
        repeat: false
        onTriggered: {
            root.refresh()
        }
    }

    Process {
        id: readProc
        property list<string> buffer: []

        command: [root.cliphistBinary, "list"]

        stdout: SplitParser {
            onRead: (line) => {
                readProc.buffer.push(line)
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.available = true;
                root.error = "";
                root.entries = readProc.buffer
                root.revision++;
            } else {
                root.available = false;
                root.error = "Clipboard history is unavailable.";
                console.error("[Cliphist] Failed to refresh with code", exitCode, "and status", exitStatus)
            }
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    IpcHandler {
        target: "cliphistService"

        function update(): void {
            root.refresh()
        }
    }
}
