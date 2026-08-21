import QtQuick
import Quickshell
import qs.services
import "services/displays/MonitorRules.js" as MonitorRules

// Starts a short preview and deliberately leaves it armed. The caller kills
// this Quickshell process; preview_guard.py must restore TESTER-PREVIEW.
ShellRoot {
    property bool started: false

    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            if (!started && DisplaysPreview.recoveryComplete && DisplaysService.monitors.length > 0) {
                const draft = MonitorRules.draftFromMonitors(DisplaysService.monitors);
                const virtualRule = draft.rules.find(rule => rule.output === "TESTER-PREVIEW");
                if (!virtualRule) {
                    console.error("[DisplaysPreviewGuardTest] FAIL: TESTER-PREVIEW missing");
                    started = true;
                    return;
                }
                DisplaysPreview.previewTimeoutSeconds = 20;
                virtualRule.x = virtualRule.x + 91;
                started = DisplaysPreview.beginPreview(draft);
            }
            if (started && DisplaysPreview.previewActive) {
                console.log("[DisplaysPreviewGuardTest] ARMED");
                running = false;
            }
        }
    }
}
