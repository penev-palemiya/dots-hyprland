pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.functions

/**
 * Git state of the project in the editor window you're currently looking at.
 *
 * Everything here is event-driven; nothing polls:
 *
 * - Which window is focused comes from `ToplevelManager.activeToplevel`.
 * - Which *project* that window has open is resolved from the window title,
 *   which is the only live signal — `/proc/<pid>/cwd` is useless for VS Code
 *   (it reports the launch directory, `/home/<user>`, not the workspace) and
 *   `storage.json`'s `lastActiveWindow` only names one window even when
 *   several are open. The title gives a folder *name*; the name is turned
 *   into a path with a map built from VS Code's own state files, so no
 *   hand-maintained list of project roots is needed.
 * - Git branch/ahead/dirty is read with a single `git status` per change, and
 *   re-read when `.git` actually changes, via inotify rather than a timer.
 *
 * Deliberately NOT here: `git fetch`. Counting commits you're *behind*
 * requires network access, so it can't be part of a passive status readout —
 * `.git/FETCH_HEAD` on this machine was a week stale, which is exactly the
 * sort of number that looks authoritative and is wrong. If it's added later
 * it has to be an explicit, rate-limited action, never a background refresh.
 */
Singleton {
    id: root

    // Window classes treated as "an editor with a project open". Kept as a
    // plain list so adding another editor is a one-line change.
    readonly property var editorClasses: ["code", "code-url-handler", "codium", "vscodium", "cursor"]

    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property string focusedClass: String(root.activeToplevel?.appId ?? "").toLowerCase()
    readonly property string focusedTitle: String(root.activeToplevel?.title ?? "")
    readonly property bool editorFocused: root.editorClasses.includes(root.focusedClass)

    // name -> absolute path, built from VS Code's own state
    property var workspaceMap: ({})

    // What the focused window is showing right now, if it's an editor at all.
    readonly property string focusedProjectName: root.editorFocused ? root.parseRootName(root.focusedTitle) : ""

    // The project actually being reported on. Deliberately STICKY: it updates
    // when an editor with a resolvable project is focused, and otherwise keeps
    // the last one rather than clearing.
    //
    // Clearing on focus loss looks tidier but breaks the island: opening its
    // overlay takes a focus grab, which drops the editor out of focus, which
    // would clear the project, which would make the activity unavailable and
    // close the overlay again — you could never actually read the panel you
    // just opened. Staying sticky also means the state is still there to
    // glance at from another window, which is when you tend to want it.
    property string projectName: ""
    property string projectPath: ""

    function resolveProject() {
        const name = root.focusedProjectName;
        if (name.length === 0)
            return; // not an editor (or no folder) — keep the previous project
        const path = root.workspaceMap[name] ?? "";
        if (path.length === 0)
            return; // unknown workspace — same
        root.projectName = name;
        root.projectPath = path;
    }

    onFocusedProjectNameChanged: root.resolveProject()
    // The map arrives asynchronously, so a project focused before storage.json
    // finished loading has to be resolved again once it has.
    onWorkspaceMapChanged: root.resolveProject()

    // ---- git state ----
    property string branch: ""
    property bool detachedHead: false
    property bool hasUpstream: false
    property int ahead: 0
    property int changedFiles: 0
    readonly property bool dirty: changedFiles > 0
    readonly property bool available: root.projectPath.length > 0 && root.branch.length > 0

    /**
     * VS Code's title is `<editor> - <rootName> - Visual Studio Code`, with a
     * "●" prefix while there are unsaved changes and the middle segment absent
     * when no folder is open. Take the last segment before the app name; if
     * that isn't a known workspace the lookup simply misses and we report no
     * project, which is the correct outcome for a lone file.
     */
    function parseRootName(title) {
        const cleaned = String(title ?? "").replace(/\s*-\s*(Visual Studio Code|VSCodium|Cursor)(\s*-\s*Insiders)?\s*$/i, "").trim();
        if (cleaned.length === 0)
            return "";
        const parts = cleaned.split(" - ");
        return parts[parts.length - 1].trim();
    }

    function pathFromUri(uri) {
        const raw = String(uri ?? "");
        if (!raw.startsWith("file://"))
            return "";
        try {
            return decodeURIComponent(raw.slice("file://".length));
        } catch (e) {
            return "";
        }
    }

    function rebuildWorkspaceMap() {
        const text = storageFile.text();
        if (!text || text.length === 0)
            return;
        let parsed;
        try {
            parsed = JSON.parse(text);
        } catch (e) {
            return;
        }

        const map = {};
        const add = uri => {
            const path = root.pathFromUri(uri);
            if (path.length === 0)
                return;
            const name = path.split("/").filter(s => s.length > 0).pop();
            if (name)
                map[name] = path;
        };

        // Currently-open windows first: these are the ones a title can
        // actually refer to right now.
        const folders = parsed.backupWorkspaces?.folders ?? [];
        for (const entry of folders)
            add(typeof entry === "string" ? entry : entry?.folderUri);

        // ...then the last active one, as a fallback for a freshly opened
        // window that hasn't been written into backupWorkspaces yet.
        add(parsed.windowsState?.lastActiveWindow?.folder);

        root.workspaceMap = map;
    }

    /**
     * Parses `git status --porcelain=v2 --branch`. Kept as a named function
     * rather than inlined in the Process handler so it can be exercised
     * directly against captured git output.
     *
     * `# branch.ab` is absent entirely when the branch has no upstream, so
     * "no upstream" and "up to date" are different states, not both zero.
     */
    function parseGitStatus(text) {
        const result = {
            branch: "",
            detached: false,
            upstream: false,
            ahead: 0,
            changed: 0
        };
        for (const line of String(text ?? "").split("\n")) {
            if (line.startsWith("# branch.head ")) {
                result.branch = line.slice("# branch.head ".length).trim();
                result.detached = result.branch === "(detached)";
            } else if (line.startsWith("# branch.upstream ")) {
                result.upstream = true;
            } else if (line.startsWith("# branch.ab ")) {
                const m = line.match(/\+(\d+)\s+-(\d+)/);
                if (m)
                    result.ahead = parseInt(m[1]);
            } else if (line.length > 0 && !line.startsWith("#")) {
                // Every non-header line is one path: tracked changes ("1"/"2"),
                // unmerged ("u") and untracked ("?") alike.
                result.changed += 1;
            }
        }
        return result;
    }

    function clearGitState() {
        root.branch = "";
        root.detachedHead = false;
        root.hasUpstream = false;
        root.ahead = 0;
        root.changedFiles = 0;
    }

    function refreshGit() {
        if (root.projectPath.length === 0) {
            root.clearGitState();
            return;
        }
        // The command is assigned here rather than left as a binding on
        // projectPath: onProjectPathChanged fires before the binding has been
        // re-evaluated, so starting the process at that moment ran git against
        // the *previous* project and every reading lagged one step behind.
        gitProc.running = false;
        gitProc.command = ["git", "-C", root.projectPath, "status", "--porcelain=v2", "--branch"];
        gitProc.running = true;
    }

    onProjectPathChanged: root.refreshGit()

    FileView {
        id: storageFile

        // VS Code rewrites this when windows open/close, so watching it keeps
        // the name->path map correct across sessions without polling.
        path: `${FileUtils.trimFileProtocol(Directories.home)}/.config/Code/User/globalStorage/storage.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.rebuildWorkspaceMap()
    }

    /**
     * `--porcelain=v2 --branch` gives branch, tracking state and the changed
     * file list in one shot, and touches only local refs — no network. Note
     * that `# branch.ab` is absent entirely when the branch has no upstream
     * (true of this repo's own `dev-master`), which is why `hasUpstream` is a
     * separate state rather than "ahead == 0".
     */
    Process {
        id: gitProc

        // Set by refreshGit() before each run — see the note there.
        command: []

        // The collector only accumulates; everything is done in onExited.
        // Checking exitCode from onStreamFinished does not work — the stream
        // closes before the exit status is known, so the check saw a stale
        // value and discarded every successful run.
        stdout: StdioCollector {
            id: gitOut
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.clearGitState();
                return;
            }
            const parsed = root.parseGitStatus(gitOut.text);
            root.branch = parsed.branch;
            root.detachedHead = parsed.detached;
            root.hasUpstream = parsed.upstream;
            root.ahead = parsed.ahead;
            root.changedFiles = parsed.changed;
        }
    }

    // Re-read on real repository changes instead of on a schedule.
    // `.git/logs/HEAD` is the reliable target: it's appended on every commit,
    // checkout, merge and reset. Watching `.git/refs/heads/*` would miss
    // anything in a repo whose refs are packed, which this one's are.
    FileView {
        path: root.projectPath.length > 0 ? `${root.projectPath}/.git/logs/HEAD` : ""
        watchChanges: true
        onFileChanged: root.refreshGit()
    }

    // Branch switches rewrite HEAD itself.
    FileView {
        path: root.projectPath.length > 0 ? `${root.projectPath}/.git/HEAD` : ""
        watchChanges: true
        onFileChanged: root.refreshGit()
    }

    // The working tree changes far more often than .git does, and nothing
    // watches it — so the dirty count is refreshed when you look at the
    // editor again, which is when it's about to be read.
    onEditorFocusedChanged: if (root.editorFocused)
        root.refreshGit()
}
