pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
import qs.services
import "displays/MonitorRules.js" as MonitorRules

/**
 * A temporary display transaction. This service deliberately owns no
 * Confirmation commits only after persistent config reload and verification.
 */
Singleton {
    id: root

    readonly property string guardPath: `${FileUtils.trimFileProtocol(Directories.scriptPath)}/displays/preview_guard.py`
    property int previewTimeoutSeconds: 20
    property bool previewActive: false
    property int previewSecondsRemaining: 0
    property var previewError: null
    property var lastApplyResult: null
    property var lastRollbackResult: null
    property string previewState: "idle"
    property string transactionDirectory: ""
    property double previewDeadline: 0
    property string previewTopologySignature: ""
    property string previewClientToken: ""
    property var pendingDraft: null
    property bool recoveryComplete: false

    function error(code, message, detail) {
        return { code, message, detail: detail ?? null };
    }

    function transactionId() {
        return `preview-${Date.now()}-${Math.floor(Math.random() * 1000000000)}`;
    }

    function beginPreview(draft) {
        if (!recoveryComplete) {
            previewError = error("recovery-pending", "Waiting for unfinished display preview recovery.");
            return false;
        }
        if (previewState !== "idle") {
            previewError = error("preview-busy", "A display preview is already in progress.");
            return false;
        }
        const validation = MonitorRules.validateDraft(draft);
        if (!validation.valid) {
            previewError = error("invalid-draft", "The display draft cannot be previewed.", validation);
            return false;
        }

        previewError = null;
        lastApplyResult = null;
        lastRollbackResult = null;
        pendingDraft = MonitorRules.clone(draft);
        previewState = "snapshotting";
        startSnapshot("begin");
        return true;
    }

    function confirmPreview() {
        if (!previewActive || previewState !== "active")
            return false;
        previewState = "confirming";
        guardProc.purpose = "commit";
        guardProc.command = ["python3", guardPath, "commit", "--directory", transactionDirectory,
            "--rules-json", JSON.stringify(pendingDraft.rules)];
        guardProc.running = true;
        return true;
    }

    function revertPreview(reason) {
        if (!transactionDirectory || previewState === "reverting" || previewState === "confirming")
            return false;
        previewActive = false;
        previewSecondsRemaining = 0;
        previewState = "reverting";
        guardProc.purpose = "revert";
        guardProc.revertReason = reason || "user";
        guardProc.command = ["python3", guardPath, "revert", "--directory", transactionDirectory];
        guardProc.running = true;
        return true;
    }

    function startSnapshot(purpose) {
        snapshotProc.purpose = purpose;
        snapshotProc.command = ["hyprctl", "-j", "monitors", "all"];
        snapshotProc.running = true;
    }

    function armGuard(snapshotText) {
        previewState = "arming";
        guardProc.purpose = "begin";
        guardProc.command = ["python3", guardPath, "begin", "--transaction", transactionId(),
            "--timeout", String(previewTimeoutSeconds), "--snapshot-json", snapshotText];
        guardProc.running = true;
    }

    function startApply() {
        previewState = "applying";
        guardProc.purpose = "apply";
        guardProc.command = ["python3", guardPath, "apply", "--rules-json", JSON.stringify(pendingDraft.rules)];
        guardProc.running = true;
    }

    function finishIdle() {
        previewActive = false;
        previewSecondsRemaining = 0;
        previewDeadline = 0;
        previewTopologySignature = "";
        transactionDirectory = "";
        pendingDraft = null;
        previewClientToken = "";
        previewState = "idle";
    }

    function previewStateJson() : string {
        return JSON.stringify({
            active: previewActive,
            secondsRemaining: previewSecondsRemaining,
            error: previewError,
            state: previewState,
            transaction: previewClientToken,
        });
    }

    function failBeforeApply(code, message, detail) {
        previewError = error(code, message, detail);
        finishIdle();
    }

    function verifyApplied() {
        previewState = "verifying";
        startSnapshot("verify");
    }

    function verifyCommitted() {
        startSnapshot("commit-verify");
    }

    Timer {
        interval: 250
        repeat: true
        running: root.previewActive
        onTriggered: {
            root.previewSecondsRemaining = Math.max(0, Math.ceil((root.previewDeadline - Date.now()) / 1000));
            // The Python watchdog, not this timer, performs rollback. This
            // merely asks it to finish immediately when the shell survives.
            if (root.previewSecondsRemaining === 0) {
                root.previewError = root.error("preview-expired", "The temporary display preview expired and was rolled back.");
                root.revertPreview("timeout");
            }
        }
    }

    Timer {
        id: commitSettle
        interval: 500
        repeat: false
        onTriggered: root.verifyCommitted()
    }

    Process {
        id: snapshotProc
        property string purpose: ""
        property string output: ""
        stdout: StdioCollector {
            id: snapshotCollector
            onStreamFinished: snapshotProc.output = snapshotCollector.text
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if ((snapshotProc.purpose === "verify" || snapshotProc.purpose === "commit-verify") && root.transactionDirectory)
                    root.revertPreview(snapshotProc.purpose === "commit-verify" ? "commit-verification-query-failed" : "verification-query-failed");
                else
                    root.failBeforeApply("snapshot-failed", "Could not read current monitor state before preview.", { exitCode });
                return;
            }
            let raw;
            try {
                raw = JSON.parse(snapshotProc.output);
                if (!Array.isArray(raw))
                    throw new Error("monitor response is not an array");
            } catch (exception) {
                if ((snapshotProc.purpose === "verify" || snapshotProc.purpose === "commit-verify") && root.transactionDirectory)
                    root.revertPreview(snapshotProc.purpose === "commit-verify" ? "commit-verification-invalid-json" : "verification-invalid-json");
                else
                    root.failBeforeApply("snapshot-invalid-json", "Current monitor state was not valid JSON.", String(exception));
                return;
            }

            DisplaysService.commitMonitorJson(snapshotProc.output);
            if (snapshotProc.purpose === "begin")
                root.armGuard(snapshotProc.output);
            else if (snapshotProc.purpose === "verify" || snapshotProc.purpose === "commit-verify") {
                const comparison = MonitorRules.compareDraftToLive(root.pendingDraft, raw);
                if (!comparison.matches) {
                    root.previewError = root.error(snapshotProc.purpose === "commit-verify" ? "commit-verification-failed" : "apply-verification-failed",
                        "Hyprland did not apply the requested display state.", comparison);
                    root.revertPreview(snapshotProc.purpose === "commit-verify" ? "commit-verification-mismatch" : "verification-mismatch");
                    return;
                }
                if (snapshotProc.purpose === "commit-verify") {
                    guardProc.purpose = "confirm";
                    guardProc.command = ["python3", guardPath, "confirm", "--directory", transactionDirectory];
                    guardProc.running = true;
                    return;
                }
                root.previewActive = true;
                root.previewTopologySignature = DisplaysService.topologySignature;
                root.previewState = "active";
                root.previewSecondsRemaining = Math.max(0, Math.ceil((root.previewDeadline - Date.now()) / 1000));
            }
        }
    }

    Process {
        id: guardProc
        property string purpose: ""
        property string output: ""
        property string revertReason: ""
        stdout: StdioCollector {
            id: guardCollector
            onStreamFinished: guardProc.output = guardCollector.text
        }
        onExited: (exitCode, exitStatus) => {
            let response = null;
            try { response = JSON.parse(guardProc.output); } catch (exception) {}
            if (exitCode !== 0 || !response || response.ok !== true) {
                if (guardProc.purpose === "recover") {
                    root.recoveryComplete = true;
                    console.error("[DisplaysPreview] unfinished-preview recovery failed");
                    return;
                }
                const failure = root.error("preview-guard-failed", "Display preview guard failed.", {
                    purpose: guardProc.purpose, exitCode, response,
                });
                if (guardProc.purpose === "revert") {
                    root.lastRollbackResult = response || failure;
                    root.previewError = root.previewError || failure;
                    root.finishIdle();
                } else if (root.transactionDirectory) {
                    root.previewError = failure;
                    root.revertPreview("guard-failed");
                } else {
                    root.failBeforeApply(failure.code, failure.message, failure.detail);
                }
                return;
            }

            if (guardProc.purpose === "begin") {
                root.transactionDirectory = response.directory;
                root.previewDeadline = Number(response.deadline) * 1000;
                root.startApply();
            } else if (guardProc.purpose === "apply") {
                root.lastApplyResult = response;
                root.verifyApplied();
            } else if (guardProc.purpose === "commit") {
                commitSettle.restart();
            } else if (guardProc.purpose === "confirm") {
                root.finishIdle();
            } else if (guardProc.purpose === "revert") {
                root.lastRollbackResult = response;
                root.finishIdle();
                DisplaysService.refresh();
            } else if (guardProc.purpose === "recover") {
                root.recoveryComplete = true;
                if ((response.recovered || []).length > 0)
                    console.warn("[DisplaysPreview] recovered an unfinished display preview");
                DisplaysService.refresh();
            }
        }
    }

    Connections {
        target: DisplaysService
        function onTopologySignatureChanged() {
            if (root.previewActive && DisplaysService.topologySignature !== root.previewTopologySignature)
                root.revertPreview("topology-changed");
        }
    }

    // This handler is instantiated only by the persistent shell through
    // DisplayOverlayManager. Standalone Settings reaches it with `qs -c ii
    // ipc call`; it never owns the watchdog or transaction state itself.
    IpcHandler {
        target: "displayPreview"

        function beginPreview(draftJson: string): string {
            let draft;
            try {
                draft = JSON.parse(draftJson);
            } catch (exception) {
                return JSON.stringify({ accepted: false, error: root.error("invalid-draft-json", "Display draft IPC payload was invalid.", String(exception)) });
            }
            if (!root.beginPreview(draft))
                return JSON.stringify({ accepted: false, error: root.previewError });
            root.previewClientToken = `client-${Date.now()}-${Math.floor(Math.random() * 1000000000)}`;
            return JSON.stringify({ accepted: true, transaction: root.previewClientToken });
        }

        function confirmPreview(transaction: string): string {
            if (!transaction || transaction !== root.previewClientToken)
                return JSON.stringify({ accepted: false, error: root.error("stale-preview", "This display preview is no longer current.") });
            return JSON.stringify({ accepted: root.confirmPreview(), state: root.previewState });
        }

        function revertPreview(transaction: string, reason: string): string {
            if (!transaction || transaction !== root.previewClientToken)
                return JSON.stringify({ accepted: false, error: root.error("stale-preview", "This display preview is no longer current.") });
            return JSON.stringify({ accepted: root.revertPreview(reason || "user"), state: root.previewState });
        }

        function getPreviewState(): string {
            return root.previewStateJson();
        }
    }

    Component.onCompleted: {
        recoveryComplete = false;
        guardProc.purpose = "recover";
        guardProc.command = ["python3", guardPath, "recover"];
        guardProc.running = true;
    }
}
