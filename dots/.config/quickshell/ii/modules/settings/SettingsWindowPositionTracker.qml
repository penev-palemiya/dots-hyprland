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
        watchStillPolls = 0;
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
        externalDrag = false;
        stillCursorPolls = 0;
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
            if (root.followDuringDrag)
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

    // --- Moves this window did not start itself -----------------------------
    //
    // begin()/end() above only fire when the drag starts on the window's own
    // title strip. Super+drag, a keybind, snapping and tiling never touch them,
    // and Hyprland emits no events while a drag is in flight - so the coarse
    // HyprlandData refresh was the only thing left, and it lands *after* the
    // move finishes. That is why the backdrop crop used to snap into place at
    // the end of a drag instead of following it.
    //
    // So ask instead of waiting to be told: a cheap poll while the window is
    // focused, stepping up to frame rate the moment the position actually
    // changes and dropping back once it settles. This asks for the exact
    // position rather than predicting it from cursor deltas, so it needs no
    // baselines and cannot drift - at the cost of one small IPC round trip per
    // frame, and only while something is genuinely moving.
    //
    // Uses j/clients rather than j/activewindow: measured, it streams position
    // live throughout a drag, and it describes every window rather than only
    // the focused one - so this needs no "is the window active" condition,
    // which was one more unverified link in the chain.

    // Chasing the window during a drag cannot be made synchronous: on Wayland a
    // client does not know its own position when it renders a frame, so the crop
    // is always one IPC round trip behind and visibly swims. The picture is
    // heavily blurred, though - which part of it you are looking at is not
    // something an eye can check - so holding the crop still for the duration of
    // the drag and resyncing once at the end looks rigid and correct, and costs
    // no IPC at all while moving.
    //
    // Live chasing, predicted from cursor deltas. j/cursorpos is a ~30 byte
    // reply, so this can run per frame; asking for the window position instead
    // would mean parsing a ~6 KB j/clients dump 60 times a second.
    property bool followDuringDrag: true

    property bool watchExternalMoves: false
    // Verbose per-frame tracing. Costs real frames at 60 Hz - leave it off
    // except while diagnosing, and never ship it on.
    property bool watchDebug: false

    // Counts instances: if this prints more than once, the window itself is
    // being built more than once and that is the real problem.
    Component.onCompleted: if (watchDebug) console.log(`[watch] tracker created, title="${settingsTitle}"`)
    property int watchIdleInterval: 100
    property int watchDragInterval: 50
    property int watchActiveInterval: 16
    property int watchStillPollsBeforeIdle: 12

    // Set when movement was detected by polling rather than by the title strip.
    // Such a drag has no mouse release to end it, so it ends on cursor stillness.
    property bool externalDrag: false
    property int stillCursorPolls: 0
    property real lastCursorX: NaN
    property real lastCursorY: NaN
    property int externalDragEndPolls: 2

    property bool watchMoving: false
    property int watchStillPolls: 0
    property bool watchPending: false
    property string watchBuffer: ""
    property real lastSeenX: NaN
    property real lastSeenY: NaN

    function handleWatchResponse() {
        let clients = null;
        try {
            clients = JSON.parse(root.watchBuffer);
        } catch (error) {
            if (root.watchDebug)
                console.log(`[watch] unparseable response, ${root.watchBuffer.length} bytes`);
            return;
        }
        if (!Array.isArray(clients)) {
            if (root.watchDebug)
                console.log("[watch] j/clients did not return an array");
            return;
        }

        const data = clients.find(client => client && client.title === root.settingsTitle);
        if (!data || !data.at || data.at.length < 2) {
            if (root.watchDebug)
                console.log(`[watch] no window titled "${root.settingsTitle}" among ${clients.length}`);
            return;
        }

        const globalX = Number(data.at[0]);
        const globalY = Number(data.at[1]);
        if (root.watchDebug)
            console.log(`[watch] found at=${JSON.stringify(data.at)}`
                + ` -> ${globalX},${globalY}`
                + ` lastSeen=${root.lastSeenX},${root.lastSeenY}`);
        if (!Number.isFinite(globalX) || !Number.isFinite(globalY)) {
            if (root.watchDebug)
                console.log("[watch] coordinates not finite, giving up on this poll");
            return;
        }

        const hadBaseline = Number.isFinite(root.lastSeenX) && Number.isFinite(root.lastSeenY);
        const moved = hadBaseline && (globalX !== root.lastSeenX || globalY !== root.lastSeenY);
        root.lastSeenX = globalX;
        root.lastSeenY = globalY;

        if (root.tracking) {
            if (moved) {
                root.watchStillPolls = 0;
            } else {
                root.watchStillPolls += 1;
                if (root.watchStillPolls >= root.externalDragEndPolls)
                    root.end();
            }
            return;
        }

        if (!root.followDuringDrag) {
            if (moved) {
                root.watchMoving = true;
                root.watchStillPolls = 0;
                return; // Frozen for the duration of the move.
            }
            if (root.watchMoving) {
                root.watchStillPolls += 1;
                if (root.watchStillPolls >= root.externalDragEndPolls) {
                    root.watchMoving = false;
                    root.watchStillPolls = 0;
                    root.exactPositionUpdated(globalX, globalY, Number(data.monitor));
                }
                return;
            }
            if (!hadBaseline)
                root.exactPositionUpdated(globalX, globalY, Number(data.monitor));
            return;
        }

        if (root.externalDrag) {
            // Prediction owns the position while dragging; this poll only
            // decides when the window has actually come to rest.
            if (moved) {
                root.watchStillPolls = 0;
            } else {
                root.watchStillPolls += 1;
                if (root.watchStillPolls >= root.externalDragEndPolls)
                    root.end();
            }
            return;
        }

        if (moved) {
            root.watchMoving = true;
            root.watchStillPolls = 0;
            // Hand over to cursor-delta prediction: it needs a ~30 byte
            // j/cursorpos reply per frame instead of a ~6 KB j/clients dump,
            // which is almost certainly why it was built that way originally.
            if (root.followDuringDrag && !root.tracking && !root.requestPending) {
                root.externalDrag = true;
                root.stillCursorPolls = 0;
                root.lastCursorX = NaN;
                root.lastCursorY = NaN;
                root.begin(globalX, globalY, Number(data.monitor));
            }
        } else if (root.watchMoving) {
            root.watchStillPolls += 1;
            if (root.watchStillPolls >= root.watchStillPollsBeforeIdle) {
                root.watchMoving = false;
                root.watchStillPolls = 0;
            }
        }

        if (moved || !hadBaseline) {
            if (root.watchDebug)
                console.log(`[watch] ${globalX},${globalY} moved=${moved} interval=${watchTimer.interval}`);
            root.exactPositionUpdated(globalX, globalY, Number(data.monitor));
        }
    }

    property Timer watchTimer: Timer {
        // Detection only - prediction supplies the frames. Slightly quicker
        // while a drag is in flight, because this interval is how long the crop
        // keeps chasing the pointer after the window has already stopped.
        interval: root.tracking ? root.watchDragInterval : root.watchIdleInterval
        repeat: true
        // Never compete with the title-strip path: while that runs it is
        // already live and owns the shared request socket.
        // Runs unconditionally, including throughout a drag. Cursor prediction
        // follows the pointer, not the window, so left to itself it outlives the
        // drag: release the button, keep moving the mouse, and the crop sails on
        // alone. Nothing else can tell us the drag ended - startSystemMove()
        // hands the pointer grab to the compositor, so the title strip's
        // MouseArea never sees onReleased, and an external drag has no release
        // to see at all. Only the real position can say the window stopped.
        //
        // It must not be gated on requestPending either: that belongs to the
        // prediction socket and toggles every frame, which would silence the
        // one thing able to end the drag.
        running: root.watchExternalMoves && root.commandSocketPath.length > 0
        onRunningChanged: if (root.watchDebug)
            console.log(`[watch] running=${running}`
                + ` external=${root.watchExternalMoves}`
                + ` tracking=${root.tracking}`
                + ` reqPending=${root.requestPending}`
                + ` sockPath=${root.commandSocketPath.length > 0}`
                + ` interval=${interval}`)
        onTriggered: {
            if (root.watchDebug)
                console.log(`[watch] tick pending=${root.watchPending}`);
            if (!root.watchPending) {
                root.watchBuffer = "";
                root.watchPending = true;
            }
        }
    }

    // Its own socket, so none of this can disturb the request state machine
    // above. Hyprland's command socket serves one request per connection
    // anyway, so a second one costs nothing while idle.
    property Socket watchSocket: Socket {
        path: root.commandSocketPath
        connected: root.watchPending

        parser: SplitParser {
            splitMarker: ""
            onRead: data => root.watchBuffer += data
        }

        onConnectedChanged: {
            if (root.watchDebug)
                console.log(`[watch] socket connected=${connected} buffered=${root.watchBuffer.length}`);
            if (connected) {
                write("j/clients");
                flush();
            } else if (root.watchPending) {
                root.watchPending = false;
                root.handleWatchResponse();
            }
        }
        // Same normal-close-reported-as-error as above. Clearing watchPending
        // here also ran *before* onConnectedChanged, so the response was
        // dropped unparsed every single time.
        onError: error => {
            if (root.watchBuffer.length > 0)
                return;
            root.watchPending = false;
            root.watchMoving = false;
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
        // Hyprland's command socket closes as soon as it has answered, and
        // Quickshell surfaces that normal close as PeerClosedError. Treating it
        // as a failure killed every request on its first reply - which is why
        // live position tracking never ran for any drag, in any direction.
        // A close with data in hand is the end of the response, not an error.
        onError: error => {
            if (root.responseBuffer.length === 0)
                root.fail(`socket error ${error}`);
        }
    }
}
