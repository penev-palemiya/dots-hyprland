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
        onCountChanged: {
            root.entries = []
            for (let i = 0; i < folderModel.count; i++) {
                const path = folderModel.get(i, "filePath") || FileUtils.trimFileProtocol(folderModel.get(i, "fileURL"))
                if (path && path.length) root.entries.push(path)
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
    }
}
