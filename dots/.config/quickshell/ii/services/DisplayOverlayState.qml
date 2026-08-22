pragma Singleton

import QtQuick
import Quickshell

/**
 * UI state for the shell-wide display overlay manager. The manager owns the
 * windows; Settings only asks it to show the short-lived identify state.
 */
Singleton {
    id: root

    property bool identifyActive: false
    readonly property int identifyTimeoutMs: 3000

    function showIdentify(): void {
        identifyActive = true;
        identifyTimer.restart();
    }

    Timer {
        id: identifyTimer
        interval: root.identifyTimeoutMs
        repeat: false
        onTriggered: root.identifyActive = false
    }
}
