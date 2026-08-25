pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.modules.common
import qs.modules.common.functions

/**
 * The single source of truth for WHERE the wallpaper is drawn on a screen.
 *
 * The desktop does not simply paint the wallpaper at screen size: it zooms it
 * (parallax.workspaceZoom) and pans it as you move between workspaces and open
 * the sidebars. Anything that wants to look like frosted glass over the
 * wallpaper — bar popups, the dynamic island — has to reproduce that exact
 * transform, or its "glass" shows a different part of the picture than the
 * desktop right behind it and drifts further with every workspace switch.
 *
 * So the transform lives here once, and both the desktop (Background.qml) and
 * the frosted surfaces (WallpaperBackdrop.qml) ask for it, rather than each
 * keeping its own copy of the arithmetic to fall out of sync.
 *
 * The natural pixel size of the wallpaper is resolved with `magick identify`
 * rather than from a QML Image: asking an Image for `sourceSize` here returns
 * 0, which is presumably why the original code shelled out for it too.
 */
Singleton {
    id: root

    readonly property bool wallpaperIsVideo: {
        const p = Config.options.background.wallpaperPath ?? "";
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }
    readonly property string path: root.wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath

    // A private copy of the current wallpaper plus its pre-blurred variant,
    // rebuilt by scripts/wallpaper/material.sh whenever `path` changes.
    //
    // Everything that draws the wallpaper should use `renderPath`, not `path`:
    // rendering from our own copy is what stops a deleted or moved original
    // from taking the wallpaper down with it.
    //
    // `blurredPath` exists so the frosted surfaces stop each running their own
    // live blur of the same picture. Until it resolves they fall back to
    // blurring themselves, so a wallpaper change is never visibly unfrosted.
    readonly property string materialDir: FileUtils.trimFileProtocol(`${Directories.state}/user/generated/wallpaper/material`)
    property string cachedSourcePath: ""
    property string blurredPath: ""
    readonly property bool blurredReady: root.blurredPath.length > 0
    readonly property string renderPath: root.cachedSourcePath.length > 0 ? root.cachedSourcePath : root.path

    function refreshMaterial() {
        if (root.path && root.path.length > 0)
            materialProc.running = true;
    }

    Process {
        id: materialProc
        command: [
            "bash",
            `${FileUtils.trimFileProtocol(Quickshell.shellPath("scripts"))}/wallpaper/material.sh`,
            root.path,
            root.materialDir
        ]
        stdout: StdioCollector {
            id: materialCollector
            onStreamFinished: {
                const lines = materialCollector.text.trim().split("\n").map(line => line.trim());
                root.cachedSourcePath = lines[0] ?? "";
                root.blurredPath = lines[1] ?? "";
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // No copy available: fall back to the original path everywhere.
                root.cachedSourcePath = "";
                root.blurredPath = "";
            }
        }
    }

    // Natural (unscaled) wallpaper dimensions; zero until `magick` answers, and
    // consumers fall back to screen-sized behaviour until then. Deliberately
    // ONE property rather than a width and a height: assigning two separately
    // notifies twice, and for the frame in between, callers saw a real width
    // next to a placeholder height and computed a wildly wrong scale from it.
    property size naturalSize: Qt.size(0, 0)

    // How long the desktop takes to glide to a new parallax offset. Consumers
    // animate with these so every surface moves as one.
    readonly property int panDuration: 600
    readonly property int panEasing: Easing.OutCubic

    onPathChanged: root.refreshMaterial()
    // Natural size is measured from whatever is actually drawn, so geometry
    // keeps working when the original is gone.
    onRenderPathChanged: root.refreshNaturalSize()
    Component.onCompleted: {
        root.refreshMaterial();
        root.refreshNaturalSize();
    }

    function refreshNaturalSize() {
        if (root.renderPath && root.renderPath.length > 0)
            sizeProc.running = true;
    }

    Process {
        id: sizeProc
        command: ["magick", "identify", "-format", "%w %h", root.renderPath]
        stdout: StdioCollector {
            id: sizeCollector
            onStreamFinished: {
                const [w, h] = sizeCollector.text.split(" ").map(Number);
                if (w > 0 && h > 0)
                    root.naturalSize = Qt.size(w, h);
            }
        }
    }

    /**
     * The rectangle the wallpaper image occupies on `screen`, in that screen's
     * own coordinates: `x`/`y` are normally negative, since the zoomed picture
     * is larger than the screen and is panned within it.
     */
    function drawRectFor(screen) {
        if (!screen || screen.width <= 0 || screen.height <= 0)
            return Qt.rect(0, 0, 0, 0);

        const screenW = screen.width;
        const screenH = screen.height;
        const known = root.naturalSize.width > 0 && root.naturalSize.height > 0;
        const naturalW = known ? root.naturalSize.width : screenW;
        const naturalH = known ? root.naturalSize.height : screenH;

        // Scale so every side fits, then apply the parallax zoom that creates
        // the slack the picture is panned within.
        const zoom = Config.options.background.parallax.workspaceZoom;
        const scale = Math.max(screenW / naturalW, screenH / naturalH) * zoom;
        const width = naturalW * scale;
        const height = naturalH * scale;
        const slackX = Math.max(0, width - screenW);
        const slackY = Math.max(0, height - screenH);

        const monitor = Hyprland.monitorFor(screen);
        const chunkSize = Config.options.bar.workspaces.shown ?? 10;
        const relevantWindows = HyprlandData.windowList.filter(win => win.monitor === monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id);
        const lastWorkspaceId = relevantWindows[relevantWindows.length - 1]?.workspace.id || 10;
        const totalWorkspaces = Math.ceil(lastWorkspaceId / chunkSize) * chunkSize;

        const vertical = (Config.options.background.parallax.autoVertical && naturalH > naturalW) || Config.options.background.parallax.vertical;
        const workspaceIndex = (monitor?.activeWorkspace?.id ?? 1) - 1;
        const fraction = totalWorkspaces <= 1 ? 0.5 : Math.max(0, Math.min(1, workspaceIndex / (totalWorkspaces - 1)));

        let fractionX = 0.5;
        if (Config.options.background.parallax.enableWorkspace && !vertical)
            fractionX = fraction;
        if (Config.options.background.parallax.enableSidebar) {
            const sidebarFraction = zoom / chunkSize / 2;
            fractionX += (sidebarFraction * GlobalStates.sidebarRightOpen - sidebarFraction * GlobalStates.sidebarLeftOpen);
        }
        fractionX = Math.max(0, Math.min(1, fractionX));

        let fractionY = 0.5;
        if (Config.options.background.parallax.enableWorkspace && vertical)
            fractionY = fraction;
        fractionY = Math.max(0, Math.min(1, fractionY));

        // A picture smaller than the screen is centred instead of panned.
        const x = screenW > width ? (screenW - width) / 2 : -slackX * fractionX;
        const y = screenH > height ? (screenH - height) / 2 : -slackY * fractionY;
        return Qt.rect(x, y, width, height);
    }
}
