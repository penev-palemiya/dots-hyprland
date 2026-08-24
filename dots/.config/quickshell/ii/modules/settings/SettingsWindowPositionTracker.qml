import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    required property string settingsTitle

    property bool tracking: false
    property bool requestPending: false
    property bool finalSyncRequested: false
    property bool reportedFailure: false
    property bool baselinesReady: false
    property string trackedAddress: ""
    property string requestKind: ""
    property string responseBuffer: ""
    property real dragStartWindowX: 0
    property real dragStartWindowY: 0
    property int dragStartMonitor: -1
    property real dragStartCursorX: 0
    property real dragStartCursorY: 0
    readonly property string commandSocketPath: {
        const runtimeDir = Quickshell.env("XDG_RUNTIME_DIR") || "/tmp";
        const signature = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "";
        return signature.length > 0 ? `${runtimeDir}/hypr/${signature}/.socket.sock` : "";
    }

    signal exactPositionUpdated(real globalX, real globalY, int monitorId)
    signal predictedPositionUpdated(real globalX, real globalY)

    function begin(exactWindowX, exactWindowY, monitorId) {
        if (tracking || requestPending || commandSocketPath.length === 0)
            return;
        tracking = true;
        finalSyncRequested = false;
        reportedFailure = false;
        baselinesReady = false;
        trackedAddress = "";
        // This is only a fallback until j/activewindow returns the committed
        // drag-start position. Cursor deltas are always global layout values.
        dragStartWindowX = exactWindowX;
        dragStartWindowY = exactWindowY;
        dragStartMonitor = monitorId;
        request("startWindow");
    }

    function end() {
        if (!tracking && !requestPending)
            return;
        tracking = false;
        baselinesReady = false;
        frameTimer.stop();
        finalSyncRequested = true;
        if (!requestPending)
            request("finalWindow");
    }

    function request(kind) {
        if (requestPending || commandSocketPath.length === 0)
            return;
        requestKind = kind;
        responseBuffer = "";
        requestPending = true;
    }

    function commandFor(kind) {
        return kind === "startWindow" || kind === "finalWindow"
            ? "j/activewindow"
            : "j/cursorpos";
    }

    function finishRequest() {
        if (!requestPending)
            return;

        const completedKind = requestKind;
        requestPending = false;
        requestKind = "";

        let data = null;
        try {
            data = JSON.parse(responseBuffer);
        } catch (error) {
            fail(`invalid ${completedKind} response`);
            return;
        }

        if (completedKind === "startWindow" || completedKind === "finalWindow") {
            if (!acceptWindow(data, completedKind === "startWindow"))
                return;

            if (completedKind === "startWindow") {
                if (finalSyncRequested)
                    request("finalWindow");
                else
                    request("startCursor");
            } else {
                finalSyncRequested = false;
                trackedAddress = "";
            }
            return;
        }

        if (!data || !Number.isFinite(Number(data.x)) || !Number.isFinite(Number(data.y))) {
            fail("invalid cursorpos response");
            return;
        }

        const cursorX = Number(data.x);
        const cursorY = Number(data.y);
        if (completedKind === "startCursor") {
            if (finalSyncRequested) {
                request("finalWindow");
                return;
            }
            dragStartCursorX = cursorX;
            dragStartCursorY = cursorY;
            baselinesReady = true;
            frameTimer.start();
            return;
        }

        if (completedKind === "cursor" && tracking && baselinesReady) {
            // Both the cursor and window baseline are Hyprland global layout
            // coordinates. Monitor origins are applied once by SettingsWindow.
            predictedPositionUpdated(
                dragStartWindowX + cursorX - dragStartCursorX,
                dragStartWindowY + cursorY - dragStartCursorY
            );
        }

        if (finalSyncRequested)
            request("finalWindow");
    }

    function acceptWindow(windowData, isStart) {
        if (!windowData || !windowData.address || !windowData.at || windowData.at.length < 2) {
            fail("invalid activewindow response");
            return false;
        }
        if (isStart) {
            if (windowData.title !== settingsTitle) {
                fail("Settings is not the active Hyprland window");
                return false;
            }
            trackedAddress = windowData.address;
        }
        if (windowData.address !== trackedAddress) {
            fail("active window changed while tracking Settings");
            return false;
        }

        const globalX = Number(windowData.at[0]);
        const globalY = Number(windowData.at[1]);
        if (!Number.isFinite(globalX) || !Number.isFinite(globalY)) {
            fail("invalid activewindow coordinates");
            return false;
        }

        if (isStart) {
            dragStartWindowX = globalX;
            dragStartWindowY = globalY;
            dragStartMonitor = Number(windowData.monitor);
        }
        exactPositionUpdated(globalX, globalY, Number(windowData.monitor));
        return true;
    }

    function fail(reason) {
        frameTimer.stop();
        tracking = false;
        baselinesReady = false;
        finalSyncRequested = false;
        requestPending = false;
        requestKind = "";
        trackedAddress = "";
        if (!reportedFailure) {
            console.warn(`[Settings position tracker] ${reason}`);
            reportedFailure = true;
        }
    }

    property Timer frameTimer: Timer {
        id: frameTimer
        interval: 17 // 58.8 Hz: bounded below the 60 Hz limit.
        repeat: true
        running: false
        onTriggered: if (root.tracking && root.baselinesReady && !root.requestPending) root.request("cursor")
    }

    property Socket commandSocket: Socket {
        id: commandSocket
        path: root.commandSocketPath
        // Hyprland's command socket answers one request then closes. A single
        // Socket object reconnects only for the bounded request in flight.
        connected: root.requestPending

        parser: SplitParser {
            // The response is JSON and its EOF is the command-response
            // boundary, so accumulate arbitrary chunks until disconnect.
            splitMarker: ""
            onRead: data => root.responseBuffer += data
        }

        onConnectedChanged: {
            if (connected) {
                write(root.commandFor(root.requestKind));
                flush();
            } else if (root.requestPending) {
                root.finishRequest();
            }
        }
        onError: error => root.fail(`socket error ${error}`)
    }
}
