import QtQuick
import Quickshell
import "services/displays/MonitorRules.js" as Rules

ShellRoot {
    id: root
    property int failures: 0

    function expect(condition, label) {
        if (!condition) {
            failures += 1;
            console.error(`[MonitorRulesTest] FAIL: ${label}`);
        }
    }

    function rule(output, overrides = {}) {
        var result = {
            output,
            enabled: true,
            mode: { width: 1920, height: 1080, refreshRate: 60 },
            x: 0,
            y: 0,
            scale: 1,
            transform: 0,
            mirrorOf: "",
            vrr: null,
        };
        for (const key of Object.keys(overrides))
            result[key] = overrides[key];
        return result;
    }

    function draft(rules) {
        var monitorCapabilities = {};
        for (const currentRule of rules) {
            monitorCapabilities[currentRule.output] = {
                modes: currentRule.mode ? [{
                    width: currentRule.mode.width,
                    height: currentRule.mode.height,
                    refreshRate: currentRule.mode.refreshRate,
                }] : [],
            };
        }
        return { rules, monitorCapabilities };
    }

    function hasCode(issues, code) {
        return issues.some(issue => issue.code === code);
    }

    Component.onCompleted: {
        var one = rule("A");
        var oneRect = Rules.logicalRect(one);
        expect(oneRect.width === 1920 && oneRect.height === 1080, "1: 1080p scale 1 logical size");

        var fromLive = Rules.draftFromMonitors([{
            name: "A", enabled: true, width: 1920, height: 1080, refreshRate: 60,
            x: 0, y: 0, scale: 1, transform: 0, mirrorOf: "none", vrr: true,
            modes: [{ width: 1920, height: 1080, refreshRate: 60, raw: "1920x1080@60.00Hz" }],
        }]);
        expect(fromLive.rules[0].output === "A" && fromLive.rules[0].vrr === null
            && fromLive.monitorCapabilities.A.modes.length === 1, "live state builds an editable draft without inferring VRR policy");

        var fourK = rule("4K", { mode: { width: 3840, height: 2160, refreshRate: 60 }, scale: 2 });
        var fourKRect = Rules.logicalRect(fourK);
        expect(fourKRect.width === 1920 && fourKRect.height === 1080, "2: 4K scale 2 logical size");

        var sideBySide = [rule("A"), rule("B", { x: 1920 })];
        expect(Rules.layoutBounds(sideBySide).width === 3840 && Rules.isAdjacent(sideBySide[0], sideBySide[1], 0), "3: side-by-side bounds and adjacency");

        var left = [rule("A", { x: -1920 }), rule("B")];
        var normalized = Rules.normalizeLayout(left);
        expect(normalized[0].x === 0 && normalized[1].x === 1920, "4: normalize negative origin");

        var mixed = [rule("A", { mode: { width: 3840, height: 2160, refreshRate: 60 }, scale: 2 }), rule("B", { x: 1920, scale: 1.25 })];
        expect(Rules.layoutBounds(mixed).width === 3456, "5: mixed scale bounds");

        var portrait = rule("P", { mode: { width: 1920, height: 1080, refreshRate: 60 }, transform: 1 });
        var portraitRect = Rules.logicalRect(portrait);
        expect(portraitRect.width === 1080 && portraitRect.height === 1920, "6: 90 degree transform swaps dimensions");

        var overlapResult = Rules.validateDraft(draft([rule("A"), rule("B", { x: 100 })]));
        expect(hasCode(overlapResult.warnings, "layout-overlap"), "7: overlapping layout warns");

        var disabled = rule("A", { enabled: false });
        expect(Rules.layoutBounds([disabled]) === null && hasCode(Rules.validateDraft(draft([disabled])).errors, "no-usable-output"), "8: disabled output excluded");

        var validMirror = Rules.validateDraft(draft([rule("A"), rule("B", { mirrorOf: "A" })]));
        expect(validMirror.valid, "9: valid mirror");
        expect(Rules.layoutBounds([rule("A"), rule("B", { x: 4000, mirrorOf: "A" })]).width === 1920, "mirror is excluded from extended bounds");

        var missingMirror = Rules.validateDraft(draft([rule("A", { mirrorOf: "Missing" })]));
        expect(hasCode(missingMirror.errors, "mirror-target-missing"), "10: missing mirror target");

        var selfMirror = Rules.validateDraft(draft([rule("A", { mirrorOf: "A" })]));
        expect(hasCode(selfMirror.errors, "mirror-self"), "11: self mirror");

        var cycle = Rules.validateDraft(draft([rule("A", { mirrorOf: "B" }), rule("B", { mirrorOf: "A" })]));
        expect(hasCode(cycle.errors, "mirror-cycle"), "12: mirror cycle");

        var allDisabled = Rules.validateDraft(draft([rule("A", { enabled: false }), rule("B", { enabled: false })]));
        expect(hasCode(allDisabled.errors, "no-usable-output"), "13: all outputs disabled");

        var invalidModeDraft = draft([rule("A")]);
        invalidModeDraft.rules[0].mode = { width: 2560, height: 1440, refreshRate: 60 };
        var invalidMode = Rules.validateDraft(invalidModeDraft);
        expect(hasCode(invalidMode.errors, "mode-not-advertised"), "14: non-advertised mode");

        var invalidGrid = Rules.validateDraft(draft([rule("A", { scale: 1.4 })]));
        expect(hasCode(invalidGrid.errors, "invalid-logical-pixel-grid"), "scale must produce whole logical pixels");

        var snap = Rules.snapCandidatePositions(rule("B", { x: 1912 }), [rule("A")], 16);
        expect(snap.some(candidate => candidate.axis === "x" && candidate.value === 1920), "snap candidates expose edge alignment");

        console.log(`[MonitorRulesTest] ${failures === 0 ? "PASS" : `FAIL (${failures})`}`);
        if (failures > 0)
            throw new Error(`MonitorRulesTest failed with ${failures} assertion(s)`);
    }
}
