import QtQuick

QtObject {
    id: root

    enum Phase {
        Closed,
        Opening,
        Opened,
        Closing
    }

    property bool requestedOpen: false
    property int phase: SurfaceLifecycle.Phase.Closed
    property real progress: 0
    property bool mounted: false
    property bool keepMounted: false
    property bool keepSurfaceMapped: false
    property int generation: 0

    property int enterDuration: 0
    property int exitDuration: 0
    property list<real> enterCurve: [0, 0, 1, 1]
    property list<real> exitCurve: [0, 0, 1, 1]

    readonly property bool surfaceVisible: root.mounted
        && (root.keepSurfaceMapped || root.phase !== SurfaceLifecycle.Phase.Closed)
    readonly property bool acceptsInput: root.requestedOpen
        && (root.phase === SurfaceLifecycle.Phase.Opening
            || root.phase === SurfaceLifecycle.Phase.Opened)

    signal openingStarted
    signal fullyOpened
    signal closingStarted
    signal fullyClosed

    function open() {
        root.setOpen(true);
    }

    function close() {
        root.setOpen(false);
    }

    function toggle() {
        root.setOpen(!root.requestedOpen);
    }

    function setOpen(open) {
        if (root.requestedOpen === open
                && ((open && (root.phase === SurfaceLifecycle.Phase.Opening
                               || root.phase === SurfaceLifecycle.Phase.Opened))
                    || (!open && (root.phase === SurfaceLifecycle.Phase.Closing
                                  || root.phase === SurfaceLifecycle.Phase.Closed))))
            return;

        root.requestedOpen = open;
        transition.stop();

        if (open) {
            root.mounted = true;
            root.generation++;
            root.phase = SurfaceLifecycle.Phase.Opening;
            root.openingStarted();
            Qt.callLater(root.startOpening);
            return;
        }

        if (root.phase === SurfaceLifecycle.Phase.Closed || root.progress <= 0) {
            root.finishClosed();
            return;
        }

        root.phase = SurfaceLifecycle.Phase.Closing;
        root.closingStarted();
        transition.from = root.progress;
        transition.to = 0;
        transition.duration = Math.max(1, root.exitDuration * Math.max(0, root.progress));
        transition.easing.bezierCurve = root.exitCurve;
        transition.start();
    }

    function startOpening() {
        if (!root.requestedOpen)
            return;
        transition.from = root.progress;
        transition.to = 1;
        transition.duration = Math.max(1, root.enterDuration * Math.max(0, 1 - root.progress));
        transition.easing.bezierCurve = root.enterCurve;
        transition.start();
    }

    function finishClosed() {
        transition.stop();
        root.progress = 0;
        root.phase = SurfaceLifecycle.Phase.Closed;
        if (!root.keepMounted)
            root.mounted = false;
        root.fullyClosed();
    }

    onKeepMountedChanged: {
        if (root.keepMounted)
            root.mounted = true;
        else if (root.phase === SurfaceLifecycle.Phase.Closed)
            root.mounted = false;
    }

    Component.onCompleted: {
        if (root.keepMounted)
            root.mounted = true;
    }

    property NumberAnimation transition: NumberAnimation {
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (root.requestedOpen && root.progress >= 0.999) {
                root.progress = 1;
                root.phase = SurfaceLifecycle.Phase.Opened;
                root.fullyOpened();
            } else if (!root.requestedOpen && root.progress <= 0.001) {
                root.finishClosed();
            }
        }
    }
}
