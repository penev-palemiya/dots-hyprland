import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * One independent "view" of the file explorer: a directory, its navigation
 * history, its search query, and its own selection. Instantiated per split
 * pane / per tab, rather than being a Singleton - the old services/
 * FileExplorer.qml held all of this as global state, which was fine for
 * "one window, one view" but breaks the moment two panes need to look at
 * different folders at once (split view) or two tabs need independent
 * back/forward history.
 *
 * services/FileExplorer.qml keeps only what is genuinely window-wide rather
 * than per-view: the copy/cut clipboard (copying in one pane and pasting in
 * another is the expected behaviour, not a bug) and openFile() (launching an
 * app isn't tied to any one pane's state). Everything else that used to live
 * there - directory, folderModel, selection, file operations that act on
 * "this pane's" selection - lives here instead.
 */
Item {
    id: root

    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: Qt.resolvedUrl(Directories.home)
    property alias folderModel: folderModel // Expose for direct binding when needed
    property string searchQuery: ""
    property list<string> entries: [] // List of absolute file paths (without file://)

    // Multi-selection - see the note on selectedPaths in the old
    // services/FileExplorer.qml (git history) for why this is a plain array
    // rather than a Set: QML property bindings only re-evaluate on property
    // CHANGE notifications, and reassigning to a new array fires one.
    // Mutating a Set in place wouldn't, so every read would silently see
    // stale membership until something else happened to touch the property.
    property list<string> selectedPaths: []
    // Anchor for Shift-range selection: the index Shift+click/arrow ranges
    // are measured from. -1 means no anchor is set yet.
    property int selectionAnchorIndex: -1

    function isSelected(path) {
        return root.selectedPaths.indexOf(path) !== -1;
    }

    function clearSelection() {
        if (root.selectedPaths.length === 0) return;
        root.selectedPaths = [];
        root.selectionAnchorIndex = -1;
    }

    // Plain click / Enter-activate: select exactly this one.
    function selectOnly(path, index) {
        root.selectedPaths = [path];
        root.selectionAnchorIndex = index;
    }

    // Ctrl+click: add if absent, remove if present, without disturbing the
    // rest of the selection.
    function toggleSelection(path, index) {
        const i = root.selectedPaths.indexOf(path);
        if (i === -1) {
            root.selectedPaths = [...root.selectedPaths, path];
        } else {
            const next = root.selectedPaths.slice();
            next.splice(i, 1);
            root.selectedPaths = next;
        }
        root.selectionAnchorIndex = index;
    }

    // Shift+click / Shift+arrow: replace the selection with the contiguous
    // range between the anchor and this index. Does NOT move the anchor -
    // repeated Shift+clicks extend/shrink from the same fixed point, matching
    // Nautilus/Explorer rather than accumulating a new anchor per click.
    function selectRange(index) {
        if (root.selectionAnchorIndex === -1) {
            root.selectionAnchorIndex = index;
        }
        const lo = Math.min(root.selectionAnchorIndex, index);
        const hi = Math.max(root.selectionAnchorIndex, index);
        const next = [];
        for (let i = lo; i <= hi; i++) {
            const path = folderModel.get(i, "filePath");
            if (path) next.push(path);
        }
        root.selectedPaths = next;
    }

    function load() {} // For forcing initialization

    Process {
        id: validateDirProc
        property string nicePath: ""
        function setDirectoryIfValid(path) {
            validateDirProc.nicePath = FileUtils.trimFileProtocol(path).replace(/\/+$/, "")
            if (/^\/*$/.test(validateDirProc.nicePath)) validateDirProc.nicePath = "/";
            validateDirProc.exec([
                "bash", "-c",
                `if [ -d "${validateDirProc.nicePath}" ]; then echo dir; elif [ -f "${validateDirProc.nicePath}" ]; then echo file; else echo invalid; fi`
            ])
        }
        stdout: StdioCollector {
            onStreamFinished: {
                    root.directory = Qt.resolvedUrl(validateDirProc.nicePath)
                const result = text.trim()
                if (result === "dir") {
                } else if (result === "file") {
                    root.directory = Qt.resolvedUrl(FileUtils.parentDirectory(validateDirProc.nicePath))
                } else {
                    // Ignore
                }
            }
        }
    }
    function setDirectory(path) {
        validateDirProc.setDirectoryIfValid(path)
    }
    function navigateUp() {
        folderModel.navigateUp()
    }
    function navigateBack() {
        folderModel.navigateBack()
    }
    function navigateForward() {
        folderModel.navigateForward()
    }

    function deleteSelection() {
        if (root.selectedPaths.length === 0) return;
        // .slice(): a QML `property list<string>` read without it stays
        // LINKED to the property rather than being snapshotted - confirmed
        // live in the Singleton this was forked from. Not currently
        // load-bearing here (nothing mutates selectedPaths between this call
        // and fileOpProc's use of it), but the failure mode if that stops
        // being true is a silent no-op gio call, not an error - cheaper to
        // always copy than to re-derive this reasoning per call site.
        fileOpProc.run("trash", root.selectedPaths.slice(), "");
    }

    function renameEntry(oldPath, newName) {
        if (!newName || newName.length === 0) return;
        const dir = FileUtils.parentDirectory(oldPath);
        fileOpProc.run("move", [oldPath], `${dir}/${newName}`);
    }

    // Public entry point for callers outside this pane - specifically
    // FileExplorer.pasteClipboard(), which runs a copy/move against
    // whichever pane it's pasting into. fileOpProc itself is an internal
    // child object; an external Singleton has no direct handle to it.
    function runFileOperation(verb, sources, destination) {
        fileOpProc.run(verb, sources, destination);
    }

    // Runs one gio subcommand against N source paths, then refreshes this
    // pane's listing and reports failure via notify-send.
    //
    // Not queued: a second call while one is running replaces `sources`/
    // `destination` on the same Process before the first exits, which would
    // corrupt whichever operation was still in flight. Multi-select already
    // batches everything into one call to keep this from mattering in
    // practice, so this is a documented limitation rather than a queue - a
    // real queue is more machinery than today's usage justifies.
    Process {
        id: fileOpProc
        property string verb: ""
        property list<string> sources: []
        property string destination: ""
        function run(verb, sources, destination) {
            if (fileOpProc.running) {
                console.warn("[FileExplorerPane] Ignoring", verb, "- a file operation is already running");
                return;
            }
            fileOpProc.verb = verb;
            fileOpProc.sources = sources;
            fileOpProc.destination = destination;
            const args = ["gio", verb, ...sources];
            if (destination.length > 0) args.push(destination);
            fileOpProc.exec(args);
        }
        stderr: StdioCollector {
            id: fileOpStderr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "notify-send",
                    Translation.tr("File operation failed"),
                    `${fileOpProc.verb}: ${fileOpStderr.text.trim()}`,
                    "-u", "critical",
                    "-a", "Shell",
                ]);
            }
            // Qt.labs.folderlistmodel does not watch the directory for
            // external changes made by a separate process (gio here), so the
            // grid would otherwise keep showing pre-operation contents until
            // something else re-triggered a scan.
            root.refresh();
        }
    }

    // Forces FolderListModel to re-scan the current directory by toggling it
    // through empty and back. There is no public "reload" - reassigning the
    // same value is a no-op, so it has to actually change and change back.
    function refresh() {
        const current = folderModel.folder;
        folderModel.folder = "";
        folderModel.folder = current;
    }

    // Folder model
    FolderListModelWithHistory {
        id: folderModel
        folder: Qt.resolvedUrl(root.defaultFolder)
        caseSensitive: false
        nameFilters: searchQuery.split(" ").filter(s => s.length > 0).map(s => `*${s}*`)
        showDirs: true
        showDotAndDotDot: false
        showOnlyReadable: true
        sortField: FolderListModel.Name
        sortReversed: false
        // On folder change, not on count change: count also changes while
        // narrowing the search query in the SAME folder, where the selection
        // should survive (the user is filtering to find what they already
        // picked, not leaving it behind).
        onFolderChanged: root.clearSelection()
        onCountChanged: {
            root.entries = []
            for (let i = 0; i < folderModel.count; i++) {
                const path = folderModel.get(i, "filePath") || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL"))
                if (path && path.length) root.entries.push(path)
            }
            // Drop any selected path the current filter no longer shows,
            // rather than leaving a "selected" entry that isn't even on
            // screen (and whose stale index would make a subsequent
            // Shift+range select the wrong rows).
            if (root.selectedPaths.length > 0) {
                const stillVisible = root.selectedPaths.filter(p => root.entries.indexOf(p) !== -1);
                if (stillVisible.length !== root.selectedPaths.length)
                    root.selectedPaths = stillVisible;
            }
        }
    }
}
