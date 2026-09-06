import qs.services
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * A standalone fork of services/Wallpapers.qml, kept as its own file rather
 * than a shared base class - same reasoning as the dedicated fileExplorer*
 * size tokens. Wallpapers.qml is a "limited file browsing service"
 * scoped to picking one image; this one is meant to grow into general file
 * management (multi-select, copy/move/delete/rename), which needs a
 * different shape of API. Forking now means that growth can't accidentally
 * destabilize wallpaper picking, which people rely on today.
 *
 * Not yet implemented: any file OPERATION beyond navigation. This is
 * currently just the browsing half - directory listing, search, history -
 * with the wallpaper-specific extension filter and thumbnail generation
 * removed.
 */
Singleton {
    id: root

    property alias directory: folderModel.folder
    readonly property string effectiveDirectory: FileUtils.trimFileProtocol(folderModel.folder.toString())
    property url defaultFolder: Qt.resolvedUrl(Directories.home)
    property alias folderModel: folderModel // Expose for direct binding when needed
    property string searchQuery: ""
    property list<string> entries: [] // List of absolute file paths (without file://)

    // Multi-selection, kept here rather than in the UI: file operations
    // (copy/move/delete/rename) and a context menu both need to act on "the
    // current selection" without the UI having to forward indices through
    // signals for every consumer that cares.
    //
    // A plain array of paths, not a JS Set - QML property bindings only
    // re-evaluate on property CHANGE notifications, and reassigning
    // `selectedPaths` to a new array fires one. Mutating a Set in place
    // wouldn't, so every read (indexOf() included) would silently see stale
    // membership until something else happened to touch the property.
    property list<string> selectedPaths: []
    // Anchor for Shift-range selection: the index Shift+click/arrow ranges
    // are measured from. -1 means no anchor is set yet (nothing to range
    // from other than the plain click target).
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

    signal changed()

    function load () {} // For forcing initialization

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

    // Copy/cut clipboard, kept here rather than in the system clipboard: the
    // system clipboard already has a job (text), and mixing "the last thing
    // you copied as text" with "the files queued for a paste" is exactly the
    // kind of cross-purpose state that produces surprises (Ctrl+C in a text
    // field silently clobbering a pending file paste, or vice versa).
    property list<string> clipboardPaths: []
    // "copy" or "cut". Only meaningful while clipboardPaths is non-empty.
    property string clipboardMode: "copy"

    function copySelectionToClipboard() {
        if (root.selectedPaths.length === 0) return;
        root.clipboardPaths = root.selectedPaths.slice();
        root.clipboardMode = "copy";
    }

    function cutSelectionToClipboard() {
        if (root.selectedPaths.length === 0) return;
        root.clipboardPaths = root.selectedPaths.slice();
        root.clipboardMode = "cut";
    }

    function pasteClipboard() {
        if (root.clipboardPaths.length === 0) return;
        // .slice() is not optional here - confirmed live. `const paths =
        // root.clipboardPaths` does NOT snapshot the array: a QML
        // `property list<string>` read this way stays LINKED to the
        // property, so `root.clipboardPaths = []` a few lines down mutated
        // `paths` right along with it, retroactively, despite `const`. The
        // process below was then launched with an empty source list every
        // time - `gio move <destination>` with no sources, silently a no-op.
        const paths = root.clipboardPaths.slice();
        const mode = root.clipboardMode;
        // A cut is a one-shot move, like every other file manager: pasting a
        // second time after a cut has nothing left to paste, rather than
        // moving the same files again (which would just no-op the second
        // time since they're no longer at the source, but would be
        // confusing enough - a paste that does nothing with no explanation -
        // that it's worth not relying on gio to make it harmless).
        if (mode === "cut") {
            root.clipboardPaths = [];
        }
        fileOpProc.run(mode === "cut" ? "move" : "copy", paths, root.effectiveDirectory);
    }

    function deleteSelection() {
        if (root.selectedPaths.length === 0) return;
        // .slice(): see the note in pasteClipboard() above. Not currently
        // load-bearing here (nothing mutates selectedPaths between this call
        // and run()'s use of it), but that stops being true the moment
        // anything - a future confirmation dialog, anything async - lands
        // between them, and the failure mode is a silent no-op gio call, not
        // an error. Cheaper to always copy than to re-derive this reasoning
        // per call site.
        fileOpProc.run("trash", root.selectedPaths.slice(), "");
    }

    function renameEntry(oldPath, newName) {
        if (!newName || newName.length === 0) return;
        const dir = FileUtils.parentDirectory(oldPath);
        fileOpProc.run("move", [oldPath], `${dir}/${newName}`);
    }

    // Runs one gio subcommand against N source paths, then refreshes the
    // listing and reports failure via notify-send - the same pattern
    // openProc below uses for `gio open`, generalized to the three
    // operations that take a source list and a destination.
    //
    // Not queued: a second call while one is running replaces `sources`/
    // `destination` on the same Process before the first exits, which would
    // corrupt whichever operation was still in flight. Multi-select already
    // batches everything into one call to keep this from mattering in
    // practice (see pasteClipboard/deleteSelection above), so this is a
    // documented limitation rather than a queue - a real queue is more
    // machinery than today's one-explorer-window usage justifies.
    Process {
        id: fileOpProc
        property string verb: ""
        property list<string> sources: []
        property string destination: ""
        function run(verb, sources, destination) {
            if (fileOpProc.running) {
                console.warn("[FileExplorer] Ignoring", verb, "- a file operation is already running");
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
            // something else (a search keystroke, navigating away and back)
            // happened to re-trigger a scan.
            root.refresh();
        }
    }

    // Forces FolderListModel to re-scan the current directory by toggling it
    // through empty and back. There is no public "reload" - this is the same
    // trick used elsewhere for FolderListModel (it re-lists on `folder`
    // actually changing, and reassigning the same value is a no-op).
    function refresh() {
        const current = folderModel.folder;
        folderModel.folder = "";
        folderModel.folder = current;
    }

    // Opens a file with whatever the desktop's mime associations say, via
    // `gio open` rather than `xdg-open`: gio reads the same GIO/GVfs mime
    // database GNOME-family apps and file-choosers already use here, and
    // doesn't depend on xdg-utils' desktop-environment detection, which is
    // frequently wrong under a non-DE compositor like Hyprland.
    Process {
        id: openProc
        property string path: ""
        function open(path) {
            openProc.path = path;
            openProc.exec(["gio", "open", path]);
        }
        stderr: StdioCollector {
            id: openStderr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "notify-send",
                    Translation.tr("Couldn't open file"),
                    `${FileUtils.trimFileProtocol(openProc.path)}\n${openStderr.text.trim()}`,
                    "-u", "critical",
                    "-a", "Shell",
                ]);
            }
        }
    }
    function openFile(path) {
        openProc.open(path);
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

    // Named distinctly from the UI-toggle handler in
    // modules/ii/fileExplorer/FileExplorer.qml: two IpcHandlers sharing one
    // target don't error, they silently keep only the first and warn about
    // the second - the exact kind of quiet failure this codebase has been
    // bitten by before, so it gets its own target instead.
    IpcHandler {
        target: "fileExplorerService"

        function setDirectory(path: string): void {
            root.setDirectory(path);
        }

        function clearSelection(): void {
            root.clearSelection();
        }

        function openFile(path: string): void {
            root.openFile(path);
        }

        function selectAll(): void {
            root.selectedPaths = root.entries.slice();
        }


        function deleteSelection(): void {
            root.deleteSelection();
        }

        function copySelection(): void {
            root.copySelectionToClipboard();
        }

        function cutSelection(): void {
            root.cutSelectionToClipboard();
        }

        function paste(): void {
            root.pasteClipboard();
        }

        function renameEntry(oldPath: string, newName: string): void {
            root.renameEntry(oldPath, newName);
        }

    }
}
