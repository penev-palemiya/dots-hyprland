import QtQuick
import Quickshell
import qs.services
import "services/displays/MonitorRules.js" as MonitorRules

// Leaves a 3-second virtual-only preview active to exercise watchdog timeout.
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
                    console.error("[DisplaysPreviewTimeoutTest] FAIL: TESTER-PREVIEW missing");
                    running = false;
                    return;
                }
                DisplaysPreview.previewTimeoutSeconds = 3;
                virtualRule.x = virtualRule.x + 73;
                started = DisplaysPreview.beginPreview(draft);
            }
            if (started && DisplaysPreview.previewState === "idle") {
                if (DisplaysPreview.previewError?.code === "preview-expired")
                    console.log("[DisplaysPreviewTimeoutTest] PASS: timeout rollback completed");
                else
                    console.error(`[DisplaysPreviewTimeoutTest] FAIL: ${JSON.stringify(DisplaysPreview.previewError)}`);
                running = false;
            }
        }
    }
}
