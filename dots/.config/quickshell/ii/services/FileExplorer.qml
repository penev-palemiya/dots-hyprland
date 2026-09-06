import qs.services
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

/**
 * Window-wide file explorer state - the things that are shared ACROSS every
 * pane/tab rather than belonging to any one of them.
 *
 * Per-pane state (directory, history, selection, search) used to live here
 * too, back when there was only ever one view. It moved to
 * modules/ii/fileExplorer/FileExplorerPane.qml (an instantiated Item, not a
 * Singleton) once split view and tabs meant multiple independent views could
 * exist at once - a Singleton can't hold "the current directory" for two
 * panes that are looking at two different directories.
 *
 * What's left here is deliberately shared:
 *  - the copy/cut clipboard: copying in one pane and pasting into another is
 *    the expected cross-pane behaviour, not a bug to fix by making it
 *    per-pane
 *  - openFile(): launching an application isn't tied to any pane's state
 */
Singleton {
    id: root

    // Copy/cut clipboard, kept here rather than in the system clipboard: the
    // system clipboard already has a job (text), and mixing "the last thing
    // you copied as text" with "the files queued for a paste" is exactly the
    // kind of cross-purpose state that produces surprises (Ctrl+C in a text
    // field silently clobbering a pending file paste, or vice versa).
    property list<string> clipboardPaths: []
    // "copy" or "cut". Only meaningful while clipboardPaths is non-empty.
    property string clipboardMode: "copy"

    function copySelectionToClipboard(pane) {
        if (pane.selectedPaths.length === 0) return;
        root.clipboardPaths = pane.selectedPaths.slice();
        root.clipboardMode = "copy";
    }

    function cutSelectionToClipboard(pane) {
        if (pane.selectedPaths.length === 0) return;
        root.clipboardPaths = pane.selectedPaths.slice();
        root.clipboardMode = "cut";
    }

    // Pastes into `destinationPath` (defaulting to `pane`'s current
    // directory) - not necessarily the pane that copied/cut, which is the
    // point of keeping this clipboard window-wide. The explicit destination
    // is for pasting into a breadcrumb segment that isn't the pane's current
    // folder (FileExplorerAddressBreadcrumb's "Paste into this folder"),
    // where the target is a specific ancestor path, not wherever the pane
    // happens to be browsing.
    function pasteClipboard(pane, destinationPath) {
        if (root.clipboardPaths.length === 0) return;
        // .slice() is not optional here - confirmed live. `const paths =
        // root.clipboardPaths` does NOT snapshot the array: a QML
        // `property list<string>` read this way stays LINKED to the
        // property, so `root.clipboardPaths = []` a few lines down mutated
        // `paths` right along with it, retroactively, despite `const`. The
        // process was then launched with an empty source list every time -
        // `gio move <destination>` with no sources, silently a no-op.
        const paths = root.clipboardPaths.slice();
        const mode = root.clipboardMode;
        const destination = destinationPath ?? pane.effectiveDirectory;
        // A cut is a one-shot move, like every other file manager: pasting a
        // second time after a cut has nothing left to paste, rather than
        // moving the same files again.
        if (mode === "cut") {
            root.clipboardPaths = [];
        }
        pane.runFileOperation(mode === "cut" ? "move" : "copy", paths, destination);
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
}
