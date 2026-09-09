import QtQuick

Item {
    id: root
    visible: false

    property int generation: 0
    property var queue: []

    function begin(nextGeneration) {
        root.generation = nextGeneration;
        root.queue = [];
        captureTimer.stop();
    }

    function enqueue(preview, requestGeneration) {
        if (!preview || requestGeneration !== root.generation)
            return;
        if (root.queue.indexOf(preview) !== -1)
            return;
        root.queue = root.queue.concat([preview]);
        if (!captureTimer.running)
            captureTimer.start();
    }

    function cancel() {
        root.generation++;
        root.queue = [];
        captureTimer.stop();
    }

    Timer {
        id: captureTimer
        interval: 16
        repeat: true
        onTriggered: {
            if (root.queue.length === 0) {
                stop();
                return;
            }

            const preview = root.queue[0];
            root.queue = root.queue.slice(1);
            if (preview)
                preview.capturePreview();

            if (root.queue.length === 0)
                stop();
        }
    }
}
