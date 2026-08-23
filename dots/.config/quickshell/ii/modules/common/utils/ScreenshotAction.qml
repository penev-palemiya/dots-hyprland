pragma ComponentBehavior: Bound
pragma Singleton
import qs.modules.common
import qs.modules.common.utils
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import Qt.labs.synchronizer
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    enum Action {
        Copy,
        Edit,
        Search,
        CharRecognition,
        Record,
        RecordWithSound
    }

    property string imageSearchEngineBaseUrl: Config.options.search.imageSearch.imageSearchEngineBaseUrl
    property string fileUploadApiEndpoint: "https://uguu.se/upload"
    readonly property string defaultSaveDirectory: FileUtils.trimFileProtocol(`${Directories.home}/Screenshots`)
    readonly property string effectiveSaveDirectory: {
        const configured = String(Config.options.screenSnip.saveDirectory ?? "").trim();
        if (configured.length > 0)
            return root.normalizeDirectory(configured);
        const legacy = String(Config.options.screenSnip.savePath ?? "").trim();
        return legacy.length > 0 ? root.normalizeDirectory(legacy) : root.defaultSaveDirectory;
    }
    readonly property bool effectiveSaveRegion: {
        const configured = String(Config.options.screenSnip.saveDirectory ?? "").trim();
        if (configured.length === 0)
            return String(Config.options.screenSnip.savePath ?? "").trim().length > 0;
        return Config.options.screenSnip.saveRegion;
    }
    readonly property bool copySavedToClipboard: Config.options.screenSnip.copySavedToClipboard
    property string lastError: ""

    function normalizeDirectory(path) {
        let value = FileUtils.trimFileProtocol(String(path ?? "")).trim();
        if (value.startsWith("~/"))
            value = `${Directories.home}/${value.slice(2)}`;
        value = value.replace(/\/+/g, "/").replace(/\/$/, "");
        return value.length > 0 ? value : "/";
    }

    function migrateLegacy() {
        if (!Config.ready || String(Config.options.screenSnip.saveDirectory ?? "").trim().length > 0)
            return;
        const legacy = String(Config.options.screenSnip.savePath ?? "").trim();
        Config.options.screenSnip.saveDirectory = legacy.length > 0
            ? root.normalizeDirectory(legacy)
            : root.defaultSaveDirectory;
        Config.options.screenSnip.saveRegion = legacy.length > 0;
        Config.options.screenSnip.copySavedToClipboard = true;
        Config.options.screenSnip.savePath = "";
    }

    function regionSaveDirectory() {
        return root.effectiveSaveRegion ? root.effectiveSaveDirectory : "";
    }

    function captureRegion(screenshotPath, x, y, width, height) {
        const directory = root.regionSaveDirectory();
        root.runOutput(["region", screenshotPath, String(Math.round(x)), String(Math.round(y)),
                        String(Math.round(width)), String(Math.round(height)), directory,
                        directory.length > 0 && root.copySavedToClipboard ? "1" : "0"]);
    }

    function captureCurrentMonitor() {
        const monitor = HyprlandData.activeWorkspace?.monitor;
        if (!monitor) {
            root.lastError = Translation.tr("Could not determine the active monitor.");
            return;
        }
        root.runOutput(["monitor", monitor, root.effectiveSaveDirectory,
                        root.copySavedToClipboard ? "1" : "0"]);
    }

    function runOutput(argumentsList) {
        if (outputProc.running) {
            root.lastError = Translation.tr("A screenshot is already being saved.");
            return;
        }
        root.lastError = "";
        outputProc.command = [Directories.screenshotOutputScriptPath, ...argumentsList];
        outputProc.running = true;
    }

    Component.onCompleted: Qt.callLater(root.migrateLegacy)

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                root.migrateLegacy();
        }
    }

    Process {
        id: outputProc
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.lastError = Translation.tr("Screenshot could not be saved.");
        }
    }

    IpcHandler {
        target: "screenshot"
        function monitorSave() {
            root.captureCurrentMonitor();
        }
    }

    function getCommand(x, y, width, height, screenshotPath, action, saveDir = "") {
        // Set command for action
        const rx = Math.round(x);
        const ry = Math.round(y);
        const rw = Math.round(width);
        const rh = Math.round(height);
        const cropBase = `magick ${StringUtils.shellSingleQuoteEscape(screenshotPath)} `
            + `-crop ${rw}x${rh}+${rx}+${ry} +repage`
        const cropToStdout = `${cropBase} -`
        const cropInPlace = `${cropBase} '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`
        const cleanup = `rm '${StringUtils.shellSingleQuoteEscape(screenshotPath)}'`
        const slurpRegion = `${rx},${ry} ${rw}x${rh}`
        const uploadAndGetUrl = (filePath) => {
            return `curl -sF files[]=@'${StringUtils.shellSingleQuoteEscape(filePath)}' ${root.fileUploadApiEndpoint} | jq -r '.files[0].url'`
        }
        const annotationCommand = `${Config.options.regionSelector.annotation.useSatty ? "satty" : "swappy"} -f -`;
        switch (action) {
            case ScreenshotAction.Action.Copy:
                return [Directories.screenshotOutputScriptPath, "region", screenshotPath,
                        String(rx), String(ry), String(rw), String(rh), saveDir,
                        saveDir !== "" && root.copySavedToClipboard ? "1" : "0"];
            case ScreenshotAction.Action.Edit:
                return ["bash", "-c", `${cropToStdout} | ${annotationCommand} && ${cleanup}`]
                break;
            case ScreenshotAction.Action.Search:
                return ["bash", "-c", `${cropInPlace} && xdg-open "${root.imageSearchEngineBaseUrl}$(${uploadAndGetUrl(screenshotPath)})" && ${cleanup}`]
                break;
            case ScreenshotAction.Action.CharRecognition:
                return ["bash", "-c", `${cropInPlace} && tesseract '${StringUtils.shellSingleQuoteEscape(screenshotPath)}' stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr '\\n' '+' | sed 's/\\+$/\\n/') | wl-copy && ${cleanup}`]
                break;
            case ScreenshotAction.Action.Record:
                return ["bash", "-c", `${Directories.recordScriptPath} --region '${slurpRegion}'`]
                break;
            case ScreenshotAction.Action.RecordWithSound:
                return ["bash", "-c", `${Directories.recordScriptPath} --region '${slurpRegion}' --sound`]
                break;
            default:
                console.warn("[Region Selector] Unknown snip action, skipping snip.");
                return;
        }
    }
}
