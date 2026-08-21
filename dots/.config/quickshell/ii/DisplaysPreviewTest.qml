import QtQuick
import Quickshell
import qs.services
import "services/displays/MonitorRules.js" as MonitorRules

// Manual integration harness. Run only with a virtual output named
// TESTER-PREVIEW; it never edits the physical eDP-1 output.
ShellRoot {
    id: root
    property int stage: 0
    property bool passed: false

    function fail(message) {
        console.error(`[DisplaysPreviewTest] FAIL: ${message}`);
    }

    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: {
            if (root.passed) {
                running = false;
                return;
            }
            if (root.stage === 0 && DisplaysPreview.recoveryComplete && DisplaysService.monitors.length > 0) {
                const draft = MonitorRules.draftFromMonitors(DisplaysService.monitors);
                const virtualRule = draft.rules.find(rule => rule.output === "TESTER-PREVIEW");
                if (!virtualRule) {
                    fail("TESTER-PREVIEW is absent");
                    root.stage = -1;
                    return;
                }
                // Change only the virtual output; do not modify eDP-1.
                virtualRule.x = virtualRule.x + 37;
                virtualRule.scale = 1.25;
                virtualRule.transform = 1;
                if (!DisplaysPreview.beginPreview(draft)) {
                    fail(`begin failed: ${JSON.stringify(DisplaysPreview.previewError)}`);
                    root.stage = -1;
                    return;
                }
                root.stage = 1;
            } else if (root.stage === 1 && DisplaysPreview.previewActive) {
                if (!DisplaysPreview.lastApplyResult
                        || JSON.stringify(DisplaysPreview.lastApplyResult.applied) !== JSON.stringify(["TESTER-PREVIEW"])) {
                    fail(`unexpected apply targets: ${JSON.stringify(DisplaysPreview.lastApplyResult)}`);
                    root.stage = -1;
                    return;
                }
                if (!DisplaysPreview.revertPreview("test"))
                    fail("revert was refused");
                root.stage = 2;
            } else if (root.stage === 2 && DisplaysPreview.previewState === "idle") {
                if (!DisplaysPreview.lastRollbackResult || !DisplaysPreview.lastRollbackResult.ok)
                    fail(`rollback result: ${JSON.stringify(DisplaysPreview.lastRollbackResult)}`);
                else {
                    console.log("[DisplaysPreviewTest] PASS: preview apply and rollback completed");
                    root.passed = true;
                }
                root.stage = -1;
            }
        }
    }
}
