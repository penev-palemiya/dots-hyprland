import QtQuick

QtObject {
    id: root

    readonly property int closed: 0
    readonly property int opening: 1
    readonly property int opened: 2
    readonly property int closing: 3

    property int phase: closed
    property bool requestedOpen: false
    property bool contentNeeded: false
    property real progress: 0
    property int generation: 0

    readonly property bool surfaceVisible: phase !== closed
    readonly property bool acceptsInput: requestedOpen && phase !== closing

    required property int enterDuration
    required property int exitDuration
    required property list<real> enterCurve
    required property list<real> exitCurve

    signal fullyOpened
    signal fullyClosed

    function setOpen(open) {
        if (root.requestedOpen === open
                && ((open && (root.phase === root.opening || root.phase === root.opened))
                    || (!open && (root.phase === root.closing || root.phase === root.closed))))
            return;

        root.requestedOpen = open;
        transition.stop();

        if (open) {
            root.contentNeeded = true;
            root.generation++;
            root.phase = root.opening;
            Qt.callLater(() => {
                if (!root.requestedOpen)
                    return;
                transition.from = root.progress;
                transition.to = 1;
                transition.duration = Math.max(1, root.enterDuration * (1 - root.progress));
                transition.easing.bezierCurve = root.enterCurve;
                transition.start();
            });
        } else {
            if (root.phase === root.closed || root.progress <= 0) {
                root.finishClosed();
                return;
            }
            root.phase = root.closing;
            transition.from = root.progress;
            transition.to = 0;
            transition.duration = Math.max(1, root.exitDuration * root.progress);
            transition.easing.bezierCurve = root.exitCurve;
            transition.start();
        }
    }

    function finishClosed() {
        transition.stop();
        root.progress = 0;
        root.phase = root.closed;
        root.contentNeeded = false;
        root.fullyClosed();
    }

    property NumberAnimation transition: NumberAnimation {
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (root.requestedOpen && root.progress >= 0.999) {
                root.progress = 1;
                root.phase = root.opened;
                root.fullyOpened();
            } else if (!root.requestedOpen && root.progress <= 0.001) {
                root.finishClosed();
            }
        }
    }
}
